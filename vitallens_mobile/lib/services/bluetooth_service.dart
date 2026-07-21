import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/heart_rate_data_model.dart';
import '../providers/heart_rate_provider.dart';
import '../services/database_service.dart';

class BluetoothService {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus.instance;
  final HeartRateProvider _heartRateProvider;
  final DatabaseService _dbService = DatabaseService();
  StreamSubscription<ScanResult>? _scanSubscription;
  StreamSubscription<BluetoothDeviceState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _heartRateSubscription;
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  
  // For HRV visualization - store RR intervals for better analysis
  final List<int> _rrIntervalBuffer = [];
  static const int _maxRrBufferSize = 30; // Keep last 30 RR intervals for HRV
  
  // Data quality tracking
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

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
    _consecutiveErrors = 0; // Reset error count on new scan
    
    // Subscribe to scan results
    _scanSubscription = _flutterBlue.scanResults.listen(
      _onScanResult,
      onError: _onScanError,
    );

    // Start scanning with specific services to improve battery life
    await _flutterBlue.startScan(
      timeout: const Duration(seconds: 15),
      servicesGuids: const [
        Guid("0000180d-0000-1000-8000-00805f9b34fb") // Heart Rate Service
      ],
      allowDuplicates: false,
    );
  }

  // Handle scan results
  void _onScanResult(ScanResult result) {
    // Filter for heart rate devices (advertising Heart Rate Service)
    if (result.advertisementServiceGuids
        .any((guid) => guid.toString() == "0000180d-0000-1000-8000-00805f9b34fb")) {
      // Avoid duplicates based on device ID
      if (!_scanResults.any((r) => r.device.id == result.device.id)) {
        _scanResults.add(result);
        // Notify listeners only if we have significant updates
        if (_scanResults.length % 5 == 0 || _scanResults.length == 1) {
          _heartRateProvider.notifyListeners();
        }
      }
    }
  }

  // Handle scan errors
  void _onScanError(dynamic error) {
    debugPrint('Bluetooth scan error: $error');
    _consecutiveErrors++;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      stopScan();
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;
    
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _flutterBlue.stopScan();
    _heartRateProvider.notifyListeners();
  }

  // Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    await _connectedDevice?.disconnect();
    
    _connectedDevice = device;
    await device.connect(mtuSize: 187); // Increased MTU for better throughput
    
    // Listen to device state changes
    _deviceStateSubscription = device.state.listen(
      _onDeviceStateChange,
      onError: _onDeviceError,
    );
  }

  // Handle device state changes
  void _onDeviceStateChange(BluetoothDeviceState state) {
    if (state == BluetoothDeviceState.connected) {
      _isConnected = true;
      _discoverServices(_connectedDevice!);
    } else if (state == BluetoothDeviceState.disconnected) {
      _isConnected = false;
      _connectedDevice = null;
      _heartRateSubscription?.cancel();
      _heartRateSubscription = null;
      _rrIntervalBuffer.clear(); // Clear buffer on disconnect
    }
    _heartRateProvider.notifyListeners();
  }

  // Handle device errors
  void _onDeviceError(dynamic error) {
    debugPrint('Bluetooth device error: $error');
    // Attempt to recover by disconnecting
    disconnect();
  }

  // Discover services and find heart rate measurement characteristic
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == "0000180d-0000-1000-8000-00805f9b34fb") {
          // Heart Rate Service found
          for (var characteristic in service in service.characteristics) {
              (characteristic.uuidString() == 
                  "00002a37-0000-1000-8000-00805f9b34fb" ||
                  characteristic
                  .properties
                  .contains(BluetoothCharacteristicProperties.notify)) {
             
  // Heart  ServSce Rate Measurement Characteristic. 
 await characteristic.setNotifyValue(true);
            _heartRateSubscription = characteristic.value.listen(
              _processHeartRateData,
              onError: _onHeartRateError,
              onDone: _onHeartRateDone,
            );
            break;
          }
          break; // Exit service loop once HR service found
        }
      }
    } catch (e) {
      debugPrint('Error discovering services: $e');
      disconnect();
    }
  }

  // Process incoming heart rate data with enhanced validation
  void _processHeartRateData(List<int> value) {
    if (value.isEmpty) {
      _handleDataError("Empty heart rate value received");
      return;
    }

    try {
      // Parse heart rate measurement according to Bluetooth SIG spec
      final int flags = value[0];
      int heartRate;
      int offset = 1;

      // Validate minimum length for flags + at least 1 byte HR
      if (value.length < 2) {
        _handleDataError("Heart rate value too short");
        return;
      }

      // Check if heart rate value is uint8 or uint16 (bit 0 of flags)
      if ((flags & 0x01) == 0) {
        // uint8 format - 1 byte for HR
        if (value.length < offset + 1) {
          _handleDataError("Incomplete uint8 heart rate value");
          return;
        }
        heartRate = value[offset];
        offset += 1;
      } else {
        // uint16 format - 2 bytes for HR (little-endian)
        if (value.length < offset + 2) {
          _handleDataError("Incomplete uint16 heart rate value");
          return;
        }
        heartRate = value[offset] | (value[offset + 1] << 8);
        offset += 2;
      }

      // Validate heart rate range (physiologically plausible)
      if (heartRate < 20 || heartRate > 300) {
        _handleDataError("Heart rate out of plausible range: $heartRate");
        return;
      }

      // Process RR intervals if present (bit 1 of flags)
      List<int> rrIntervals = [];
      if ((flags & 0x02) != 0) {
        // Calculate expected length for RR intervals
        int expectedLength = offset;
        while (expectedLength + 1 < value.length) {
          expectedLength += 2;
        }
        
        if (value.length < expectedLength) {
          _handleDataError("Incomplete RR interval data");
          // Continue with just heart rate if RR data is incomplete
        } else {
          // Extract RR intervals (each is 2 bytes, little-endian, in 1/1024 seconds)
          while (offset + 1 < value.length) {
            int rrInterval = value[offset] | (value[offset + 1] << 8);
            // Validate RR interval range (typically 300-2000 ms for 30-200 BPM)
            if (rrInterval >= 150 && rrInterval <= 4000) { // Converted to ms equivalent
              rrIntervals.add(rrInterval);
            }
            offset += 2;
          }
        }
      }

      // Process Energy Expended if present (bit 3 of flags)
      // Skip for now as not needed for core functionality

      // Reset error counter on successful parse
      _consecutiveErrors = 0;

      // Update HRV buffer with new RR intervals
      _updateRrBuffer(rrIntervals);

      // Calculate HRV metrics
      double? sdnn;
      double? rmssd;
      double? pnn50;

      // Always calculate from current RR intervals if we have enough
      if (_rrIntervalBuffer.length >= 2) {
        final List<int> validRrIntervals = _rrIntervalBuffer
            .where((rr) => rr >= 150 && rr <= 4000)
            .toList();
        
        if (validRrIntervals.length >= 2) {
          sdnn = _calculateSdnn(validRrIntervals);
          rmssd = _calculateRmssd(validRrIntervals);
          pnn50 = _calculatePnn50(validRrIntervals);
        }
      }

      // Create heart rate data with timestamp
      final heartRateData = HeartRateData(
        heartRate: heartRate,
        timestamp: DateTime.now(),
        sdnn: sdnn,
        rmssd: rmssd,
        pnn50: pnn50,
      );

      // Add to provider (triggers UI update and database save)
      _heartRateProvider.addHeartRateData(heartRateData);
    } catch (e, stackTrace) {
      _handleDataError("Exception processing heart rate data: $e", stackTrace);
    }
  }

  // Update RR interval buffer with new values
  void _updateRrBuffer(List<int> newRrIntervals) {
    for (int rr in newRrIntervals) {
      _rrIntervalBuffer.add(rr);
      // Maintain buffer size
      if (_rrIntervalBuffer.length > _maxRrBufferSize) {
        _rrIntervalBuffer.removeAt(0);
      }
    }
  }

  // Handle data errors with rate limiting
  void _handleDataError(String message, [dynamic stackTrace]) {
    _consecutiveErrors++;
    if (_consecutiveErrors <= 3) { // Only log first few errors to avoid spam
      debugPrint('Heart rate data error: $message');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('Too many consecutive errors, stopping heart rate updates');
      // Don't disconnect immediately - might be recoverable
    }
  }

  // Handle heart rate characteristic errors
  void _onHeartRateError(dynamic error) {
    debugPrint('Heart rate characteristic error: $error');
    _handleDataError("Heart rate characteristic error: $error");
  }

  // Handle heart rate characteristic done (device disconnected)
  void _onHeartRateDone() {
    debugPrint('Heart rate characteristic stream done');
    // Don't automatically disconnect - wait for device state change
  }

  // Enhanced HRV calculation methods with better handling
  double _calculateSdnn(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    // Convert to double for calculations
    final List<double> values = intervals.map((e) => e * 1.0 / 1024.0 * 1000.0).toList(); // Convert to ms
    
    double mean = values.reduce((a, b) => a + b) / values.length;
    double variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    return variance.sqrt();
  }

  double _calculateRmssd(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    // Convert to milliseconds
    final List<double> values = intervals.map((e) => e * 1.0 / 1024.0 * 1000.0).toList();
    
    List<double> diffs = [];
    for (int i = 1; i < values.length; i++) {
      diffs.add((values[i] - values[i - 1]).abs());
    }
    
    if (diffs.isEmpty) return 0.0;
    
    double sumOfSquares = diffs.map((d) => d * d).reduce((a, b) => a + b);
    return (sumOfSquares / diffs.length).sqrt();
  }

  double _calculatePnn50(List<int> intervals) {
    if (intervals.length < 2) return 0.0;
    
    // Convert to milliseconds
    final List<double> values = intervals.map((e) => e * 1.0 / 1024.0 * 1000.0).toList();
    
    int countOver50 = 0;
    for (int i = 1; i < values.length; i++) {
      if ((values[i] - values[i - 1]).abs() > 50.0) {
        countOver50++;
      }
    }
    
    return (countOver50 / (values.length - 1)) * 100.0;
  }

  // Get recent RR intervals for advanced analysis (if needed elsewhere)
  List<int> getRecentRrIntervals() => List.unmodifiable(_rrIntervalBuffer);

  // Disconnect from device
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _isConnected = false;
    _connectedDevice = null;
    _heartRateSubscription?.cancel();
    _heartRateSubscription = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    _rrIntervalBuffer.clear(); // Clear buffer on disconnect
  }

  // Dispose resources
  void dispose() {
    stopScan();
    disconnect();
  }
}
