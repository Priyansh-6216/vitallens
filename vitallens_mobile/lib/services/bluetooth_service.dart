import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/heart_rate_data_model.dart';
import '../providers/heart_rate_provider.dart';

class BluetoothService {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  final HeartRateProvider _heartRateProvider;
  StreamSubscription<ScanResult>? _scanSubscription;
  StreamSubscription<BluetoothDeviceState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _heartRateSubscription;
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;

  BluetoothService(this._heartRateProvider);

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<ScanResult> get scanResults => _scanResults;
  final List<ScanResult> _scanResults = [];

  // Start scanning for BLE devices
  Future<void> startScan() async {
    if (_isScanning) return;
    
    _isScanning = true;
    _scanResults.clear();
    
    // Subscribe to scan results
    _scanSubscription = _flutterBlue.scanResults.listen((results) {
      // Filter for heart rate devices (optional)
      for (var result in results) {
        // Check if device advertises heart rate service
        if (result.advertisementData.serviceUuids
            .contains("0000180d-0000-1000-8000-00805f9b34fb")) {
          // Avoid duplicates
          if (!_scanResults.any((r) => r.device.id == result.device.id)) {
            _scanResults.add(result);
          }
        }
      }
    });

    // Start scanning
    await _flutterBlue.startScan(timeout: const Duration(seconds: 10));
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;
    
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _flutterBlue.stopScan();
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    await _connectedDevice?.disconnect();
    
    _connectedDevice = device;
    await device.connect();
    
    // Listen to device state changes
    _deviceStateSubscription = device.state.listen((state) {
      if (state == BluetoothDeviceState.connected) {
        _isConnected = true;
        _discoverServices(device);
      } else if (state == BluetoothDeviceState.disconnected) {
        _isConnected = false;
        _connectedDevice = null;
        _heartRateSubscription?.cancel();
        _heartRateSubscription = null;
      }
    });
  }

  // Discover services and find heart rate measurement characteristic
  Future<void> _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString() == "0000180d-0000-1000-8000-00805f9b34fb") {
        // Heart Rate Service found
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == 
              "00002a37-0000-1000-8000-00805f9b34fb") {
            // Heart Rate Measurement Characteristic
            await characteristic.setNotifyValue(true);
            _heartRateSubscription = characteristic.value.listen(_processHeartRateData);
            break;
          }
        }
      }
    }
  }

  // Process incoming heart rate data
  void _processHeartRateData(List<int> value) {
    if (value.isEmpty) return;
    
    // Parse heart rate measurement (Bluetooth SIG spec)
    int flags = value[0];
    int heartRate;
    int offset = 1;
    
    // Check if heart rate value is uint8 or uint16
    if ((flags & 0x01) == 0) {
      // uint8 format
      heartRate = value[offset];
    } else {
      // uint16 format
      heartRate = (value[offset] | (value[offset + 1] << 8));
    }
    
    // Calculate RR intervals if present (for HRV)
    List<int> rrIntervals = [];
    if ((flags & 0x02) != 0) {
      // RR intervals present
      while (offset + 1 < value.length) {
        int rrInterval = (value[offset] | (value[offset + 1] << 8));
        rrIntervals.add(rrInterval);
        offset += 2;
      }
    }
    
    // Calculate HRV metrics from RR intervals if available
    double? sdnn;
    double? rmssd;
    double? pnn50;
    
    if (rrIntervals.length >= 2) {
      sdnn = _calculateSDNN(rrIntervals);
      rmssd = _calculateRMSSD(rrIntervals);
      pnn50 = _calculatePNN50(rrIntervals);
    }
    
    // Create heart rate data
    final heartRateData = HeartRateData(
      heartRate: heartRate,
      timestamp: DateTime.now(),
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
    );
    
    // Add to provider
    _heartRateProvider.addHeartRateData(heartRateData);
  }

  // HRV calculation methods
  double _calculateSDNN(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    double mean = intervals.reduce((a, b) => a + b) / intervals.length;
    double variance = intervals.map((i) => (i - mean) * (i - mean)).reduce((a, b) => a + b) / intervals.length;
    return variance.sqrt();
  }

  double _calculateRMSSD(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    List<double> diffs = [];
    for (int i = 1; i < intervals.length; i++) {
      diffs.add((intervals[i] - intervals[i - 1]).abs().toDouble());
    }
    
    double sumOfSquares = diffs.map((d) => d * d).reduce((a, b) => a + b);
    return (sumOfSquares / diffs.length).sqrt();
  }

  double _calculatePNN50(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    int countOver50 = 0;
    for (int i = 1; i < intervals.length; i++) {
      if ((intervals[i] - intervals[i - 1]).abs() > 50) {
        countOver50++;
      }
    }
    
    return (countOver50 / (intervals.length - 1)) * 100.0;
  }

  // Disconnect from device
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _isConnected = false;
    _connectedDevice = null;
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
  }

  // Dispose resources
  void dispose() {
    stopScan();
    disconnect();
  }
}
