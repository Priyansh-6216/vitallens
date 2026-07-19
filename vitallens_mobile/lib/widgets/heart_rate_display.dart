import 'package:flutter/material.dart';

class HeartRateDisplay extends StatelessWidget {
  final int heartRate;
  final bool isMonitoring;

  const HeartRateDisplay({
    super.key,
    required this.heartRate,
    required this.isMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Current Heart Rate',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            heartRate > 0 ? '$heartRate bpm' : '--',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: heartRate > 0
                  ? (heartRate >= 100 || heartRate <= 50
                      ? Colors.red
                      : (heartRate >= 90 || heartRate <= 60
                          ? Colors.orange
                          : Colors.green))
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isMonitoring
                  ? Colors.green.shade100
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isMonitoring ? 'MONITORING' : 'PAUSED',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isMonitoring
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
