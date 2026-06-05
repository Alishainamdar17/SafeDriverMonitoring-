// lib/services/firebase_drive_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/drive.dart';

class FirebaseDriveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GPS throttle — write at most once every 5 seconds
  DateTime? _lastRouteWrite;

  // ───────────────────────────────────────────────────────────────────────────
  // 1. START DRIVE
  // ───────────────────────────────────────────────────────────────────────────
  Future<String> startDrive(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('drives')
        .add({
      'startTime': FieldValue.serverTimestamp(),
      'status': 'active',
    });
    debugPrint('🚗 Drive doc created: ${doc.id}');
    return doc.id;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. LIVE UPDATE  (single merged doc — no spam)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> updateLiveData(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('live_tracking')
          .doc('current_drive')
          .set({
        ...data,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ updateLiveData error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. ADD GPS ROUTE POINT  (throttled to 1 write per 5 s)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> addRoutePoint(
    String userId,
    String driveId,
    LocationPoint point,
  ) async {
    final now = DateTime.now();
    if (_lastRouteWrite != null &&
        now.difference(_lastRouteWrite!).inSeconds < 5) {
      return; // too soon — skip
    }
    _lastRouteWrite = now;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('drives')
          .doc(driveId)
          .collection('route_points')
          .add(point.toFirebaseMap());
    } catch (e) {
      debugPrint('❌ addRoutePoint error: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. END DRIVE  — saves all fields + marks status: completed
  //    All flat params are required so fromFirestore() can read them back.
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> endDrive(
    String userId,
    String driveId,
    Drive drive, {
    required double safetyScore,
    required int hardBrakeCount,
    required int hardAccelCount,
    required int sharpTurnCount,
    required int overSpeedCount,
    required double maxSpeed,
    required double distanceMeters,
    required String startLocation,
    required String endLocation,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('drives')
          .doc(driveId)
          .set({
        // Full Drive model (averageSpeed, durationSeconds, etc.)
        ...drive.toFirebaseMap(),

        // ← THIS field is what getDriveHistory() filters on
        'status': 'completed',
        'endTime': FieldValue.serverTimestamp(),

        // Flat fields — LiveDriveSession.fromFirestore() reads these directly
        'safetyScore': safetyScore,
        'hardBrakeCount': hardBrakeCount,
        'hardAccelCount': hardAccelCount,
        'sharpTurnCount': sharpTurnCount,
        'overSpeedCount': overSpeedCount,
        'maxSpeed': maxSpeed,
        'distanceMeters': distanceMeters,
        'startLocation': startLocation,
        'endLocation': endLocation,
      }, SetOptions(merge: true));

      debugPrint('✅ endDrive saved: $driveId');
    } catch (e) {
      debugPrint('❌ endDrive error: $e');
      rethrow; // let LiveDriveState.endDrive() catch it
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. GET DRIVE HISTORY
  //    Requires a composite Firestore index on:
  //      collection: drives  |  status ASC  |  startTime DESC
  //    Firebase will print the index-creation URL in the debug console
  //    the first time this query runs — just tap it.
  // ───────────────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDriveHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('drives')
          .where('status', isEqualTo: 'completed')
          .orderBy('startTime', descending: true)
          .limit(50)
          .get();

      final result = snapshot.docs
          .map((d) => {'firestoreId': d.id, ...d.data()})
          .toList();

      debugPrint('📋 getDriveHistory: ${result.length} drives loaded');
      return result;
    } catch (e) {
      debugPrint('❌ getDriveHistory error: $e');
      return [];
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 6. DELETE A DRIVE  (for swipe-to-delete in DriveHistoryPage)
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> deleteDrive(String userId, String driveId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('drives')
          .doc(driveId)
          .delete();
      debugPrint('🗑️ Drive deleted: $driveId');
    } catch (e) {
      debugPrint('❌ deleteDrive error: $e');
    }
  }
}