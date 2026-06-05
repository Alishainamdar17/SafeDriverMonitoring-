// lib/services/live_drive_state.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  COMPLETED SESSION MODEL
// ─────────────────────────────────────────────────────────────────────────────
class LiveDriveSession {
  final DateTime startTime;
  final DateTime endTime;
  final String  startLocation;
  final String  endLocation;
  final double  distanceKm;
  final double  maxSpeed;
  final double  avgSpeed;
  final int     hardBrakeCount;
  final int     hardAccelCount;
  final int     sharpTurnCount;
  final int     overSpeedCount;
  final double  safetyScore;
  final List<Map<String, double>> routePoints;

  LiveDriveSession({
    required this.startTime,
    required this.endTime,
    required this.startLocation,
    required this.endLocation,
    required this.distanceKm,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.hardBrakeCount,
    required this.hardAccelCount,
    required this.sharpTurnCount,
    required this.overSpeedCount,
    required this.safetyScore,
    required this.routePoints,
  });

  Duration get duration => endTime.difference(startTime);

  double get currentSpeed => avgSpeed;

  String get grade {
    if (safetyScore >= 90) return 'A+';
    if (safetyScore >= 80) return 'A';
    if (safetyScore >= 70) return 'B';
    if (safetyScore >= 55) return 'C';
    return 'D';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'status'                   : 'completed',
      'userId'                   : FirebaseAuth.instance.currentUser?.uid ?? '',
      'startTime'                : Timestamp.fromDate(startTime),
      'endTime'                  : Timestamp.fromDate(endTime),
      'startLocation'            : startLocation,
      'endLocation'              : endLocation,
      'durationSeconds'          : duration.inSeconds,
      'distanceKm'               : distanceKm,
      'maxSpeed'                 : maxSpeed,
      'averageSpeed'             : avgSpeed,
      'safetyScore'              : safetyScore,
      'suddenBrakings'           : {'total': hardBrakeCount},
      'suddenAccelerations'      : {'total': hardAccelCount},
      'sharpTurns'               : {'total': sharpTurnCount},
      'overSpeedDurationSeconds' : overSpeedCount * 30,
      'routePoints'              : routePoints.take(500).map((p) => {
        'lat': p['lat'],
        'lng': p['lng'],
      }).toList(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIVE SESSION WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveSession {
  final DateTime startTime;
  final String   startLocation;
  double distanceKm  = 0;
  double maxSpeed    = 0;
  double _totalSpeed = 0;
  int    _speedTicks = 0;
  int    hardBrakeCount = 0;
  int    hardAccelCount = 0;
  int    sharpTurnCount = 0;
  int    overSpeedCount = 0;
  double safetyScore    = 100.0;
  double _currentSpeed  = 0;
  final List<Map<String, double>> routePoints = [];

  _ActiveSession({required this.startTime, required this.startLocation});

  double get avgSpeed     => _speedTicks > 0 ? _totalSpeed / _speedTicks : 0.0;
  double get currentSpeed => _currentSpeed;

  void updateSpeed(double speed, double distDelta) {
    _currentSpeed  = speed;
    distanceKm    += distDelta / 1000.0;
    if (speed > maxSpeed) maxSpeed = speed;
    _totalSpeed   += speed;
    _speedTicks++;
  }

  void deductScore(double amount) {
    safetyScore = (safetyScore - amount).clamp(0.0, 100.0);
  }

  LiveDriveSession toCompleted(DateTime endTime, String endLocation) {
    return LiveDriveSession(
      startTime     : startTime,
      endTime       : endTime,
      startLocation : startLocation,
      endLocation   : endLocation,
      distanceKm    : distanceKm,
      maxSpeed      : maxSpeed,
      avgSpeed      : avgSpeed,
      hardBrakeCount: hardBrakeCount,
      hardAccelCount: hardAccelCount,
      sharpTurnCount: sharpTurnCount,
      overSpeedCount: overSpeedCount,
      safetyScore   : safetyScore,
      routePoints   : List.from(routePoints),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIVE DRIVE STATE  (singleton ChangeNotifier)
// ─────────────────────────────────────────────────────────────────────────────
class LiveDriveState extends ChangeNotifier {
  LiveDriveState._();
  static final LiveDriveState instance = LiveDriveState._();

  // ── Active drive ───────────────────────────────────────────────────────────
  _ActiveSession? _active;
  String?         _docId;

  // ── Completed sessions (in-memory) ─────────────────────────────────────────
  final List<LiveDriveSession> _history = [];

  // ── All-time aggregates ────────────────────────────────────────────────────
  double   _totalDistanceKm  = 0.0;
  Duration _totalDriveTime   = Duration.zero;
  double   _scoreSum         = 0.0;
  int      _totalHardBrakes  = 0;
  int      _totalHardAccels  = 0;
  int      _totalSharpTurns  = 0;
  int      _totalOverSpeeds  = 0;

  // ── Firebase sync debounce ─────────────────────────────────────────────────
  Timer? _syncTimer;
  bool   _pendingSync = false;

  // ── Firestore collection (single source of truth) ─────────────────────────
  static const String _kCollection = 'live_drives';

  // ─────────────────────────────────────────────────────────────────────────
  //  PUBLIC GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  bool get isDriveActive => _active != null;
  bool get hasDrive      => _active != null;

  LiveDriveSession? get current {
    final a = _active;
    if (a == null) return null;
    return LiveDriveSession(
      startTime     : a.startTime,
      endTime       : DateTime.now(),
      startLocation : a.startLocation,
      endLocation   : '',
      distanceKm    : a.distanceKm,
      maxSpeed      : a.maxSpeed,
      avgSpeed      : a.avgSpeed,
      hardBrakeCount: a.hardBrakeCount,
      hardAccelCount: a.hardAccelCount,
      sharpTurnCount: a.sharpTurnCount,
      overSpeedCount: a.overSpeedCount,
      safetyScore   : a.safetyScore,
      routePoints   : List.from(a.routePoints),
    );
  }

  double get currentSpeed    => _active?._currentSpeed ?? 0.0;
  double get distanceKm      => _active?.distanceKm    ?? 0.0;
  double get maxSpeed        => _active?.maxSpeed       ?? 0.0;
  double get avgSpeed        => _active?.avgSpeed       ?? 0.0;
  double get safetyScore     => _active?.safetyScore    ?? 100.0;

  List<LiveDriveSession> get history => List.unmodifiable(_history);

  int      get totalTrips        => _history.length;
  double   get totalDistanceKm   => _totalDistanceKm;
  Duration get totalDriveTime    => _totalDriveTime;
  double   get allTimeAvgScore   =>
      _history.isNotEmpty ? _scoreSum / _history.length : 0.0;

  int get totalHardBrakes  => _totalHardBrakes;
  int get totalHardAccels  => _totalHardAccels;
  int get totalSharpTurns  => _totalSharpTurns;
  int get totalOverSpeeds  => _totalOverSpeeds;

  // ─────────────────────────────────────────────────────────────────────────
  //  START DRIVE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> startDrive(String location) async {
    if (_active != null) return;

    _active = _ActiveSession(
      startTime     : DateTime.now(),
      startLocation : location,
    );
    _docId = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // ✅ FIXED: save to 'live_drives' collection with 'userId' field
        final ref = await FirebaseFirestore.instance
            .collection(_kCollection)
            .add({
          'status'        : 'live',
          'startTime'     : Timestamp.fromDate(_active!.startTime),
          'startLocation' : location,
          'userId'        : uid,   // ← 'userId' not 'uid'
        });
        _docId = ref.id;
        debugPrint('✅ Drive started: $_docId');
      }
    } catch (e) {
      debugPrint('❌ startDrive error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  UPDATE SPEED + DISTANCE + ROUTE
  // ─────────────────────────────────────────────────────────────────────────
  void updateSpeed({
    required double speed,
    required double distanceDelta,
    double? latitude,
    double? longitude,
  }) {
    final a = _active;
    if (a == null) return;

    a.updateSpeed(speed, distanceDelta);

    if (latitude != null && longitude != null) {
      a.routePoints.add({'lat': latitude, 'lng': longitude});
    }

    notifyListeners();
    _scheduleLiveSync();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EVENT METHODS
  // ─────────────────────────────────────────────────────────────────────────
  void addHardBrake() {
    final a = _active;
    if (a == null) return;
    a.hardBrakeCount++;
    a.deductScore(5);
    notifyListeners();
    _scheduleLiveSync();
  }

  void addHardAccel() {
    final a = _active;
    if (a == null) return;
    a.hardAccelCount++;
    a.deductScore(3);
    notifyListeners();
    _scheduleLiveSync();
  }

  void addSharpTurn() {
    final a = _active;
    if (a == null) return;
    a.sharpTurnCount++;
    a.deductScore(4);
    notifyListeners();
    _scheduleLiveSync();
  }

  void addOverSpeed() {
    final a = _active;
    if (a == null) return;
    a.overSpeedCount++;
    a.deductScore(5);
    notifyListeners();
    _scheduleLiveSync();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LIVE SYNC (debounced)
  // ─────────────────────────────────────────────────────────────────────────
  void _scheduleLiveSync() {
    if (_pendingSync) return;
    _pendingSync = true;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), _writeLiveSync);
  }

  Future<void> _writeLiveSync() async {
    _pendingSync = false;
    final a = _active;
    if (a == null || _docId == null) return;
    try {
      // ✅ FIXED: correct collection path
      await FirebaseFirestore.instance
          .collection(_kCollection)
          .doc(_docId!)
          .update({
        'status'                   : 'live',
        'currentSpeed'             : a.currentSpeed,
        'distanceKm'               : a.distanceKm,
        'maxSpeed'                 : a.maxSpeed,
        'averageSpeed'             : a.avgSpeed,
        'safetyScore'              : a.safetyScore,
        'suddenBrakings'           : {'total': a.hardBrakeCount},
        'suddenAccelerations'      : {'total': a.hardAccelCount},
        'sharpTurns'               : {'total': a.sharpTurnCount},
        'overSpeedDurationSeconds' : a.overSpeedCount * 30,
        'lastUpdated'              : FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ liveSync error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  END DRIVE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> endDrive(String endLocation) async {
    final a = _active;
    if (a == null) {
      debugPrint('⚠️ endDrive: no active drive');
      return;
    }

    final endTime = DateTime.now();

    // 1. Build completed session BEFORE clearing _active
    final completed = a.toCompleted(endTime, endLocation);

    // 2. Add to in-memory history
    _history.insert(0, completed);

    // 3. Update all-time aggregates
    _totalDistanceKm += completed.distanceKm;
    _totalDriveTime  += completed.duration;
    _scoreSum        += completed.safetyScore;
    _totalHardBrakes += completed.hardBrakeCount;
    _totalHardAccels += completed.hardAccelCount;
    _totalSharpTurns += completed.sharpTurnCount;
    _totalOverSpeeds += completed.overSpeedCount;

    // 4. Clear active session
    _active = null;
    _syncTimer?.cancel();
    _pendingSync = false;

    // 5. Notify UI
    notifyListeners();

    // 6. Write to Firestore
    final docIdToUpdate = _docId;
    _docId = null;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        if (docIdToUpdate != null) {
          // ✅ FIXED: correct collection path
          await FirebaseFirestore.instance
              .collection(_kCollection)
              .doc(docIdToUpdate)
              .update(completed.toFirestore());
          debugPrint('✅ Drive saved: $docIdToUpdate');
        } else {
          // Fallback: startDrive Firebase call may have failed
          await FirebaseFirestore.instance
              .collection(_kCollection)
              .add(completed.toFirestore());
          debugPrint('✅ Drive saved (fallback)');
        }
      }
    } catch (e) {
      debugPrint('❌ endDrive Firebase error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOAD HISTORY FROM FIREBASE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> loadHistory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // ✅ FIXED: query 'live_drives' with 'userId' filter
      final snap = await FirebaseFirestore.instance
          .collection(_kCollection)
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      final loaded = <LiveDriveSession>[];

      for (final doc in snap.docs) {
        try {
          final d = doc.data();
          debugPrint('📄 Loading doc ${doc.id}: $d');

          DateTime startTime = DateTime.now();
          DateTime endTime   = DateTime.now();
          try {
            if (d['startTime'] is Timestamp) {
              startTime = (d['startTime'] as Timestamp).toDate();
            }
            if (d['endTime'] is Timestamp) {
              endTime = (d['endTime'] as Timestamp).toDate();
            }
          } catch (_) {}

          final brakes  = _foldEventMap(d['suddenBrakings']);
          final accels  = _foldEventMap(d['suddenAccelerations']);
          final turns   = _foldEventMap(d['sharpTurns']);
          final overSec = (d['overSpeedDurationSeconds'] as num?)?.toInt() ?? 0;
          final distKm  = (d['distanceKm'] as num?)?.toDouble() ??
              _calcDistFromSpeed(d);

          double score = (d['safetyScore'] as num?)?.toDouble() ?? 0;
          if (score == 0) {
            score = (100.0 - brakes * 5 - accels * 3 - turns * 4 -
                (overSec ~/ 30) * 5).clamp(0.0, 100.0);
          }

          loaded.add(LiveDriveSession(
            startTime     : startTime,
            endTime       : endTime,
            startLocation : (d['startLocation'] as String?) ?? '',
            endLocation   : (d['endLocation']   as String?) ?? '',
            distanceKm    : distKm,
            maxSpeed      : (d['maxSpeed']       as num?)?.toDouble() ?? 0,
            avgSpeed      : (d['averageSpeed']   as num?)?.toDouble() ?? 0,
            hardBrakeCount: brakes,
            hardAccelCount: accels,
            sharpTurnCount: turns,
            overSpeedCount: overSec ~/ 30,
            safetyScore   : score,
            routePoints   : [],
          ));
        } catch (e) {
          debugPrint('⚠️ Skipping malformed drive doc ${doc.id}: $e');
        }
      }

      // Only insert Firebase history that isn't already in memory
      final existingStarts = _history.map((s) => s.startTime).toSet();
      for (final s in loaded) {
        if (!existingStarts.contains(s.startTime)) {
          _history.add(s);
        }
      }
      _history.sort((a, b) => b.startTime.compareTo(a.startTime));

      _rebuildAggregates();
      notifyListeners();
      debugPrint('✅ loadHistory: ${_history.length} trips loaded');
    } catch (e) {
      debugPrint('❌ loadHistory error: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  int _foldEventMap(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) return raw;
    if (raw is Map) {
      return raw.values.fold<int>(0, (s, v) => s + ((v as num?)?.toInt() ?? 0));
    }
    return 0;
  }

  double _calcDistFromSpeed(Map<String, dynamic> d) {
    final speed = (d['averageSpeed'] as num?)?.toDouble() ?? 0;
    final secs  = (d['durationSeconds'] as num?)?.toDouble() ?? 0;
    return (speed * secs) / 3600;
  }

  void _rebuildAggregates() {
    _totalDistanceKm = 0;
    _totalDriveTime  = Duration.zero;
    _scoreSum        = 0;
    _totalHardBrakes = 0;
    _totalHardAccels = 0;
    _totalSharpTurns = 0;
    _totalOverSpeeds = 0;

    for (final s in _history) {
      _totalDistanceKm += s.distanceKm;
      _totalDriveTime  += s.duration;
      _scoreSum        += s.safetyScore;
      _totalHardBrakes += s.hardBrakeCount;
      _totalHardAccels += s.hardAccelCount;
      _totalSharpTurns += s.sharpTurnCount;
      _totalOverSpeeds += s.overSpeedCount;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}