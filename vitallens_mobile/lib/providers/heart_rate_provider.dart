import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/bluetooth_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import 'package:collection/collection.dart';

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
  late final NotificationService _notificationService;
  List<HeartRateData> _heartRateData = [];
  bool _isMonitoring = false;
  int _currentHeartRate = 0;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  bool _notificationsEnabled = true; // Default to enabled
  List<ScanResult> _scanResults = [];
  bool _notificationsEnabled = true;

  // For real-time charting - keep recent data in memory
  static const int _maxRecentDataPoints = 300; // ~5 minutes at 1Hz

  // Batch processing for database writes
  static const int _batchSize = 10;
  final List<HeartRateData> _pendingBatch = [];
  DateTime _lastBatchFlush = DateTime.now();
  static const Duration _batchFlushInterval = Duration(seconds: 5);

  List<HeartRateData> get heartRateData => List.unmodifiable(_heartRateData);
  bool get isMonitoring => _isMonitoring;
  int get currentHeartRate => _currentHeartRate;
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  List<int> get recentRrIntervals => _bluetoothService.getRecentRrIntervals();

  HeartRateProvider() {
    _bluetoothService = BluetoothService(this);
    _notificationService = NotificationService();
    _startBatchFlushTimer();
    // Initialize notification service
    _notificationService.init();
  }

  /// Set whether notifications are enabled
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    // If disabling notifications, we could clear any pending notifications here if needed
    if (!enabled) {
      _notificationService.cancelAllNotifications();
    }
  }

Future<Map<String, dynamic>> exportDataCsv() async {
    try {
      final exportService = ExportService();
      final file = await exportService.exportToCSV();
      if (file != null) {
        return {
          'success': true,
          'filePath': file.path,
          'message': 'Data exported successfully to CSV'
        };
      } else {
        return {
          'success': false,
          'error': 'No data available to export'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to export data: $e'
      };
    }
  }

  Future<Map<String, dynamic>> exportDataJson() async {
    try {
      final exportService = ExportService();
      final file = await exportService.exportToJSON();
      if (file != null) {
        return {
          'success': true,
          'filePath': file.path,
          'message': 'Data exported successfully to JSON'
        };
      } else {
        return {
          'success': false,
          'error': 'No data available to export'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to export data: $e'
      };
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadInitialData();
    _isInitialized = true;
  }

  Future<void> _loadInitialData() async {
    try {
      // Load recent data for better UI experience
      final data = await _dbService.getRecentData(minutes: 10);
      _heartRateData = data
          .map((model) => HeartRateData(
                heartRate: model.heartRate,
                timestamp: DateTime.parse(model.timestamp),
                sdnn: model.sdnn,
                rmssd: model.rmssd,
                pnn50: model.pnn50,
              ))
          .toList();
      
      // Also load some older data for HRV calculations if needed
      if (_heartRateData.isEmpty) {
        final allData = await _dbService.getAllHeartRateData(limit: 50);
        _heartRateData = allData
            .map((model) => HeartRateData(
                  heartRate: model.heartRate,
                  timestamp: DateTime.parse(model.timestamp),
                  sdnn: model.sdnn,
                  rmssd: model.rmssd,
                  pnn50: model.pnn50,
                ))
            .toList();
      }
      
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

  void addHeartRateData(HeartRateData data) {
    // Add to local list (maintain size limit)
    _heartRateData.add(data);
    if (_heartRateData.length > _maxRecentDataPoints) {
      _heartRateData.removeRange(0, _heartRateData.length - _maxRecentDataPoints);
    }
    _currentHeartRate = data.heartRate;

    // Check for abnormal heart rate and send notification if needed
    if (_notificationsEnabled) {
      _notificationService.checkHeartRate(data.heartRate);
    }

    // Add to batch for database storage
    _pendingBatch.add(data);

    // Save to database in batches for better performance
    _maybeFlushBatch();

    notifyListeners();
  }

  void _startBatchFlushTimer() {
    // Flush batch periodically to ensure data persistence
    Future.delayed(_batchFlushInterval, () {
      if (!mounted) return; // Safety check
      _flushBatch();
      _startBatchFlushTimer(); // Reschedule
    });
  }

  void _maybeFlushBatch() {
    if (_pendingBatch.length >= _batchSize) {
      _flushBatch();
    }
  }

  Future<void> _flushBatch() async {
    if (_pendingBatch.isEmpty) return;
    
    final batchToFlush = List<HeartRateData>.from(_pendingBatch);
    _pendingBatch.clear();
    _lastBatchFlush = DateTime.now();
    
    try {
      final models = batchToFlush.map((data) => HeartRateDataModel(
        heartRate: data.heartRate,
        timestamp: data.timestamp.toIso8601String(),
        sdnn: data.sdnn,
        rmssd: data.rmssd,
        pnn50: data.pnn50,
      )).toList();
      
      await _dbService.insertHeartRateDataBatch(models);
      // debugPrint('Flushed batch of ${batchToFlush.length} heart rate records to DB');
    } catch (e) {
      debugPrint('Error flushing batch to database: $e');
      // Put data back in pending batch to retry later
      _pendingBatch.addAll(batchToFlush);
    }
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
    // Flush any pending data on disconnect
    await _flushBatch();
    notifyListeners();
  }

  Future<void> clearData() async {
    _heartRateData.clear();
    _currentHeartRate = 0;
    _pendingBatch.clear();
    await _dbService.deleteAllHeartRateData();
    notifyListeners();
  }

  // Get data for charts (last 30 readings by default, or time-based)
  List<HeartRateData> getChartData({int limit = 30}) {
    final data = _heartRateData.toList();
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Most recent first
    return data.take(limit).toList();
  }

  // Get data for HRV analysis (use more points for better accuracy)
  List<HeartRateData> getHrvData({int minutes = 2}) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    final data = _heartRateData
        .where((d) => d.timestamp.isAfter(cutoff))
        .toList();
    
    // Sort by timestamp ascending for HRV calculations
    data.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return data;
  }

  // Dispose resources
  @override
  void dispose() {
    _flushBatch(); // Flush any remaining data
    _bluetoothService.dispose();
    _notificationService.dispose();
    super.dispose();
  }
}
