from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import asyncio
import threading
import time
from datetime import datetime
from bleak import BleakScanner, BleakClient
from sqlalchemy import create_engine, Column, Integer, Float, DateTime, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import numpy as np
import json

app = Flask(__name__)
CORS(app)

# Database setup
DATABASE_URL = "sqlite:///health_data.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database models
class HeartRateReading(Base):
    __tablename__ = "heart_rate_readings"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    heart_rate = Column(Integer, nullable=False)
    rr_intervals = Column(String)  # JSON string of RR intervals in seconds

    def to_dict(self):
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat(),
            "heart_rate": self.heart_rate,
            "rr_intervals": self.rr_intervals
        }

class HRVMetrics(Base):
    __tablename__ = "hrv_metrics"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    sdnn = Column(Float)  # Standard deviation of NN intervals
    rmssd = Column(Float)  # Root mean square of successive differences
    pnn50 = Column(Float)  # Percentage of successive NN intervals differing by >50ms
    mean_hr = Column(Integer)  # Mean heart rate during the measurement period

    def to_dict(self):
        return {
            "id": self.id,
            "timestamp": self.timestamp.isoformat(),
            "sdnn": self.sdnn,
            "rmssd": self.rmssd,
            "pnn50": self.pnn50,
            "mean_hr": self.mean_hr
        }

# Create tables
Base.metadata.create_all(bind=engine)

# Global state
devices = []
current_client = None
current_device_address = None
heart_rate = 0
is_monitoring = False
rr_buffer = []  # Buffer to store recent RR intervals for HRV calculation

# Heart Rate Measurement characteristic UUID (standard)
HRM_CHARACTERISTIC_UUID = "00002a37-0000-1000-8000-00805f9b34fb"

def calculate_hrv(rr_intervals):
    """Calculate HRV metrics from RR intervals"""
    if len(rr_intervals) < 2:
        return None

    # Convert to numpy array for calculations
    rr_array = np.array(rr_intervals)

    # SDNN: Standard deviation of NN intervals
    sdnn = np.std(rr_array)

    # RMSSD: Root mean square of successive differences
    successive_diffs = np.diff(rr_array)
    rmssd = np.sqrt(np.mean(np.square(successive_diffs)))

    # pNN50: Percentage of successive NN intervals differing by >50ms
    nn50 = np.sum(np.abs(successive_diffs) > 0.05)  # >50ms
    pnn50 = (nn50 / len(successive_diffs)) * 100

    # Mean heart rate
    mean_rr = np.mean(rr_array)
    mean_hr = 60.0 / mean_rr if mean_rr > 0 else 0

    return {
        "sdnn": float(sdnn),
        "rmssd": float(rmssd),
        "pnn50": float(pnn50),
        "mean_hr": int(round(mean_hr))
    }

def save_to_database(hr_value, rr_intervals=None):
    """Save heart rate reading to database"""
    db = SessionLocal()
    try:
        # Prepare RR intervals for storage
        rr_json = None
        if rr_intervals and len(rr_intervals) > 0:
            rr_json = json.dumps(rr_intervals)

        # Create and save heart rate reading
        reading = HeartRateReading(
            heart_rate=hr_value,
            rr_intervals=rr_json
        )
        db.add(reading)
        db.commit()

        # Calculate and store HRV if we have enough RR intervals
        if rr_intervals and len(rr_intervals) >= 5:  # Minimum for HRV calculation
            hrv_metrics = calculate_hrv(rr_intervals)
            if hrv_metrics:
                hrv_record = HRVMetrics(
                    sdnn=hrv_metrics["sdnn"],
                    rmssd=hrv_metrics["rmssd"],
                    pnn50=hrv_metrics["pnn50"],
                    mean_hr=hrv_metrics["mean_hr"]
                )
                db.add(hrv_record)
                db.commit()

    except Exception as e:
        print(f"Database error: {e}")
        db.rollback()
    finally:
        db.close()

