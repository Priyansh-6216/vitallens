from flask import Flask, render_template, jsonify, make_response
from flask_cors import CORS
import asyncio
import threading
import time
import csv
import os
from datetime import datetime
from bleak import BleakScanner, BleakClient

app = Flask(__name__)
CORS(app)

# Global state
devices = []
current_client = None
current_device_address = None
heart_rate = 0
is_monitoring = False
data_file = None
data_file_path = 'heart_rate_data.csv'

# Heart Rate Measurement characteristic UUID (standard)
HRM_CHARACTERISTIC_UUID = "00002a37-0000-1000-8000-00805f9b34fb"

def init_data_file():
    """Initialize the CSV file with headers if it doesn't exist"""
    if not os.path.exists(data_file_path):
        with open(data_file_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['timestamp', 'heart_rate_bpm'])

def parse_heart_rate(data):
    """Parse heart rate measurement from Bluetooth data"""
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

    if rr_interval:
        # Parse RR intervals (remaining data)
        rr_intervals = []
        while index < len(data):
            rr = int.from_bytes(data[index:index+2], byteorder='little')
            rr_intervals.append(rr/1000.0)  # Convert to seconds
            index += 2
        return bpm, rr_intervals

    return bpm, []

def notification_handler(sender, data):
    """Handle heart rate notifications"""
    global heart_rate, data_file
    bpm, rr_intervals = parse_heart_rate(data)
    heart_rate = bpm
    timestamp = datetime.now().isoformat()

    # Log to CSV
    if data_file is None:
        init_data_file()
        data_file = open(data_file_path, 'a', newline='')

    writer = csv.writer(data_file)
    writer.writerow([timestamp, bpm])
    data_file.flush()  # Ensure data is written immediately

    print(f"Heart Rate: {bpm} bpm at {timestamp}")

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
    global current_client, current_device_address, is_monitoring, data_file

    if current_client and current_client.is_connected:
        try:
            await current_client.stop_notify(HRM_CHARACTERISTIC_UUID)
            await current_client.disconnect()
            print("Disconnected from device")
        except Exception as e:
            print(f"Disconnection error: {e}")
        finally:
            current_client = None
            current_device_address = None
            is_monitoring = False
            # Close the data file if open
            if data_file is not None:
                data_file.close()
                data_file = None

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

@app.route('/api/export/csv')
def export_csv():
    """Export heart rate data as CSV"""
    try:
        if not os.path.exists(data_file_path):
            return jsonify({"error": "No data available"}), 404

        # Read the CSV file and return it
        with open(data_file_path, 'r') as f:
            content = f.read()

        response = make_response(content)
        response.headers["Content-Disposition"] = f"attachment; filename=heart_rate_data.csv"
        response.headers["Content-Type"] = "text/csv"
        return response
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/export/json')
def export_json():
    """Export heart rate data as JSON"""
    try:
        if not os.path.exists(data_file_path):
            return jsonify({"error": "No data available"}), 404

        # Read CSV and convert to JSON
        data = []
        with open(data_file_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                data.append(row)

        response = jsonify(data)
        response.headers["Content-Disposition"] = "attachment; filename=heart_rate_data.json"
        return response
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
