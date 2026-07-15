from flask import Flask, render_template, jsonify
from flask_cors import CORS
import asyncio
import threading
import time
from bleak import BleakScanner, BleakClient

app = Flask(__name__)
CORS(app)

# Global state
devices = []
current_client = None
current_device_address = None
heart_rate = 0
is_monitoring = False

# Heart Rate Measurement characteristic UUID (standard)
HRM_CHARACTERISTIC_UUID = "00002a37-0000-1000-8000-00805f9b34fb"

def bluetooth_thread():
    """Background thread for Bluetooth operations"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    async def scan_devices():
        """Scan for BLE devices"""
        return await BleakScanner.discover()

    async def connect_device(address):
        """Connect to a BLE device"""
        global current_client, heart_rate, is_monitoring

        try:
            if current_client and current_client.is_connected:
                await current_client.disconnect()

            current_client = BleakClient(address)
            await current_client.connect()

            # Start heart rate notifications
            await current_client.start_notify(
                HRM_CHARACTERISTIC_UUID,
                notification_handler
            )

            is_monitoring = True
            return True
        except Exception as e:
            print(f"Connection error: {e}")
            return False

    async def disconnect_device():
        """Disconnect from current device"""
        global current_client, heart_rate, is_monitoring

        try:
            if current_client and current_client.is_connected:
                await current_client.stop_notify(HRM_CHARACTERISTIC_UUID)
                await current_client.disconnect()
            current_client = None
            heart_rate = 0
            is_monitoring = False
        except Exception as e:
            print(f"Disconnection error: {e}")

    def notification_handler(sender, data):
        """Handle incoming heart rate notifications"""
        global heart_rate

        # Parse heart rate from Bluetooth HRM format
        # Format: Flags (1 byte) + HR value (1 or 2 bytes) + ...
        flags = data[0]
        hr_format = flags & 0x01  # 0 = UINT8, 1 = UINT16

        if hr_format:
            # UINT16 - little endian
            hr = int.from_bytes(data[1:3], byteorder='little')
        else:
            # UINT8
            hr = data[1]

        heart_rate = hr
        print(f"Heart Rate: {hr} bpm")

    def run_async(coro):
        """Run coroutine in the event loop"""
        future = asyncio.run_coroutine_threadsafe(coro, loop)
        return future.result()

    # Keep the event loop running
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass

# Start Bluetooth thread
bt_thread = threading.Thread(target=bluetooth_thread, daemon=True)
bt_thread.start()

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/scan')
def scan_devices():
    """Scan for BLE devices"""
    try:
        # Run scan in the Bluetooth thread
        future = asyncio.run_coroutine_threadsafe(
            scan_devices(),
            asyncio.get_event_loop() if hasattr(asyncio, '_get_running_loop') and asyncio._get_running_loop() else None
        )
        # Since we don't have direct access to the loop, let's create a simple approach
        # For simplicity, we'll do a direct scan (acceptable for this use case)
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        devices = loop.run_until_complete(scan_devices())
        loop.close()

        # Format for JSON response
        device_list = []
        for device in devices:
            device_list.append({
                'name': device.name or 'Unknown',
                'address': device.address,
                'rssi': device.rssi if hasattr(device, 'rssi') else None
            })

        return jsonify(device_list)
    except Exception as e:
        print(f"Scan error: {e}")
        return jsonify([]), 500

@app.route('/api/connect/<address>')
def connect_device(address):
    """Connect to a device"""
    global current_device_address
    try:
        # Create a new loop for this operation
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)

        async def connect():
            global current_client, heart_rate, is_monitoring
            try:
                if current_client and current_client.is_connected:
                    await current_client.disconnect()

                current_client = BleakClient(address)
                await current_client.connect()

                # Start heart rate notifications
                await current_client.start_notify(
                    HRM_CHARACTERISTIC_UUID,
                    lambda sender, data: set_heart_rate(data)
                )

                is_monitoring = True
                current_device_address = address
                return {'success': True}
            except Exception as e:
                print(f"Connection error: {e}")
                return {'success': False, 'error': str(e)}

        def set_heart_rate(data):
            global heart_rate
            flags = data[0]
            hr_format = flags & 0x01

            if hr_format:
                heart_rate = int.from_bytes(data[1:3], byteorder='little')
            else:
                heart_rate = data[1]

        result = loop.run_until_complete(connect())
        loop.close()
        return jsonify(result)
    except Exception as e:
        print(f"Connection error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/heart_rate')
def get_heart_rate():
    """Get current heart rate"""
    global heart_rate, is_monitoring
    return jsonify({
        'heart_rate': heart_rate,
        'monitoring': is_monitoring
    })

@app.route('/api/disconnect')
def disconnect_device():
    """Disconnect from current device"""
    global current_client, heart_rate, is_monitoring, current_device_address
    try:
        # Create a new loop for this operation
        loop = asyncio.new_event_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
         asyncio.set_event_loop(loop)

        async def disconnect():
            global current_client, heart_rate, is_monitoring
            try:
                if current_client and current_client.is_connected:
                    await current_client.stop_notify(HRM_CHARACTERISTIC_UUID)
                    await current_client.disconnect()
                current_client = None
                heart_rate = 0
                is_monitoring = False
                return {'success': True}
            except Exception as e:
                print(f"Disconnection error: {e}")
                return {'success': False, 'error': str(e)}

        result = loop.run_until_complete(disconnect())
        loop.close()
        current_device_address = None
        return jsonify(result)
    except Exception as e:
        print(f"Disconnection error: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)