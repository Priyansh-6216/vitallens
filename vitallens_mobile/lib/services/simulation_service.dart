import 'dart:math';
import '../providers/heart_rate_provider.dart';

class SimulationService {
  static final SimulationService _instance = SimulationService._internal();
  late final HeartRateProvider _provider;
  Timer? _timer;
  bool _isSimulating = false;

  factory SimulationService() {
    return _instance;
  }

  SimulationService._internal();

  void initialize(HeartRateProvider provider) {
    _provider = provider;
  }

  void startSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _generateMockData());
  }

  void stopSimulation() {
    _isSimulating = false;
    _timer?.cancel();
  }

  void _generateMockData() {
    // Simulate realistic heart rate data (60-100 bpm resting, with some variation)
    final Random random = Random();
    final int baseHR = 70 + random.nextInt(20); // 70-90 bpm
    final int variation = random.nextBool() ? -random.nextInt(10) : random.nextInt(10);
    final int heartRate = (baseHR + variation).clamp(50, 120);

    // Generate some HRV metrics (simplified)
    final double sdnn = 20 + random.nextDouble() * 30; // 20-50 ms
    final double rmssd = 15 + random.nextDouble() * 25; // 15-40 ms
    final double pnn50 = 5 + random.nextDouble() * 20; // 5-25%

    final data = HeartRateData(
      heartRate: heartRate,
      timestamp: DateTime.now(),
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
    );

    _provider.addHeartRateData(data);
  }
}
