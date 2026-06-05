class DrivingRecord {
  final int? id;
  final int? driveId;
  final DateTime timestamp;
  final double speed;
  final double latitude;
  final double longitude;
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double totalAcceleration;
  final bool isSuddenAcceleration;
  final bool isSuddenBraking;
  final bool isSharpTurn;
  // NEW: Eye detection fields
  final bool? leftEyeOpen;
  final bool? rightEyeOpen;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final bool? isDrowsy;

  DrivingRecord({
    this.id,
    this.driveId,
    required this.timestamp,
    required this.speed,
    required this.latitude,
    required this.longitude,
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.totalAcceleration,
    required this.isSuddenAcceleration,
    required this.isSuddenBraking,
    required this.isSharpTurn,
    // NEW
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.isDrowsy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'drive_id': driveId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'speed': speed,
      'latitude': latitude,
      'longitude': longitude,
      'accelerationX': accelerationX,
      'accelerationY': accelerationY,
      'accelerationZ': accelerationZ,
      'totalAcceleration': totalAcceleration,
      'isSuddenAcceleration': isSuddenAcceleration ? 1 : 0,
      'isSuddenBraking': isSuddenBraking ? 1 : 0,
      'isSharpTurn': isSharpTurn ? 1 : 0,
      // NEW
      'leftEyeOpen': leftEyeOpen != null ? (leftEyeOpen! ? 1 : 0) : null,
      'rightEyeOpen': rightEyeOpen != null ? (rightEyeOpen! ? 1 : 0) : null,
      'leftEyeOpenProbability': leftEyeOpenProbability,
      'rightEyeOpenProbability': rightEyeOpenProbability,
      'isDrowsy': isDrowsy != null ? (isDrowsy! ? 1 : 0) : null,
    };
  }

  static DrivingRecord fromMap(Map<String, dynamic> map) {
    return DrivingRecord(
      id: map['id'],
      driveId: map['drive_id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      speed: map['speed'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      accelerationX: map['accelerationX'],
      accelerationY: map['accelerationY'],
      accelerationZ: map['accelerationZ'],
      totalAcceleration: map['totalAcceleration'],
      isSuddenAcceleration: map['isSuddenAcceleration'] == 1,
      isSuddenBraking: map['isSuddenBraking'] == 1,
      isSharpTurn: map['isSharpTurn'] == 1,
      // NEW
      leftEyeOpen: map['leftEyeOpen'] != null ? map['leftEyeOpen'] == 1 : null,
      rightEyeOpen: map['rightEyeOpen'] != null ? map['rightEyeOpen'] == 1 : null,
      leftEyeOpenProbability: map['leftEyeOpenProbability']?.toDouble(),
      rightEyeOpenProbability: map['rightEyeOpenProbability']?.toDouble(),
      isDrowsy: map['isDrowsy'] != null ? map['isDrowsy'] == 1 : null,
    );
  }
}
