# Heart Rate Monitor

A simple web-based heart rate monitor that connects to Bluetooth Low Energy (BLE) heart rate straps and displays real-time heart rate data.

## Features

- Scan for nearby BLE devices
- Connect to heart rate monitors (standard Bluetooth Heart Rate Service)
- Display real-time heart rate in beats per minute (BPM)
- Visual feedback based on heart rate zones
- Simple, clean interface built with Tailwind CSS
- No external dependencies beyond standard Bluetooth profiles

## Supported Devices

This application works with any Bluetooth device that implements the standard Heart Rate Service (0x180D), including:
- Polar H10, H9, H7
- Wahoo Tickr, Tickr X, Tickr Fit
- Garmin HRM-Pro, HRM-Swim, HRM-Tri
- And many other Bluetooth heart rate straps

## Setup

1. Install Python 3.8+
2. Clone this repository
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the application:
   ```bash
   python app.py
   ```
5. Open your browser to http://localhost:5000

## How It Works

1. The application uses the [Bleak](https://github.com/hbldh/bleak) library to communicate with Bluetooth Low Energy devices
2. It scans for nearby BLE devices advertising standard services
3. When you select a device, it connects and subscribes to the Heart Rate Measurement characteristic (0x2A37)
4. Heart rate data is parsed according to the Bluetooth SIG specification
5. The web interface updates in real-time via AJAX polling

## Data Privacy

- All data processing happens locally on your device
- No data is sent to external servers
- Bluetooth connections are direct between your computer and the heart rate monitor
- No personal information is collected or stored

## Requirements

- Python 3.8+
- Bluetooth 4.0+ hardware on your computer
- A Bluetooth heart rate monitor that supports the standard Heart Rate Service

## License

MIT License