import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/heart_rate_provider.dart';
import '../widgets/heart_rate_display.dart';
import '../widgets/heart_rate_chart.dart';
import '../widgets/hrv_metrics_card.dart';
import '../widgets/control_buttons.dart';
import '../services/database_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  bool _showConnectionTips = true;

  @override
  void initState() {
    super.initState();
    _checkInitialData();
  }

  Future<void> _checkInitialData() async {
    try {
      final count = await _dbService.getCount();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showConnectionTips = count == 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSampleData() async {
    // Add sample data for demonstration
    final List<Map<String, dynamic>> samples = [
      {
        'heartRate': 72,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'sdnn': 35.2,
        'rmssd': 28.7,
        'pNN50': 15.3
      },
      {
        'heartRate': 75,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 4)).toIso8601String(),
        'sdnn': 33.1,
        'rmssd': 26.4,
        'pNN50': 12.8
      },
      {
        'heartRate': 70,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        'sdnn': 38.5,
        'rmssd': 31.2,
        'pNN50': 18.9
      },
      {
        'heartRate': 68,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        'sdnn': 40.1,
        'rmssd': 33.8,
        'pNN50': 22.4
      },
      {
        'heartRate': 71,
        'timestamp': DateTime.now().toIso8601String(),
        'sdnn': 36.8,
        'rmssd': 29.5,
        'pNN50': 16.7
      }
    ];

    for (final sample in samples) {
      try {
        await _dbService.insertHeartRateData(sample);
      } catch (e) {
        // Continue if one fails
      }
    }

    if (mounted) {
      // Refresh the data
      final heartRateProvider =
          Provider.of<HeartRateProvider>(context, listen: false);
      await heartRateProvider.init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final heartRateProvider = Provider.of<HeartRateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VitalLens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await heartRateProvider.init();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Connection status with more details
                  _buildConnectionStatus(heartRateProvider),
                  const SizedBox(height: 12),
                  
                  // Connection tips for first-time users
                  if (_showConnectionTips && !heartRateProvider.isConnected)
                    _buildConnectionTips(),
                  
                  // Current heart rate display
                  HeartRateDisplay(
                    heartRate: heartRateProvider.currentHeartRate,
                    isMonitoring: heartRateProvider.isMonitoring,
                  ),
                  const SizedBox(height: 24),
                  
                  // Heart rate trend chart with real-time indicator
                  const Text(
                    'Heart Rate Trend (Real-time)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: heartRateProvider.heartRateData.isEmpty
                        ? const Center(
                            child: Text(
                              'No data available\nScan and connect to a heart rate monitor\nto see real-time data',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : HeartRateChart(
                            data: _convertToFlSpots(heartRateProvider.getChartData()),
                            showLiveIndicator: heartRateProvider.isConnected &&
                                heartRateProvider.isMonitoring,
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  // HRV metrics with explanation
                  const Text(
                    'Heart Rate Variability Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  heartRateProvider.heartRateData.isEmpty
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            HRVMetricsCard(
                              hrvData: _calculateLatestHrv(
                                  heartRateProvider.getHrvData(minutes: 2)),
                            ),
                            const SizedBox(height: 8),
                            _buildHrvInfo(heartRateProvider),
                          ],
                        ),
                  const SizedBox(height: 24),
                  
                  // Control buttons and BLE controls
                  Column(
                    children: [
                      ControlButtons(
                        isMonitoring: heartRateProvider.isMonitoring,
                        onStart: heartRateProvider.startMonitoring,
                        onStop: heartRateProvider.stopMonitoring,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: heartRateProvider.isScanning
                                ? null
                                : () => _startScan(heartRateProvider),
                            icon: Icon(heartRateProvider.isScanning
                                ? Icons.stop
                                : Icons.bluetooth_searching),
                            label: Text(heartRateProvider.isScanning
                                ? 'Stop Scanning'
                                : 'Scan for Devices'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (heartRateProvider.isConnected)
                            ElevatedButton.icon(
                              onPressed: () => _disconnectDevice(heartRateProvider),
                              icon: const Icon(Icons.bluetooth_connected),
                              label: const Text('Disconnect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSampleData,
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Add Sample Data'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionStatus(HeartRateProvider provider) {
    if (provider.isScanning) {
      return Container(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        child: const Row(
          children: [
            Icon(Icons.bluetooth_searching, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Scanning for heart rate monitors...',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
      );
    } else if (provider.isConnected) {
      // Show connection quality info
      final rrCount = provider.recentRrIntervals.length;
      return Container(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Connected to Heart Rate Monitor',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            if (rrCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Receiving RR intervals: $rrCount recent samples',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
            ],
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        backgroundColor: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        child: const Row(
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'No device connected',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildConnectionTips() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Getting Started',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          SizedBox(height: 4),
          Text(
            '1. Ensure your Bluetooth heart rate monitor is powered on\n'
            '2. Tap "Scan for Devices" to find available monitors\n'
            '3. Select your device from the list to connect\n'
            '4. Watch real-time heart rate and HRV data appear',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildHrvInfo(HeartRateProvider provider) {
    final hrvData = provider.getHrvData(minutes: 2);
    final dataPoints = hrvData.length;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey.shade50,
      ),
      child: Text(
        'Based on $dataPoints data points from the last 2 minutes\n'
        'HRV metrics update continuously as new data arrives',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _startScan(HeartRateProvider provider) async {
    await provider.startScan();
  }

  Future<void> _disconnectDevice(HeartRateProvider provider) async {
    await provider.disconnect();
  }

  List<FlSpot> _convertToFlSpots(List<HeartRateData> heartRateData) {
    return heartRateData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final heartRate = entry.value.heartRate.toDouble();
      return FlSpot(index, heartRate);
    }).toList();
  }

  Map<String, double> _calculateLatestHrv(List<HeartRateData> data) {
    if (data.isEmpty) {
      return {'SDNN': 0.0, 'RMSSD': 0.0, 'pNN50': 0.0};
    }

    // Use more sophisticated HRV calculation with available data
    final heartRates = data.map((d) => d.heartRate.toDouble()).toList();
    
    if (heartRates.length < 2) {
      return {'SDNN': 0.0, 'RMSSD': 0.0, 'pNN50': 0.0};
    }

    // Calculate SDNN (standard deviation of all NN intervals)
    double meanHR = heartRates.reduce((a, b) => a + b) / heartRates.length;
    double variance = heartRates.map((hr) => (hr - meanHR) * (hr - meanHR))
        .reduce((a, b) => a + b) / heartRates.length;
    double sdnn = variance.sqrt();

    // Calculate RMSSD (root mean square of successive differences)
    if (heartRates.length >= 2) {
      List<double> successiveDiffs = [];
      for (int i = 1; i < heartRates.length; i++) {
        successiveDiffs.add((heartRates[i] - heartRates[i - 1]).abs());
      }
      double sumOfSquares = successiveDiffs.map((d) => d * d).reduce((a, b) => a + b);
      double rmssd = (sumOfSquares / successiveDiffs.length).sqrt();
      
      // Calculate pNN50 (percentage of successive differences > 50ms)
      // Convert to milliseconds approximation: 60000/bpm gives ms per beat
      List<double> successiveIntervalsMs = [];
      for (int i = 0; i < heartRates.length; i++) {
        double msPerBeat = 60000 / heartRates[i];
        successiveIntervalsMs.add(msPerBeat);
      }
      
      int countOver50 = 0;
      for (int i = 1; i < successiveIntervalsMs.length; i++) {
        if ((successiveIntervalsMs[i] - successiveIntervalsMs[i - 1]).abs() > 50) {
          countOver50++;
        }
      }
      double pnn50 = (countOver50 / (successiveIntervalsMs.length - 1)) * 100.0;
      
      return {
        'SDNN': sdnn.clamp(0.0, 200.0).toDouble(),
        'RMSSD': rmssd.clamp(0.0, 200.0).toDouble(),
        'pNN50': pnn50.clamp(0.0, 100.0).toDouble(),
      };
    } else {
      return {'SDNN': sdnn.clamp(0.0, 200.0).toDouble(), 'RMSSD': 0.0, 'pNN50': 0.0};
    }
  }
}
