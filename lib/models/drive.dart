// lib/models/drive.dart

class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double speed; // ← added

  const LocationPoint({
    required this.latitude, 
    required this.longitude,
    required this.timestamp,
    this.speed = 0.0, // default so old call-sites without speed still compile
  });

  Map<String, dynamic> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'ts':  timestamp.millisecondsSinceEpoch,
      };

  Map<String, dynamic> toFirebaseMap() => {
        'lat':       latitude,
        'lng':       longitude,
        'speed':     speed,
        'timestamp': timestamp.toIso8601String(),
      };
}

class Drive {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double averageSpeed;
  final int overSpeedDurationSeconds;
  final Map<int, int> suddenAccelerations;
  final Map<int, int> suddenBrakings;
  final Map<int, int> sharpTurns;
  final List<LocationPoint> routePoints;

  Drive({
    this.id,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    required this.averageSpeed,
    required this.overSpeedDurationSeconds,
    required this.suddenAccelerations,
    required this.suddenBrakings,
    required this.sharpTurns,
    this.routePoints = const [],
  });

  // ── SQLite ────────────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'start_time':          startTime.millisecondsSinceEpoch,
      'end_time':            endTime?.millisecondsSinceEpoch,
      'duration_seconds':    durationSeconds,
      'average_speed':       averageSpeed,
      'over_speed_duration': overSpeedDurationSeconds,
      'sudden_acc_groups':   _intMapToJson(suddenAccelerations),
      'sudden_brake_groups': _intMapToJson(suddenBrakings),
      'sharp_turn_groups':   _intMapToJson(sharpTurns),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Drive.fromMap(Map<String, dynamic> map) => Drive(
        id:                       map['id'] as int?,
        startTime:                DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
        endTime:                  map['end_time'] != null
                                      ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
                                      : null,
        durationSeconds:          map['duration_seconds'] as int,
        averageSpeed:             (map['average_speed'] as num).toDouble(),
        overSpeedDurationSeconds: map['over_speed_duration'] as int,
        suddenAccelerations:      _intMapFromJson(map['sudden_acc_groups']),
        suddenBrakings:           _intMapFromJson(map['sudden_brake_groups']),
        sharpTurns:               _intMapFromJson(map['sharp_turn_groups']),
        routePoints:              [],
      );

  Map<String, dynamic> toJson()              => toMap();
  factory Drive.fromJson(Map<String, dynamic> json) => Drive.fromMap(json);

  // ── Firebase ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toFirebaseMap() => {
        'id':                     id,
        'startTime':              startTime.toIso8601String(),
        'endTime':                endTime?.toIso8601String(),
        'durationSeconds':        durationSeconds,
        'averageSpeed':           averageSpeed,
        'overSpeedDurationSeconds': overSpeedDurationSeconds,
        // int keys → string for Firestore
        'suddenAccelerations':    suddenAccelerations.map((k, v) => MapEntry(k.toString(), v)),
        'suddenBrakings':         suddenBrakings.map((k, v) => MapEntry(k.toString(), v)),
        'sharpTurns':             sharpTurns.map((k, v) => MapEntry(k.toString(), v)),
        'routePoints':            routePoints.map((e) => e.toFirebaseMap()).toList(),
      };

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _intMapToJson(Map<int, int> map) {
    if (map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static Map<int, int> _intMapFromJson(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return {};
    try {
      return Map.fromEntries(
        raw.toString().split(',').map((entry) {
          final parts = entry.split(':');
          return MapEntry(int.parse(parts[0]), int.parse(parts[1]));
        }),
      );
    } catch (_) {
      return {};
    }
  }
}
