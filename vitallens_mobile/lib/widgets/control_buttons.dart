import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final bool isMonitoring;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const ControlButtons({
    super.key,
    required this.isMonitoring,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: isMonitoring ? null : onStart,
          icon: Icon(isMonitoring ? Icons.pause_circle : Icons.play_circle),
          label: Text(isMonitoring ? 'Pause' : 'Start Monitoring'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isMonitoring ? Colors.orange : Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop_circle),
          label: const Text('Stop'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
}
