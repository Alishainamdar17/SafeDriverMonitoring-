// lib/services/eye_detection_service.dart
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum HeadMovement {
  straight,
  nodding,
  tiltedLeft,
  tiltedRight,
  turnedLeft,
  turnedRight,
}

class BlinkEvent {
  final DateTime timestamp;
  final int blinkCount;
  final double blinksPerMinute;
  const BlinkEvent({
    required this.timestamp,
    required this.blinkCount,
    required this.blinksPerMinute,
  });
}

class EyeDetectionData {
  final bool leftEyeOpen;
  final bool rightEyeOpen;
  final double leftEyeOpenProbability;
  final double rightEyeOpenProbability;
  final DateTime timestamp;
  final bool noFaceDetected;
  final int blinkCount;
  final double blinksPerMinute;
  final bool isBlinking;
  final double headEulerAngleX;
  final double headEulerAngleY;
  final double headEulerAngleZ;
  final HeadMovement headMovement;
  final bool isHeadDropping;

  const EyeDetectionData({
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.leftEyeOpenProbability,
    required this.rightEyeOpenProbability,
    required this.timestamp,
    this.noFaceDetected = false,
    this.blinkCount = 0,
    this.blinksPerMinute = 0.0,
    this.isBlinking = false,
    this.headEulerAngleX = 0.0,
    this.headEulerAngleY = 0.0,
    this.headEulerAngleZ = 0.0,
    this.headMovement = HeadMovement.straight,
    this.isHeadDropping = false,
  });

  bool get bothEyesOpen => leftEyeOpen && rightEyeOpen;
  bool get bothEyesClosed => !leftEyeOpen && !rightEyeOpen;
  bool get oneEyeClosed =>
      (leftEyeOpen && !rightEyeOpen) || (!leftEyeOpen && rightEyeOpen);
  bool get isHighBlinkRate => blinksPerMinute > 25.0;

  String get headMovementLabel {
    switch (headMovement) {
      case HeadMovement.straight:
        return 'Head Straight';
      case HeadMovement.nodding:
        return '⚠️ Head Dropping';
      case HeadMovement.tiltedLeft:
        return '⚠️ Tilted Left';
      case HeadMovement.tiltedRight:
        return '⚠️ Tilted Right';
      case HeadMovement.turnedLeft:
        return '⚡ Turned Left';
      case HeadMovement.turnedRight:
        return '⚡ Turned Right';
    }
  }

  String get status {
    if (noFaceDetected) return '📷 No face detected - position your face';
    if (isHeadDropping) return '🆘 HEAD DROPPING - Drowsy!';
    if (bothEyesClosed) return '⚠️ DROWSY - Both eyes closed!';
    if (oneEyeClosed) return '⚡ WARNING - One eye closed';
    if (headMovement != HeadMovement.straight) return headMovementLabel;
    if (bothEyesOpen) return '✅ ALERT - Both eyes open';
    return 'Waiting for face...';
  }

