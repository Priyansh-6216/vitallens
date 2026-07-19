import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/heart_rate_provider.dart';
import '../widgets/heart_rate_display.dart';
import '../widgets/heart_rate_chart.dart';
import '../widgets/hrv_metrics_card.dart';
import '../widgets/control_buttons.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;

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
                  // Current heart rate display
                  HeartRateDisplay(
                    heartRate: heartRateProvider.currentHeartRate,
                    isMonitoring: heartRateProvider.isMonitoring,
                  ),
                  const SizedBox(height: 24),
                  
                  // Heart rate trend chart
                  const Text(
                    'Heart Rate Trend (Last 30 Readings)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: heartRateProvider.heartRateData.isEmpty
                        ? const Center(
                            child: Text(
                              'No data available\nTap "Add Sample Data" to see demo',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : HeartRateChart(
                            data: _convertToFlSpots(heartRateProvider.getChartData()),
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  // HRV metrics
                  const Text(
                    'Heart Rate Variability',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  heartRateProvider.heartRateData.isEmpty
                      ? const SizedBox.shrink()
                      : HRVMetricsCard(
                          hrvData: _calculateLatestHRV(
                              heartRateProvider.getChartData()),
                        ),
                  const SizedBox(height: 24),
                  
                  // Control buttons and sample data button
                  Column(
                    children: [
                      ControlButtons(
                        isMonitoring: heartRateProvider.isMonitoring,
                        onStart: heartRateProvider.startMonitoring,
                        onStop: heartRateProvider.stopMonitoring,
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

  List<FlSpot> _convertToFlSpots(List<HeartRateData> heartRateData) {
    return heartRateData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final heartRate = entry.value.heartRate.toDouble();
      return FlSpot(index, heartRate);
    }).toList();
  }

  Map<String, double> _calculateLatestHRV(
      List<HeartRateData> data) {
    if (data.isEmpty) {
      return {'SDNN': 0.0, 'RMSSD': 0.0, 'pNN50': 0.0};
    }

    // Use the most recent reading for HRV display
    final latest = data.first;
    return {
      'SDNN': latest.sdnn ?? 0.0,
      'RMSSD': latest.rmssd ?? 0.0,
      'pNN50': latest.pnn50 ?? 0.0,
    };
  }
}
