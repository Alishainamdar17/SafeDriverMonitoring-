class DriverProfile {
  final double averageSpeed;
  final double averageOverSpeedRatio;
  final double averageEventRate;
  final int driveCount;

  DriverProfile({
    required this.averageSpeed,
    required this.averageOverSpeedRatio,
    required this.averageEventRate,
    required this.driveCount,
  });

  factory DriverProfile.defaultProfile() => DriverProfile(
        averageSpeed: 0.0,
        averageOverSpeedRatio: 0.0,
        averageEventRate: 0.0,
        driveCount: 0,
      );

  bool get isInitialized => driveCount > 0;

  Map<String, dynamic> toJson() => {
        'averageSpeed': averageSpeed,
        'averageOverSpeedRatio': averageOverSpeedRatio,
        'averageEventRate': averageEventRate,
        'driveCount': driveCount,
      };

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
        averageSpeed: (json['averageSpeed'] as num).toDouble(),
        averageOverSpeedRatio: (json['averageOverSpeedRatio'] as num).toDouble(),
        averageEventRate: (json['averageEventRate'] as num).toDouble(),
        driveCount: json['driveCount'] as int,
      );

  DriverProfile mergeWith(DriverProfile other) {
    if (!isInitialized) return other;
    if (!other.isInitialized) return this;

    const alpha = 0.2;
    return DriverProfile(
      averageSpeed: averageSpeed * (1 - alpha) + other.averageSpeed * alpha,
      averageOverSpeedRatio: averageOverSpeedRatio * (1 - alpha) + other.averageOverSpeedRatio * alpha,
      averageEventRate: averageEventRate * (1 - alpha) + other.averageEventRate * alpha,
      driveCount: driveCount + other.driveCount,
    );
  }
}
