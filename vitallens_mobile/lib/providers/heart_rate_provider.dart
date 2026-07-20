import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/bluetooth_service.dart';

class HeartRateData {
  final int heartRate;
  final DateTime timestamp;
  final double? sdnn;
  final double? rmssd;
  final double? pnn50;

  HeartRateData({
    required this.heartRate,
    required this.timestamp,
    this.sdnn,
    this.rmssd,
    this.pnn50,
  });
}

class HeartRateProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  late final BluetoothService _bluetoothService;
  List<HeartRateData> _heartRateData = [];
  bool _isMonitoring = false;
  int _currentHeartRate = 0;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  List<ScanResult> _scanResults = [];

  List<HeartRateData> get heartRateData => List.unmodifiable(_heartRateData);
  bool get isMonitoring => _isMonitoring;
  int get currentHeartRate => _currentHeartRate;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  HeartRateProvider() {
    _bluetoothService = BluetoothService(this);
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadInitialData();
    _isInitialized = true;
  }

  Future<void> _loadInitialData() async {
    try {
      final data = await _dbService.getAllHeartRateData();
      _heartRateData = data
          .map((model) => HeartRateData(
                heartRate: model.heartRate,
                timestamp: DateTime.parse(model.timestamp),
                sdnn: model.sdnn,
                rmssd: model.rmssd,
                pnn50: model.pnn50,
              ))
          .toList();
      if (_heartRateData.isNotEmpty) {
        _currentHeartRate = _heartRateData.last.heartRate;
      }
    } catch (e) {
      // If there's an error loading data, start with empty list
      _heartRateData = [];
      _currentHeartRate = 0;
    }
    notifyListeners();
  }

  Future<void> addHeartRateData(HeartRateData data) async {
    // Add to local list
    _heartRateData.add(data);
    _currentHeartRate = data.heartRate;
    
    // Save to database
    await _dbService.insertHeartRateData(
      HeartRateDataModel(
        heartRate: data.heartRate,
        timestamp: data.timestamp.toIso8601String(),
        sdnn: data.sdnn,
        rmssd: data.rmssd,
        pnn50: data.pnn50,
      ),
    );
    
    notifyListeners();
  }

  void startMonitoring() {
    _isMonitoring = true;
    notifyListeners();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    notifyListeners();
  }

  Future<void> startScan() async {
    await _bluetoothService.startScan();
    _isScanning = _bluetoothService.isScanning;
    _scanResults = _bluetoothService.scanResults;
    notifyListeners();
  }

  Future<void> stopScan() async {
    await _bluetoothService.stopScan();
    _isScanning = _bluetoothService.isScanning;
    notifyListeners();
  }

  Future<void> connectToDevice(ScanResult result) async {
    await _bluetoothService.connectToDevice(result.device);
    _isConnected = _bluetoothService.isConnected;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _isConnected = _bluetoothService.isConnected;
    notifyListeners();
  }

  Future<void> clearData() async {
    _heartRateData.clear();
    _currentHeartRate = 0;
    await _dbService.deleteAllHeartRateData();
    notifyListeners();
  }

  // Get data for charts (last 30 readings by default)
  List<HeartRateData> getChartData({int limit = 30}) {
    final data = _heartRateData.toList();
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
    return data.take(limit).toList();
  }

  // Dispose resources
  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }
}
