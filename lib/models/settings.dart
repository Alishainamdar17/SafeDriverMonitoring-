import 'package:safe_drive_monitor/config/app_config.dart';

class Settings {
  final int retentionDays;
  final double minDrivingSpeed;
  final double speedLimit;
  final double suddenAccThreshold;
  final double suddenBrakeThreshold;
  final double sharpTurnThreshold;
  final bool adaptiveLearningEnabled;

  Settings({
    required this.retentionDays,
    required this.minDrivingSpeed,
    required this.speedLimit,
    required this.suddenAccThreshold,
    required this.suddenBrakeThreshold,
    required this.sharpTurnThreshold,
    required this.adaptiveLearningEnabled,
  });

  factory Settings.defaultSettings() => Settings(
    retentionDays: AppConfig.retentionDays,
    minDrivingSpeed: AppConfig.minRecordingSpeed,
    speedLimit: AppConfig.speedThreshold,
    suddenAccThreshold: AppConfig.suddenAccelerationThreshold,
    suddenBrakeThreshold: AppConfig.suddenBrakingThreshold,
    sharpTurnThreshold: AppConfig.sharpTurnThreshold,
    adaptiveLearningEnabled: AppConfig.adaptiveLearningEnabled,
  );

  Map<String, dynamic> toJson() => {
    'retentionDays': retentionDays,
    'minDrivingSpeed': minDrivingSpeed,
    'speedLimit': speedLimit,
    'suddenAccThreshold': suddenAccThreshold,
    'suddenBrakeThreshold': suddenBrakeThreshold,
    'sharpTurnThreshold': sharpTurnThreshold,
    'adaptiveLearningEnabled': adaptiveLearningEnabled,
  };

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    retentionDays: json['retentionDays'] as int,
    minDrivingSpeed: (json['minDrivingSpeed'] as num).toDouble(),
    speedLimit: (json['speedLimit'] as num).toDouble(),
    suddenAccThreshold: (json['suddenAccThreshold'] as num).toDouble(),
    suddenBrakeThreshold: (json['suddenBrakeThreshold'] as num).toDouble(),
    sharpTurnThreshold: (json['sharpTurnThreshold'] as num).toDouble(),
    adaptiveLearningEnabled: json['adaptiveLearningEnabled'] as bool? ?? false,
  );
}