def parse_heart_rate(data):
    """Parse heart rate measurement from Bluetooth data"""
    global rr_buffer
    flags = data[0]
    hr_format = flags & 0x01  # 0 = UINT8, 1 = UINT16
    sensor_contact = (flags & 0x06) >> 1
    energy_expended = (flags & 0x08) >> 3
    rr_interval = (flags & 0x10) >> 4

    index = 1
    if hr_format == 0:
        bpm = data[index]
        index += 1
    else:
        bpm = int.from_bytes(data[index:index+2], byteorder='little')
        index += 2

    if energy_expended:
        # Skip 2 bytes of energy expended
        index += 2

    rr_intervals = []
    if rr_interval:
        # Parse RR intervals (remaining data)
        while index < len(data):
            rr = int.from_bytes(data[index:index+2], byteorder='little')
            rr_intervals.append(rr/1000.0)  # Convert to seconds
            index += 2

    # Update RR buffer for HRV calculation (keep last 30 seconds worth)
    if rr_intervals:
        rr_buffer.extend(rr_intervals)
        # Keep only last 30 seconds of data (assuming ~1Hz sampling)
        if len(rr_buffer) > 30:
            rr_buffer = rr_buffer[-30:]

    return bpm, rr_intervals

def notification_handler(sender, data):
    """Handle heart rate notifications"""
    global heart_rate
    bpm, rr_intervals = parse_heart_rate(data)
    heart_rate = bpm

    # Save to database
    save_to_database(bpm, rr_intervals if rr_intervals else None)

    print(f"Heart Rate: {bpm} bpm, RR intervals: {len(rr_intervals) if rr_intervals else 0}")

async def scan_devices():
    """Scan for Bluetooth devices"""
    global devices
    print("Scanning for devices...")
    devices = await BleakScanner.discover(timeout=5.0)
    print(f"Found {len(devices)} devices")
    return devices

async def connect_to_device(address):
    """Connect to a Bluetooth device"""
    global current_client, current_device_address, is_monitoring

    try:
        print(f"Connecting to {address}...")
        client = BleakClient(address)
        await client.connect()

        if client.is_connected:
            print("Connected!")
            current_client = client
            current_device_address = address

            # Start heart rate notifications
            await client.start_notify(
                HRM_CHARACTERISTIC_UUID,
                notification_handler
            )
            is_monitoring = True
            return True
        else:
            print("Failed to connect")
            return False
    except Exception as e:
        print(f"Connection error: {e}")
        return False

async def disconnect_from_device():
    """Disconnect from the current device"""
    global current_client, current_device_address, is_monitoring, rr_buffer

    if current_client and current_client.is_connected:
        try:
            await client.stop_notify(HRM_CHARACTERISTIC_UUID)
            await client.disconnect()
            print("Disconnected from device")
        except Exception as e:
            print(f"Disconnection error: {e}")
        finally:
            current_client = None
            current_device_address = None
            is_monitoring = False
            rr_buffer = []  # Clear RR buffer on disconnect

def run_async(coro):
    """Helper to run async functions in a thread"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    return loop.run_until_complete(coro)

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/scan')
def scan():
    devices_list = run_async(scan_devices())
    return jsonify([{
        'name': d.name or 'Unknown',
        'address': d.address,
        'rssi': d.rssi
    } for d in devices_list])

@app.route('/api/connect/<address>')
def connect(address):
    success = run_async(connect_to_device(address))
    return jsonify({'success': success})

@app.route('/api/disconnect')
def disconnect():
    run_async(disconnect_from_device())
    return jsonify({'success': True})

@app.route('/api/heart_rate')
def get_heart_rate():
    return jsonify({'heart_rate': heart_rate, 'monitoring': is_monitoring})

@app.route('/api/hrv/latest')
def get_latest_hrv():
    """Get the latest HRV metrics"""
    db = SessionLocal()
    try:
        latest = db.query(HRVMetrics).order_by(HRVMetrics.timestamp.desc()).first()
        if latest:
            return jsonify(latest.to_dict())
        else:
            return jsonify({"error": "No HRV data available"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        db.close()

@app.route('/api/heart_rate/history')
def get_heart_rate_history():
    """Get heart rate history with optional limit"""
    limit = request.args.get('limit', 100, type=int)
    db = SessionLocal()
    try:
        readings = db.query(HeartRateReading)\
                    .order_by(HeartRateReading.timestamp.desc())\
                    .limit(limit)\
                    .all()
        return jsonify([r.to_dict() for r in reversed(readings)])  # Oldest first for charts
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        db.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)