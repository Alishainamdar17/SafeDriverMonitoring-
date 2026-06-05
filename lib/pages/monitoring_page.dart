// lib/pages/monitoring_page.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_drive_monitor/services/eye_detection_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_drive_monitor/services/firebase_drive_service.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage>
    with TickerProviderStateMixin {

  // 🔥 FIREBASE VARIABLES
  late FirebaseDriveService _firebaseService;
  String userId = "test_user";
  String? driveId;                         // ✅ nullable String — proper null safety

  late EyeDetectionService _eyeDetectionService;
  EyeDetectionData? _latestEyeData;
  bool _isInitialized = false;
  String _statusMessage = 'Initializing camera...';

  // ── Blink flash animation ─────────────────────────────────────────────────
  late AnimationController _blinkFlashController;
  late Animation<double> _blinkFlashAnimation;

  // ── Alert pulse animation ─────────────────────────────────────────────────
  late AnimationController _alertPulseController;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseDriveService();

    _blinkFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _blinkFlashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blinkFlashController, curve: Curves.easeOut),
    );

    _alertPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _initializeEyeDetection();
  }

  Future<void> _initializeEyeDetection() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isDenied) {
        setState(() => _statusMessage = 'Camera permission denied');
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera found');
        return;
      }

      _eyeDetectionService = EyeDetectionService();
      await _eyeDetectionService.initialize(cameras);

      // ✅ FIX: wrap in try-catch, store as nullable
      try {
        driveId = await _firebaseService.startDrive(userId);
        debugPrint('✅ Drive started in Firebase: $driveId');
      } catch (e) {
        debugPrint('❌ Firebase startDrive failed: $e');
        // Continue without Firebase — app still works offline
      }

      DateTime lastSave = DateTime.now();

      _eyeDetectionService.eyeDetectionStream.listen((eyeData) async {
        if (!mounted) return;

        if (eyeData.isBlinking) {
          _blinkFlashController.forward(from: 0.0);
        }

        setState(() => _latestEyeData = eyeData);

        // ── FIREBASE UPLOAD (every 1 second) ──────────────────────────────
        if (driveId != null &&
            DateTime.now().difference(lastSave).inSeconds >= 1) {
          try {
            debugPrint('📤 Uploading to Firebase | driveId: $driveId');

            // ✅ FIX: save under BOTH paths so data is accessible everywhere
            // Path 1: live_drives/{driveId}  ← for real-time monitoring
            await FirebaseFirestore.instance
                .collection('live_drives')
                .doc(driveId!)
                .set({
              'userId': userId,
              'blinkCount': eyeData.blinkCount,
              'blinksPerMinute': eyeData.blinksPerMinute,
              'safetyLevel': eyeData.safetyLevel,
              'isHeadDropping': eyeData.isHeadDropping,
              'leftEyeOpen': eyeData.leftEyeOpen,
              'rightEyeOpen': eyeData.rightEyeOpen,
              'headMovement': eyeData.headMovement.toString(),
              'noFaceDetected': eyeData.noFaceDetected,
              'headEulerX': eyeData.headEulerAngleX,
              'headEulerY': eyeData.headEulerAngleY,
              'headEulerZ': eyeData.headEulerAngleZ,
              'status': eyeData.status,
              'timestamp': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            // Path 2: users/{userId}/drives/{driveId}  ← linked to drive record
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('drives')
                .doc(driveId!)
                .set({
              'latestEyeData': {
                'blinkCount': eyeData.blinkCount,
                'blinksPerMinute': eyeData.blinksPerMinute,
                'safetyLevel': eyeData.safetyLevel,
                'isHeadDropping': eyeData.isHeadDropping,
                'status': eyeData.status,
                'timestamp': FieldValue.serverTimestamp(),
              },
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            lastSave = DateTime.now();
            debugPrint('✅ Firebase upload success');
          } catch (e) {
            debugPrint('❌ Firebase upload error: $e');
          }
        }
        // ──────────────────────────────────────────────────────────────────
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Camera ready';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Error: $e');
      }
      debugPrint('❌ _initializeEyeDetection error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Driver Monitoring'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Firebase status indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: driveId != null ? Colors.greenAccent : Colors.red,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'Test ambulance siren',
            onPressed: _isInitialized
                ? () => _eyeDetectionService.testAlarmSound()
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset blink count',
            onPressed: _isInitialized
                ? () {
                    _eyeDetectionService.resetBlinkCount();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Blink count reset')),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: _isInitialized ? _buildMonitoringBody() : _buildLoadingBody(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MONITORING BODY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMonitoringBody() {
    final data = _latestEyeData;
    final isDangerous =
        data != null && (data.isHeadDropping || data.bothEyesClosed);

    return Stack(
      children: [
        CameraPreview(_eyeDetectionService.cameraController),

        if (isDangerous)
          AnimatedBuilder(
            animation: _alertPulseController,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red
                      .withOpacity(0.4 + _alertPulseController.value * 0.4),
                  width: 8,
                ),
              ),
            ),
          ),

        AnimatedBuilder(
          animation: _blinkFlashAnimation,
          builder: (_, __) => Opacity(
            opacity: (1.0 - _blinkFlashAnimation.value) * 0.25,
            child: Container(color: Colors.white),
          ),
        ),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(0, 0, 0, 0.82),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusBadge(data),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildEyeIndicator(
                      'Left Eye',
                      data?.leftEyeOpen,
                      data?.leftEyeOpenProbability,
                    ),
                    _buildEyeIndicator(
                      'Right Eye',
                      data?.rightEyeOpen,
                      data?.rightEyeOpenProbability,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildSafetyBar(data),
                const SizedBox(height: 14),
                Divider(color: Colors.grey[700], height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildBlinkStats(data)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildHeadMovementPanel(data)),
                  ],
                ),
                const SizedBox(height: 14),
                _buildHeadAnglesRow(data),
                const SizedBox(height: 8),
                // ── Firebase status row ──────────────────────────────────
                Row(
                  children: [
                    Icon(
                      driveId != null ? Icons.cloud_done : Icons.cloud_off,
                      size: 14,
                      color: driveId != null ? Colors.greenAccent : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      driveId != null
                          ? 'Firebase: $driveId'
                          : 'Firebase: not connected',
                      style: TextStyle(
                        color: driveId != null
                            ? Colors.greenAccent
                            : Colors.red[300],
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATUS BADGE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStatusBadge(EyeDetectionData? data) {
    final safetyLevel = data?.safetyLevel ?? 50;
    final isDangerous = safetyLevel == 0;

    return AnimatedBuilder(
      animation: _alertPulseController,
      builder: (_, __) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDangerous
                ? Color.lerp(
                    Colors.red,
                    Colors.red.shade900,
                    _alertPulseController.value,
                  )!
                : _getStatusColor(safetyLevel),
            borderRadius: BorderRadius.circular(10),
            boxShadow: isDangerous
                ? [
                    BoxShadow(
                      color: Colors.red.withOpacity(
                        0.3 + _alertPulseController.value * 0.4,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            data?.status ?? 'Waiting for face detection...',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEyeIndicator(String label, bool? isOpen, double? probability) {
    return Column(
      children: [
        Icon(
          isOpen == true ? Icons.remove_red_eye : Icons.visibility_off,
          color: isOpen == true ? Colors.green : Colors.red,
          size: 32,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        Text(
          '${((probability ?? 0.0) * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSafetyBar(EyeDetectionData? data) {
    final level = data?.safetyLevel ?? 50;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: level / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[700],
            valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(level)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Safety Level: $level%',
          style: TextStyle(color: Colors.grey[300], fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBlinkStats(EyeDetectionData? data) {
    final blinkCount = data?.blinkCount ?? 0;
    final bpm = data?.blinksPerMinute ?? 0.0;
    final highBpm = data?.isHighBlinkRate ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highBpm ? Colors.orange.withOpacity(0.6) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye, size: 14, color: Colors.cyan),
              const SizedBox(width: 6),
              Text(
                'BLINK',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$blinkCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('Total blinks',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.speed,
                  size: 12,
                  color: highBpm ? Colors.orange : Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '${bpm.toStringAsFixed(1)} / min',
                style: TextStyle(
                  color: highBpm ? Colors.orange : Colors.grey[300],
                  fontSize: 12,
                  fontWeight: highBpm ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          if (highBpm) ...[
            const SizedBox(height: 4),
            Text(
              '⚠ High rate — fatigue',
              style: TextStyle(color: Colors.orange[300], fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeadMovementPanel(EyeDetectionData? data) {
    final movement = data?.headMovement ?? HeadMovement.straight;
    final isDropping = data?.isHeadDropping ?? false;
    final isStraight = movement == HeadMovement.straight;

    Color panelBorderColor = Colors.transparent;
    Color iconColor = Colors.green;
    IconData movementIcon = Icons.face;

    if (isDropping) {
      panelBorderColor = Colors.red.withOpacity(0.7);
      iconColor = Colors.red;
      movementIcon = Icons.arrow_downward;
    } else if (!isStraight) {
      panelBorderColor = Colors.orange.withOpacity(0.6);
      iconColor = Colors.orange;
      movementIcon = _getHeadMovementIcon(movement);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: panelBorderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal,
                  size: 14, color: Colors.cyan),
              const SizedBox(width: 6),
              Text(
                'NECK',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(movementIcon, size: 28, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isStraight ? 'Straight' : _movementShortLabel(movement),
                  style: TextStyle(
                    color: isStraight ? Colors.green : iconColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isDropping
                ? '🆘 HEAD DROPPING!'
                : isStraight
                    ? 'Head position normal'
                    : data?.headMovementLabel ?? '',
            style: TextStyle(
              color: isDropping
                  ? Colors.red[300]
                  : isStraight
                      ? Colors.grey[500]
                      : Colors.orange[300],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadAnglesRow(EyeDetectionData? data) {
    final x = data?.headEulerAngleX.toStringAsFixed(1) ?? '—';
    final y = data?.headEulerAngleY.toStringAsFixed(1) ?? '—';
    final z = data?.headEulerAngleZ.toStringAsFixed(1) ?? '—';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildAngleTile('Pitch (X)', x, 'Nod ↕', Colors.cyan),
        _buildAngleTile('Yaw (Y)', y, 'Turn ↔', Colors.lime),
        _buildAngleTile('Roll (Z)', z, 'Tilt ↗', Colors.amber),
      ],
    );
  }

  Widget _buildAngleTile(String axis, String value, String hint, Color color) {
    return Column(
      children: [
        Text(
          '$value°',
          style:
              TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(axis, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
        Text(hint, style: TextStyle(color: Colors.grey[600], fontSize: 9)),
      ],
    );
  }

  Widget _buildLoadingBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.deepPurple),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int safetyLevel) {
    if (safetyLevel >= 80) return Colors.green;
    if (safetyLevel >= 40) return Colors.orange;
    return Colors.red;
  }

  IconData _getHeadMovementIcon(HeadMovement movement) {
    switch (movement) {
      case HeadMovement.nodding:     return Icons.arrow_downward;
      case HeadMovement.tiltedLeft:  return Icons.rotate_left;
      case HeadMovement.tiltedRight: return Icons.rotate_right;
      case HeadMovement.turnedLeft:  return Icons.arrow_back;
      case HeadMovement.turnedRight: return Icons.arrow_forward;
      case HeadMovement.straight:    return Icons.face;
    }
  }

  String _movementShortLabel(HeadMovement movement) {
    switch (movement) {
      case HeadMovement.nodding:     return 'Nodding';
      case HeadMovement.tiltedLeft:  return 'Tilt Left';
      case HeadMovement.tiltedRight: return 'Tilt Right';
      case HeadMovement.turnedLeft:  return 'Turn Left';
      case HeadMovement.turnedRight: return 'Turn Right';
      case HeadMovement.straight:    return 'Straight';
    }
  }

  @override
  void dispose() {
    _blinkFlashController.dispose();
    _alertPulseController.dispose();
    if (_isInitialized) {
      _eyeDetectionService.dispose();
    }
    super.dispose();
  }
}