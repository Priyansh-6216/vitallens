import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/heart_rate_provider.dart';
import '../services/database_service.dart';
import '../models/heart_rate_data_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  List<HeartRateDataModel> _historyData = [];

  // Stats
  double _avgHeartRate = 0;
  int _minHeartRate = 0;
  int _maxHeartRate = 0;
  double _avgSdnn = 0;
  double _avgRmssd = 0;
  double _avgPnn50 = 0;

  @override
  void initState() {
    super.initState();
    // Default to last 7 days
    _setDateRange(DateTime.now().subtract(const Duration(days: 7)), DateTime.now());
    _loadHistoryData();
  }

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    });
  }

  Future<void> _loadHistoryData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isLoading = true);
    try {
      final data = await _dbService.getHeartRateDataInRange(_startDate!, _endDate!);
      setState(() {
        _historyData = data;
        _calculateStatistics();
      });
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateStatistics() {
    if (_historyData.isEmpty) {
      _avgHeartRate = 0;
      _minHeartRate = 0;
      _maxHeartRate = 0;
      _avgSdnn = 0;
      _avgRmssd = 0;
      _avgPnn50 = 0;
      return;
    }

    double hrSum = 0;
    int minHr = _historyData.first.heartRate;
    int maxHr = _historyData.first.heartRate;
    double sdnnSum = 0;
    double rmssdSum = 0;
    double pnn50Sum = 0;
    int validSdnnCount = 0;
    int validRmssdCount = 0;
    int validPnn50Count = 0;

    for (final record in _historyData) {
      hrSum += record.heartRate;
      if (record.heartRate < minHr) minHr = record.heartRate;
      if (record.heartRate > maxHr) maxHr = record.heartRate;

      if (record.sdnn != null) {
        sdnnSum += record.sdnn!;
        validSdnnCount++;
      }
      if (record.rmssd != null) {
        rmssdSum += record.rmssd!;
        validRmssdCount++;
      }
      if (record.pnn50 != null) {
        pnn50Sum += record.pnn50!;
        validPnn50Count++;
      }
    }

    _avgHeartRate = hrSum / _historyData.length;
    _minHeartRate = minHr;
    _maxHeartRate = maxHr;
    _avgSdnn = validSdnnCount > 0 ? sdnnSum / validSdnnCount : 0;
    _avgRmssd = validRmssdCount > 0 ? rmssdSum / validRmssdCount : 0;
    _avgPnn50 = validPnn50Count > 0 ? pnn50Sum / validPnn50Count : 0;
  }

  List<FlSpot> _getHeartRateSpots() {
    return _historyData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final heartRate = entry.value.heartRate.toDouble();
      return FlSpot(index, heartRate);
    }).toList();
  }

  List<FlSpot> _getSdnnSpots() {
    return _historyData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final sdnn = entry.value.sdnn ?? 0;
      return FlSpot(index, sdnn.toDouble());
    }).toList();
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Theme.of(context).primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _startDate == null || _endDate == null
                    ? 'Select Date Range'
                    : '${DateFormat('MMM d, yyyy').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _showDateRangePicker,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      // For simplicity, just select a single day - in a full app you'd have a range picker
      setState(() {
        _setDateRange(picked, picked);
      });
      _loadHistoryData();
    }
  }

  Widget _buildQuickDateButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildDateButton('Today', DateTime.now(), DateTime.now()),
          const SizedBox(width: 8),
          _buildDateButton('Yesterday',
              DateTime.now().subtract(const Duration(days: 1)),
              DateTime.now().subtract(const Duration(days: 1))),
          const SizedBox(width: 8),
          _buildDateButton('Last 7 Days',
              DateTime.now().subtract(const Duration(days: 7)),
              DateTime.now()),
          const SizedBox(width: 8),
          _buildDateButton('Last 30 Days',
              DateTime.now().subtract(const Duration(days: 30)),
              DateTime.now()),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime start, DateTime end) {
    final bool isSelected = _isSameDay(_startDate, start) &&
                           _isSameDay(_endDate, end);

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _setDateRange(start, end);
        });
        _loadHistoryData();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).primaryColor
            : Theme.of(context).colorScheme.surface,
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }

  bool _isSameDay(DateTime? d1, DateTime d2) {
    if (d1 == null) return false;
    return d1.year == d2.year &&
           d1.month == d2.month &&
           d1.day == d2.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History & Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.show_chart,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No data available for selected period',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try selecting a different date range',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateRangeSelector(),
                        const SizedBox(height: 16),
                        _buildQuickDateButtons(),
                        const SizedBox(height: 24),
                        // Statistics Cards
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Avg HR',
                                value: '${_avgHeartRate.round()} bpm',
                                icon: Icons.favorite,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Min HR',
                                value: '$_minHeartRate bpm',
                                icon: Icons.arrow_downward,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Max HR',
                                value: '$_maxHeartRate bpm',
                                icon: Icons.arrow_upward,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'Avg SDNN',
                                value: '${_avgSdnn.toStringAsFixed(1)} ms',
                                icon: Icons.show_chart,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Avg RMSSD',
                                value: '${_avgRmssd.toStringAsFixed(1)} ms',
                                icon: Icons.favorite_border,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                title: 'Avg pNN50',
                                value: '${_avgPnn50.toStringAsFixed(1)} %',
                                icon: Icons.percent,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Charts Section
                        const Text(
                          'Heart Rate Trends',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _historyData.length < 2
                              ? const Center(
                                  child: Text('Need more data points for chart'),
                                )
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(show: true),
                                    titlesData: FlTitlesShow(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 && index < _historyData.length) {
                                              final date = _historyData[index].timestamp;
                                              return Text(
                                                DateFormat('Md').format(date),
                                                style: const FontStyle(),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _getHeartRateSpots(),
                                        isCurved: true,
                                        color: Colors.red,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(show: false),
                                        belowBarData: BarAreaData(show: true),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'HRV Trends',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _historyData.length < 2
                              ? const Center(
                                  child: Text('Need more data points for chart'),
                                )
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(show: true),
                                    titlesData: FlTitlesShow(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index >= 0 && index < _historyData.length) {
                                              final date = _historyData[index].timestamp;
                                              return Text(
                                                DateFormat('Md').format(date),
                                                style: const FontStyle(),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: true),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _getSdnnSpots(),
                                        isCurved: true,
                                        color: Colors.purple,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(show: false),
                                        belowBarData: BarAreaData(show: true),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}