import 'package:flutter/material.dart';

class HRVMetricsCard extends StatelessWidget {
  final Map<String, double> hrvData;

  const HRVMetricsCard({
    super.key,
    required this.hrvData,
  });

  @override
  Widget build(BuildContext context) {
    final double sdnn = hrvData['SDNN'] ?? 0.0;
    final double rmssd = hrvData['RMSSD'] ?? 0.0;
    final double pnn50 = hrvData['pNN50'] ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HRV Metrics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricColumn('SDNN', '$sdnn ms', _getSdnnColor(sdnn)),
                _buildMetricColumn('RMSSD', '$rmssd ms', _getRmssdColor(rmssd)),
                _buildMetricColumn('pNN50', '${pnn50.toStringAsFixed(1)}%',
                    _getPnn50Color(pnn50)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Color _getSdnnColor(double value) {
    if (value < 20) return Colors.red;
    if (value < 40) return Colors.orange;
    return Colors.green;
  }

  Color _getRmssdColor(double value) {
    if (value < 15) return Colors.red;
    if (value < 30) return Colors.orange;
    return Colors.green;
  }

  Color _getPnn50Color(double value) {
    if (value < 5) return Colors.red;
    if (value < 15) return Colors.orange;
    return Colors.green;
  }
}