  int get safetyLevel {
    if (noFaceDetected) return 50;
    if (isHeadDropping || bothEyesClosed) return 0;
    if (oneEyeClosed) return 30;
    if (headMovement == HeadMovement.nodding) return 10;
    if (headMovement == HeadMovement.tiltedLeft ||
        headMovement == HeadMovement.tiltedRight) return 40;
    if (headMovement == HeadMovement.turnedLeft ||
        headMovement == HeadMovement.turnedRight) return 60;
    if (isHighBlinkRate) return 70;
    if (bothEyesOpen) return 100;
    return 50;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  EYE DETECTION SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class EyeDetectionService {
  // ── Face detector ──────────────────────────────────────────────────────────
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  // ── Alert cooldown ─────────────────────────────────────────────────────────
  String _lastSpokenAlert = '';
  static const Duration _alertCooldown = Duration(seconds: 4);
  DateTime _lastAlertTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Drowsiness: 10 seconds of both-eyes-closed → alarm ────────────────────
  // Camera runs ~15–20 fps. 10 sec × 15 fps = ~150 frames.
  // We use a real timer instead of frame count for accuracy.
  DateTime? _eyesClosedSince;         // when both eyes first closed
  static const Duration _eyesClosedAlarmDelay = Duration(seconds: 10);

  // ── No-face: 10 seconds of no face detected → alarm ───────────────────────
  DateTime? _noFaceSince;             // when face first disappeared
  static const Duration _noFaceAlarmDelay = Duration(seconds: 10);

  // ── Blink tracking ─────────────────────────────────────────────────────────
  bool _eyesWereClosed = false;
  int _totalBlinkCount = 0;
  final List<DateTime> _blinkTimestamps = [];
  static const Duration _blinkRateWindow = Duration(minutes: 1);

  final StreamController<BlinkEvent> _blinkEventStream =
      StreamController<BlinkEvent>.broadcast();
  Stream<BlinkEvent> get blinkEventStream => _blinkEventStream.stream;

  // ── Head movement thresholds ───────────────────────────────────────────────
  // FIX: tighter thresholds + eulerY is LEFT/RIGHT turn, eulerZ is tilt
  static const double _headDropThreshold = -20.0;  // eulerX < -20 → nodding
  static const double _headTiltThreshold = 15.0;   // |eulerZ| > 15 → tilt
  static const double _headTurnThreshold = 25.0;   // |eulerY| > 25 → turn

  // Head drop: sustained frames (kept for extra safety alongside timer)
  static const int _headDropFrameThreshold = 8;
  int _headDropFrameCount = 0;

  // ── Camera ─────────────────────────────────────────────────────────────────
  late CameraController _cameraController;
  late CameraDescription _cameraDescription;
  final StreamController<EyeDetectionData> _eyeDetectionStream =
      StreamController<EyeDetectionData>.broadcast();
  bool _isDetecting = false;

  Stream<EyeDetectionData> get eyeDetectionStream => _eyeDetectionStream.stream;
  CameraController get cameraController => _cameraController;

  // ── Siren channel ──────────────────────────────────────────────────────────
  static const MethodChannel _sirenChannel = MethodChannel('safe_drive/siren');
  bool _isAlarmPlaying = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> initialize(List<CameraDescription> cameras) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception('Camera permission not granted');

    try {
      _cameraDescription = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    } catch (_) {
      _cameraDescription = cameras.first;
    }

    _cameraController = CameraController(
      _cameraDescription,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController.initialize();
    _startEyeDetection();
  }

  // ── Detection loop ─────────────────────────────────────────────────────────
  void _startEyeDetection() {
    _cameraController.startImageStream((image) async {
      if (_isDetecting) return;
      _isDetecting = true;
      try {
        await _detectEyes(image);
      } catch (e) {
        debugPrint('Stream error: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<void> _detectEyes(CameraImage image) async {
    final inputImage = _convertCameraImageToInputImage(image);
    if (inputImage == null) return;

    try {
      final faces = await _faceDetector.processImage(inputImage);
      final now = DateTime.now();

      if (faces.isNotEmpty) {
        // ── Face found → reset no-face timer ────────────────────────────────
        _noFaceSince = null;

        final face = faces.first;
        final leftEyeProb  = face.leftEyeOpenProbability  ?? 0.0;
        final rightEyeProb = face.rightEyeOpenProbability ?? 0.0;
        final eyesCurrentlyClosed = leftEyeProb < 0.5 && rightEyeProb < 0.5;

        // ── 10-second eyes-closed timer ──────────────────────────────────────
        if (eyesCurrentlyClosed) {
          _eyesClosedSince ??= now;   // start timer on first closed frame
        } else {
          _eyesClosedSince = null;    // reset when eyes open
        }

        // ── Blink detection (closed → open transition) ─────────────────────
        bool justBlinked = false;
        if (_eyesWereClosed && !eyesCurrentlyClosed) {
          _totalBlinkCount++;
          justBlinked = true;
          _blinkTimestamps.add(now);
          _blinkTimestamps.removeWhere(
            (t) => now.difference(t) > _blinkRateWindow,
          );
          _blinkEventStream.add(BlinkEvent(
            timestamp: now,
            blinkCount: _totalBlinkCount,
            blinksPerMinute: _blinkTimestamps.length.toDouble(),
          ));
          debugPrint('BLINK #$_totalBlinkCount | BPM: ${_blinkTimestamps.length}');
        }
        _eyesWereClosed = eyesCurrentlyClosed;

        // ── Head euler angles ────────────────────────────────────────────────
        //  eulerX (Pitch) : positive = look up, negative = look down / nod
        //  eulerY (Yaw)   : positive = turned RIGHT, negative = turned LEFT
        //  eulerZ (Roll)  : positive = tilted LEFT,  negative = tilted RIGHT
        final eulerX = face.headEulerAngleX ?? 0.0;
        final eulerY = face.headEulerAngleY ?? 0.0;
        final eulerZ = face.headEulerAngleZ ?? 0.0;

        final headMovement = _classifyHeadMovement(eulerX, eulerY, eulerZ);

        // ── Head drop frame accumulator ──────────────────────────────────────
        if (eulerX < _headDropThreshold) {
          _headDropFrameCount++;
        } else {
          _headDropFrameCount = 0;
        }
        final isHeadDropping = _headDropFrameCount >= _headDropFrameThreshold;

        _blinkTimestamps.removeWhere(
          (t) => now.difference(t) > _blinkRateWindow,
        );

        debugPrint(
          'EYES L:${leftEyeProb.toStringAsFixed(2)} '
          'R:${rightEyeProb.toStringAsFixed(2)} | '
          'X:${eulerX.toStringAsFixed(1)} '
          'Y:${eulerY.toStringAsFixed(1)} '
          'Z:${eulerZ.toStringAsFixed(1)} | '
          'Move:$headMovement | HeadDrop:$isHeadDropping',
        );

        final data = EyeDetectionData(
          leftEyeOpen: leftEyeProb > 0.5,
          rightEyeOpen: rightEyeProb > 0.5,
          leftEyeOpenProbability: leftEyeProb,
          rightEyeOpenProbability: rightEyeProb,
          timestamp: now,
          noFaceDetected: false,
          blinkCount: _totalBlinkCount,
          blinksPerMinute: _blinkTimestamps.length.toDouble(),
          isBlinking: justBlinked,
          headEulerAngleX: eulerX,
          headEulerAngleY: eulerY,
          headEulerAngleZ: eulerZ,
          headMovement: headMovement,
          isHeadDropping: isHeadDropping,
        );

        _eyeDetectionStream.add(data);
        _handleAlerts(data, now);

      } else {
        // ── No face detected ─────────────────────────────────────────────────
        _headDropFrameCount = 0;
        _eyesWereClosed = false;
        _eyesClosedSince = null;  // reset eyes-closed timer when no face

        // Start / keep no-face timer
        _noFaceSince ??= now;
        final noFaceDuration = now.difference(_noFaceSince!);

        debugPrint(
          '⚠️ No face detected for ${noFaceDuration.inSeconds}s',
        );

        // Fire alarm after 10 seconds of no face
        if (noFaceDuration >= _noFaceAlarmDelay) {
          if (!_isAlarmPlaying) {
            debugPrint('🚨 No face for 10s → playing alarm');
            await _playAmbulanceSiren();
          }
          final cooldownPassed =
              now.difference(_lastAlertTime) > _alertCooldown;
          if (cooldownPassed) {
            await _speakAlert(
              'Warning! Driver not visible. Please look at the camera.',
            );
            _lastAlertTime = now;
          }
        }

        _eyeDetectionStream.add(EyeDetectionData(
          leftEyeOpen: false,
          rightEyeOpen: false,
          leftEyeOpenProbability: 0.0,
          rightEyeOpenProbability: 0.0,
          timestamp: now,
          noFaceDetected: true,
          blinkCount: _totalBlinkCount,
          blinksPerMinute: _blinkTimestamps.length.toDouble(),
        ));
      }
    } catch (e, stack) {
      debugPrint('Detection error: $e\n$stack');
    }
  }

  // ── Head movement classifier (FIXED) ──────────────────────────────────────
  //  Priority order matters — head-drop first, then tilt, then turn.
  HeadMovement _classifyHeadMovement(
      double eulerX, double eulerY, double eulerZ) {
    // 1. Nod / head drop (eulerX strongly negative)
    if (eulerX < _headDropThreshold) return HeadMovement.nodding;

    // 2. Roll/tilt (eulerZ)
    //    eulerZ > +threshold → tilted LEFT (Roll towards driver's left shoulder)
    //    eulerZ < -threshold → tilted RIGHT
    if (eulerZ > _headTiltThreshold)  return HeadMovement.tiltedLeft;
    if (eulerZ < -_headTiltThreshold) return HeadMovement.tiltedRight;

    // 3. Yaw/turn (eulerY)
    //    eulerY > +threshold → turned RIGHT
    //    eulerY < -threshold → turned LEFT
    if (eulerY > _headTurnThreshold)  return HeadMovement.turnedRight;
    if (eulerY < -_headTurnThreshold) return HeadMovement.turnedLeft;

    return HeadMovement.straight;
  }

  // ── Alert handler ──────────────────────────────────────────────────────────
  void _handleAlerts(EyeDetectionData data, DateTime now) {
    final cooldownPassed = now.difference(_lastAlertTime) > _alertCooldown;

    // ── CRITICAL 1: Head dropping → ambulance siren immediately ───────────
    if (data.isHeadDropping) {
      if (!_isAlarmPlaying) _playAmbulanceSiren();
      if (cooldownPassed) {
        _speakAlert('Danger! Your head is dropping. You are falling asleep!');
        _lastAlertTime = now;
      }
      return;
    }

    // ── CRITICAL 2: Both eyes closed for 10 seconds → alarm ───────────────
    if (data.bothEyesClosed && _eyesClosedSince != null) {
      final closedDuration = now.difference(_eyesClosedSince!);
      debugPrint(
        '👁 Both eyes closed for ${closedDuration.inSeconds}s',
      );

      if (closedDuration >= _eyesClosedAlarmDelay) {
        if (!_isAlarmPlaying) {
          debugPrint('🚨 Eyes closed 10s → playing alarm');
          _playAmbulanceSiren();
        }
        if (cooldownPassed) {
          _speakAlert(
            'Warning! You are drowsy. Please pull over and rest.',
          );
          _lastAlertTime = now;
        }
        return;
      }
    }

    // Eyes open / no longer critical → stop alarm
    if (!data.bothEyesClosed && !data.isHeadDropping) {
      if (_isAlarmPlaying) _stopAlarm();
    }

    // ── Mild alerts (voice only) ───────────────────────────────────────────
    if (data.oneEyeClosed &&
        _lastSpokenAlert != 'one_eye' &&
        cooldownPassed) {
      _speakAlert('Caution! One eye closed. Stay alert.');
      _lastAlertTime = now;
      _lastSpokenAlert = 'one_eye';
      return;
    }

    if ((data.headMovement == HeadMovement.tiltedLeft ||
            data.headMovement == HeadMovement.tiltedRight) &&
        _lastSpokenAlert != 'tilt' &&
        cooldownPassed) {
      _speakAlert('Warning! Your head is tilting. Stay focused.');
      _lastAlertTime = now;
      _lastSpokenAlert = 'tilt';
      return;
    }

    if ((data.headMovement == HeadMovement.turnedLeft ||
            data.headMovement == HeadMovement.turnedRight) &&
        _lastSpokenAlert != 'turn' &&
        cooldownPassed) {
      _speakAlert('Keep your eyes on the road!');
      _lastAlertTime = now;
      _lastSpokenAlert = 'turn';
      return;
    }

    if (data.isHighBlinkRate &&
        _lastSpokenAlert != 'blink_rate' &&
        cooldownPassed) {
      _speakAlert(
        'High blink rate detected. You may be fatigued. Consider taking a break.',
      );
      _lastAlertTime = now;
      _lastSpokenAlert = 'blink_rate';
      return;
    }

    // All clear
    if (data.bothEyesOpen && data.headMovement == HeadMovement.straight) {
      _lastSpokenAlert = '';
    }
  }

  // ── Ambulance siren ────────────────────────────────────────────────────────
  Future<void> _playAmbulanceSiren() async {
    try {
      if (_isAlarmPlaying) return;
      _isAlarmPlaying = true;
      await _sirenChannel.invokeMethod('play');
      debugPrint('🚑 Siren STARTED');
    } catch (e) {
      debugPrint('Siren channel error: $e');
      _isAlarmPlaying = false;
      HapticFeedback.heavyImpact();
      await _speakAlert('DANGER! WAKE UP! Pull over NOW!');
    }
  }

  Future<void> _stopAlarm() async {
    try {
      if (!_isAlarmPlaying) return;
      await _sirenChannel.invokeMethod('stop');
      _isAlarmPlaying = false;
      debugPrint('🔕 Siren STOPPED');
    } catch (e) {
      debugPrint('Alarm stop error: $e');
    }
  }

  Future<void> _speakAlert(String message) async {
    _lastSpokenAlert = message;
    debugPrint('🔊 ALERT: $message');
    HapticFeedback.heavyImpact();
  }

  // ── Public test methods ────────────────────────────────────────────────────
  Future<void> testVoiceAlert() async {
    await _speakAlert('Voice alert test.');
  }

  Future<void> testAlarmSound() async {
    debugPrint('🧪 Testing siren...');
    await _playAmbulanceSiren();
    await Future.delayed(const Duration(seconds: 4));
    await _stopAlarm();
  }

  void resetBlinkCount() {
    _totalBlinkCount = 0;
    _blinkTimestamps.clear();
  }

  // ── Image conversion ───────────────────────────────────────────────────────
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final rotation = _getRotationForDevice();
      final inputImageFormat = switch (image.format.group) {
        ImageFormatGroup.yuv420   => InputImageFormat.yuv420,
        ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
        ImageFormatGroup.nv21     => InputImageFormat.nv21,
        _                         => InputImageFormat.nv21,
      };

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  InputImageRotation _getRotationForDevice() {
    final orientation = _cameraDescription.sensorOrientation;
    if (_cameraDescription.lensDirection == CameraLensDirection.front) {
      switch (orientation) {
        case 90:  return InputImageRotation.rotation90deg;
        case 270: return InputImageRotation.rotation270deg;
        case 180: return InputImageRotation.rotation180deg;
        default:  return InputImageRotation.rotation0deg;
      }
    }
    return _rotationIntToInputImageRotation(orientation);
  }

  InputImageRotation _rotationIntToInputImageRotation(int rotation) {
    switch (rotation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────────
  Future<void> dispose() async {
    try { await _cameraController.stopImageStream(); } catch (_) {}
    await _cameraController.dispose();
    await _eyeDetectionStream.close();
    await _blinkEventStream.close();
    await _faceDetector.close();
    try { await _stopAlarm(); } catch (_) {}
  }
}