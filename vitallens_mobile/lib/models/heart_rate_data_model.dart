class HeartRateDataModel {
  final int heartRate;
  final String timestamp; // Stored as ISO string in database
  final double? sdnn;
  final double? rmssd;
  final double? pnn50;

  HeartRateDataModel({
    required this.heartRate,
    required this.timestamp,
    this.sdnn,
    this.rmssd,
    this.pnn50,
  });

  Map<String, dynamic> toMap() {
    return {
      'heart_rate': heartRate,
      'timestamp': timestamp,
      'sdnn': sdnn,
      'rmssd': rmssd,
      'pnn50': pnn50,
    };
  }

  factory HeartRateDataModel.fromMap(Map<String, dynamic> map) {
    return HeartRateDataModel(
      heartRate: map['heart_rate'] as int,
      timestamp: map['timestamp'] as String,
      sdnn: map['sdnn'] as double?,
      rmssd: map['rmssd'] as double?,
      pnn50: map['pnn50'] as double?,
    );
  }
}
