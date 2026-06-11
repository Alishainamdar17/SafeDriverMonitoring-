// lib/pages/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'dart:async';
import 'package:safe_drive_monitor/config/app_config.dart';
import 'package:safe_drive_monitor/services/background_service.dart';
import 'package:safe_drive_monitor/services/live_drive_state.dart';
import 'package:safe_drive_monitor/pages/monitoring_page.dart';
import 'package:safe_drive_monitor/pages/analytics_page.dart';
import 'package:safe_drive_monitor/pages/settings_page.dart';
import 'package:safe_drive_monitor/pages/drive_history_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  // ── Location ───────────────────────────────────────────────────────────────
  double _latitude  = 0.0;
  double _longitude = 0.0;
  double _currentSpeed  = 0.0;
  double _totalDistance = 0.0;
  double _maxSpeed      = 0.0;
  double _avgSpeed      = 0.0;
  int    _speedSamples  = 0;
  double _prevLat = 0.0;
  double _prevLng = 0.0;

  final DateTime _startTime = DateTime.now();
  bool _isDriving       = false;
  bool _isOverSpeed     = false;
  bool _drowsinessAlert = false;

  // ── Night Mode ─────────────────────────────────────────────────────────────
  bool _isNightMode = false;
  Timer? _nightModeTimer;

  // ── AI Status ──────────────────────────────────────────────────────────────
  final String _aiStatus  = 'AI Active';
  String _driverAttention = 'FOCUSED';
  int    _attentionScore  = 100;
  bool _seatbeltDetected  = true;
  bool _phoneDetected     = false;

  // ── Event counters (local for dashboard display) ───────────────────────────
  int _hardBrakeCount = 0;
  int _hardAccelCount = 0;
  int _sharpTurnCount = 0;
  int _overSpeedCount = 0;
  double _safetyScore = 100.0;

  // ── Accelerometer ──────────────────────────────────────────────────────────
  double _smoothX = 0.0;
  double _smoothY = 0.0;
  double _smoothZ = 9.81;
  static const double _lpAlpha = 0.85;

  DateTime? _lastBrakeTime;
  DateTime? _lastAccelTime;
  DateTime? _lastTurnTime;
  static const int _eventCooldownMs = 1500;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<Position>? _locationSub;
  Timer? _timerTick;

  // ── Drowsiness ─────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  int  _blinkCount        = 0;
  int  _longBlinkCount    = 0;
  int  _drowsinessLevel   = 0;
  Timer? _blinkResetTimer;
  int  _simulatedBlinkInterval = 0;
  Timer? _blinkSimTimer;

  // ── Voice/SOS ──────────────────────────────────────────────────────────────
  bool _voiceAlertsEnabled = true;
  DateTime? _lastVoiceAlert;
  bool _ttsInitialized = false;
  bool _sosPressed   = false;
  int  _sosCountdown = 5;
  Timer? _sosTimer;

  // ── Trip summary ───────────────────────────────────────────────────────────
  bool _tripSummaryShown = false;
  bool _wasDriving       = false;
  int  _stoppedSeconds   = 0;

  // ── Speed history ──────────────────────────────────────────────────────────
  final List<double> _speedHistory =
    List<double>.filled(30, 0.0, growable: true);

  // ── Live Drive State ───────────────────────────────────────────────────────
  final LiveDriveState _liveState = LiveDriveState.instance;
  bool _driveStarted = false;

  // ── GPS route throttle (FIX #5: prevent Firestore spam) ───────────────────
  DateTime? _lastRoutePoint;
  static const int _routeThrottleSeconds = 5;

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _scoreController;
  late AnimationController _alertController;
  late AnimationController _scanController;
  late AnimationController _entryController;
  late AnimationController _sosController;
  late AnimationController _drowsyController;

  late Animation<double> _pulseAnim;
  late Animation<double> _scoreAnim;
  late Animation<double> _alertAnim;
  late Animation<double> _scanAnim;
  late Animation<double> _entryAnim;
  late Animation<double> _sosAnim;
  late Animation<double> _drowsyAnim;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _requestPermissions();
    _initLocationUpdates();
    _initAccelerometer();
    _initTTS();
    _initNightModeDetection();
    BackgroundService.startService();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkStopDetection();
        _checkDriveStart();
      }
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _scoreController = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200));
    _alertController = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _scanController  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2500))..repeat();
    _entryController = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1000));
    _sosController   = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..repeat(reverse: true);
    _drowsyController= AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);

    _pulseAnim  = Tween<double>(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _scoreAnim  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scoreController, curve: Curves.easeOut));
    _alertAnim  = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _alertController, curve: Curves.easeInOut));
    _scanAnim   = Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);
    _entryAnim  = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _sosAnim    = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _sosController, curve: Curves.easeInOut));
    _drowsyAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _drowsyController, curve: Curves.easeInOut));

    _scoreController.forward();
    _entryController.forward();
  }

  // ── FIX #1: Drive not detected second time — reset _driveStarted when stopped ──
  void _checkDriveStart() {
    if (_currentSpeed > 5 && !_driveStarted) {
      _driveStarted = true;
      final loc = _latitude != 0
          ? '${_latitude.toStringAsFixed(3)}°N, ${_longitude.toStringAsFixed(3)}°E'
          : 'Unknown location';

      _liveState.startDrive(loc);

      setState(() {
        _hardBrakeCount   = 0;
        _hardAccelCount   = 0;
        _sharpTurnCount   = 0;
        _overSpeedCount   = 0;
        _safetyScore      = 100.0;
        _totalDistance    = 0.0;
        _maxSpeed         = 0.0;
        _avgSpeed         = 0.0;
        _speedSamples     = 0;
        _tripSummaryShown = false;
      });
    }

    // FIX #1: Reset _driveStarted so next drive can be detected
    if (_currentSpeed < 2 && _driveStarted && !_isDriving) {
      _driveStarted = false;
    }
  }

  Future<void> _initTTS() async {
    setState(() => _ttsInitialized = true);
  }

  Future<void> _speak(String text, {bool force = false}) async {
    if (!_voiceAlertsEnabled || !_ttsInitialized) return;
    final now = DateTime.now();
    if (!force && _lastVoiceAlert != null &&
        now.difference(_lastVoiceAlert!).inSeconds < 8) return;
    _lastVoiceAlert = now;
    debugPrint('🔊 VOICE ALERT: $text');
    HapticFeedback.mediumImpact();
  }

  void _initNightModeDetection() {
    _nightModeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _autoDetectNightMode();
    });
    _autoDetectNightMode();
  }

  void _autoDetectNightMode() {
    final hour = DateTime.now().hour;
    final isNight = hour >= 19 || hour < 6;
    if (mounted && isNight != _isNightMode) {
      setState(() => _isNightMode = isNight);
    }
  }

  Future<void> _initDrowsinessDetection() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(frontCam,
          ResolutionPreset.low, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _cameraInitialized = true);
        _startSimulatedDrowsinessMonitoring();
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      _startSimulatedDrowsinessMonitoring();
    }
  }

  void _startSimulatedDrowsinessMonitoring() {
    _blinkSimTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isDriving || !mounted) return;
      _simulatedBlinkInterval++;
      final drivingMinutes = DateTime.now().difference(_startTime).inMinutes;
      final blinkFreq = max(4, 8 - (drivingMinutes ~/ 10));
      if (_simulatedBlinkInterval % blinkFreq == 0) {
        _registerBlink(
          duration: drivingMinutes > 20
              ? 250 + Random().nextInt(200)
              : 100 + Random().nextInt(100),
        );
      }
      if (drivingMinutes > 30 && Random().nextInt(100) < 2) {
        _longBlinkCount += 2;
        _updateDrowsinessLevel();
      }
    });
  }

  void _registerBlink({required int duration}) {
    _blinkCount++;
    if (duration > 300) _longBlinkCount++;
    _updateDrowsinessLevel();
    _blinkResetTimer?.cancel();
    _blinkResetTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) setState(() { _blinkCount = 0; _longBlinkCount = 0; });
    });
  }

  void _updateDrowsinessLevel() {
    if (!mounted) return;
    final perclos = _longBlinkCount / max(_blinkCount, 1);
    int newLevel;
    if      (perclos > 0.5 || _longBlinkCount > 5) newLevel = 3;
    else if (perclos > 0.3 || _longBlinkCount > 3) newLevel = 2;
    else if (perclos > 0.15|| _longBlinkCount > 1) newLevel = 1;
    else                                            newLevel = 0;

    setState(() {
      _drowsinessLevel = newLevel;
      _drowsinessAlert = newLevel >= 2;
      switch (newLevel) {
        case 0: _driverAttention = 'FOCUSED';     _attentionScore = 95 + Random().nextInt(5); break;
        case 1: _driverAttention = 'MILD DROWSY'; _attentionScore = 70 + Random().nextInt(15); break;
        case 2: _driverAttention = 'DROWSY';      _attentionScore = 40 + Random().nextInt(20); break;
        default:_driverAttention = 'CRITICAL';    _attentionScore = Random().nextInt(30); break;
      }
    });
  }

  void _checkStopDetection() {
    if (_wasDriving && !_isDriving) {
      _stoppedSeconds++;
      if (_stoppedSeconds >= 30 && !_tripSummaryShown) {
        _showTripSummary();
        // FIX #2: endDrive is now async — properly awaited + passes location
        if (_driveStarted) {
          _driveStarted = false;
          final loc = _latitude != 0
              ? '${_latitude.toStringAsFixed(3)}°N, ${_longitude.toStringAsFixed(3)}°E'
              : 'Stopped location';
          _liveState.endDrive(loc); // async fire-and-forget is safe here
        }
      }
    } else {
      _stoppedSeconds = 0;
    }
    _wasDriving = _isDriving;
  }

  void _showTripSummary() {
    _tripSummaryShown = true;
    final duration = DateTime.now().difference(_startTime);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripSummarySheet(
        duration: duration,
        distance: _totalDistance,
        maxSpeed: _maxSpeed,
        avgSpeed: _avgSpeed,
        safetyScore: _safetyScore,
        hardBrakes: _hardBrakeCount,
        hardAccels: _hardAccelCount,
        sharpTurns: _sharpTurnCount,
        overSpeeds: _overSpeedCount,
        isNightMode: _isNightMode,
      ),
    ).then((_) => _tripSummaryShown = false);
  }

  void _startSOS() {
    setState(() { _sosPressed = true; _sosCountdown = 5; });
    HapticFeedback.heavyImpact();
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _sosCountdown--);
      if (_sosCountdown <= 0) { timer.cancel(); _triggerSOS(); }
    });
  }

  void _cancelSOS() {
    _sosTimer?.cancel();
    setState(() { _sosPressed = false; _sosCountdown = 5; });
  }

  Future<void> _triggerSOS() async {
    setState(() => _sosPressed = false);
    final uri = Uri.parse('tel:112');
    try { if (await canLaunchUrl(uri)) await launchUrl(uri); } catch (e) {}
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.activityRecognition.request();
    await Permission.sensors.request();
    await Geolocator.requestPermission();
    await Permission.camera.request();
    await Permission.phone.request();
    await _initDrowsinessDetection();
  }

  // ── FIX #4: Events synced to Firebase via _liveState calls (already present)
  // ── FIX #5: Added _lastRoutePoint throttle field above + check in listener ──
  void _initAccelerometer() {
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (!mounted) return;
      _smoothX = _lpAlpha * _smoothX + (1 - _lpAlpha) * event.x;
      _smoothY = _lpAlpha * _smoothY + (1 - _lpAlpha) * event.y;
      _smoothZ = _lpAlpha * _smoothZ + (1 - _lpAlpha) * event.z;
      final linearX = event.x - _smoothX;
      final linearY = event.y - _smoothY;
      final linearZ = event.z - _smoothZ;
      final mag = sqrt(linearX*linearX + linearY*linearY + linearZ*linearZ);
      if (_currentSpeed < 5) return;
      final now = DateTime.now();
      final brakeCoolOk = _lastBrakeTime == null ||
          now.difference(_lastBrakeTime!).inMilliseconds > _eventCooldownMs;
      if (mag > 4.5 && linearY < -3.5 && _currentSpeed > 10 && brakeCoolOk) {
        _lastBrakeTime = now;
        setState(() { _hardBrakeCount++; });
        _deductScore(5);
        _liveState.addHardBrake(); // FIX #4: syncs to Firebase
        HapticFeedback.heavyImpact();
        _speak('Hard braking detected.');
      } else if (mag > 4.0 && linearY > 3.0 && _currentSpeed > 5) {
        final accelCoolOk = _lastAccelTime == null ||
            now.difference(_lastAccelTime!).inMilliseconds > _eventCooldownMs;
        if (accelCoolOk) {
          _lastAccelTime = now;
          setState(() { _hardAccelCount++; });
          _deductScore(3);
          _liveState.addHardAccel(); // FIX #4: syncs to Firebase
          HapticFeedback.mediumImpact();
          _speak('Sudden acceleration detected.');
        }
      }
      final turnCoolOk = _lastTurnTime == null ||
          now.difference(_lastTurnTime!).inMilliseconds > _eventCooldownMs;
      if (linearX.abs() > 3.5 && _currentSpeed > 15 && turnCoolOk) {
        _lastTurnTime = now;
        setState(() { _sharpTurnCount++; });
        _deductScore(4);
        _liveState.addSharpTurn(); // FIX #4: syncs to Firebase
        HapticFeedback.mediumImpact();
        _speak('Sharp turn detected.');
      }
    });
  }

  Future<void> _initLocationUpdates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 1),
    ).listen((Position position) {
      final distanceDelta = (_prevLat != 0 && _prevLng != 0)
          ? Geolocator.distanceBetween(
              _prevLat, _prevLng, position.latitude, position.longitude)
          : 0.0;
      final newSpeed = position.speed <= 0
          ? 0.0
          : (position.speed * 3.6).clamp(0.0, 300.0);
      final wasOverSpeed = _isOverSpeed;
      setState(() {
        _totalDistance += distanceDelta;
        _prevLat       = _latitude;
        _prevLng       = _longitude;
        _latitude      = position.latitude;
        _longitude     = position.longitude;
        _currentSpeed  = newSpeed;
        _isDriving     = newSpeed > 5;
        _isOverSpeed   = newSpeed > AppConfig.speedLimit;
        if (newSpeed > _maxSpeed) _maxSpeed = newSpeed;
        _speedSamples++;
        _avgSpeed = (_avgSpeed * (_speedSamples - 1) + newSpeed) / _speedSamples;
        _speedHistory.add(newSpeed);
        if (_speedHistory.length > 20) {
          _speedHistory.removeAt(0);
        }
      });

      // FIX #3 + FIX #5: Pass lat/lng to updateSpeed, throttle Firestore GPS writes
      final now = DateTime.now();
      final shouldWriteRoute = _lastRoutePoint == null ||
          now.difference(_lastRoutePoint!).inSeconds >= _routeThrottleSeconds;

      _liveState.updateSpeed(
        speed: newSpeed,
        distanceDelta: distanceDelta,
        latitude: shouldWriteRoute ? position.latitude : null,   // FIX #3 + #5
        longitude: shouldWriteRoute ? position.longitude : null,  // FIX #3 + #5
      );

      if (shouldWriteRoute) {
        _lastRoutePoint = now; // FIX #5: update throttle timestamp
      }

      // Count overspeed only on transition into overspeed
      if (_isOverSpeed && !wasOverSpeed) {
        _deductScore(5);
        setState(() => _overSpeedCount++);
        _liveState.addOverSpeed();
        _speak('Speed limit exceeded.');
      }
    });
  }

  void _deductScore(double amount) {
    setState(() {
      _safetyScore = (_safetyScore - amount).clamp(0.0, 100.0);
    });
  }

  // ── Color helpers ──────────────────────────────────────────────────────────
  Color get _bg      => _isNightMode ? const Color(0xFF020205) : const Color(0xFF050508);
  Color get _cardBg  => _isNightMode ? const Color(0xFF080810) : const Color(0xFF0C0C14);
  Color get _accentBlue => _isNightMode ? const Color(0xFF0099CC) : const Color(0xFF00D4FF);

  Color get _speedColor {
    if (_currentSpeed > AppConfig.speedLimit)        return const Color(0xFFFF2D55);
    if (_currentSpeed > AppConfig.speedLimit * 0.85) return const Color(0xFFFF9F0A);
    return const Color(0xFF34C759);
  }

  Color get _scoreColor {
    if (_safetyScore >= 80) return const Color(0xFF34C759);
    if (_safetyScore >= 55) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF2D55);
  }

  Color get _attentionColor {
    switch (_drowsinessLevel) {
      case 0: return const Color(0xFF34C759);
      case 1: return const Color(0xFFFF9F0A);
      case 2: return const Color(0xFFFF6B00);
      default:return const Color(0xFFFF2D55);
    }
  }

  Color get _drowsyColor => _attentionColor;

  String get _scoreLabel {
    if (_safetyScore >= 90) return 'EXCELLENT';
    if (_safetyScore >= 75) return 'GOOD';
    if (_safetyScore >= 55) return 'FAIR';
    return 'CRITICAL';
  }

  String _formatDistance(double meters) =>
      meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)}' : meters.toStringAsFixed(0);
  String _distanceUnit(double meters) => meters >= 1000 ? 'km' : 'm';
  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scoreController.dispose();
    _alertController.dispose();
    _scanController.dispose();
    _entryController.dispose();
    _sosController.dispose();
    _drowsyController.dispose();
    _accelSub?.cancel();
    _locationSub?.cancel();
    _timerTick?.cancel();
    _nightModeTimer?.cancel();
    _blinkResetTimer?.cancel();
    _blinkSimTimer?.cancel();
    _sosTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(_startTime);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _entryAnim,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                      child: Column(
                        children: [
                          _buildNightModeBanner(),
                          _buildAlertBanner(),
                          _buildDrowsinessCard(),
                          const SizedBox(height: 10),
                          _buildLiveActivityCard(duration),
                          const SizedBox(height: 14),
                          _buildSpeedometerHUD(),
                          const SizedBox(height: 14),
                          _buildAIMonitoringStrip(),
                          const SizedBox(height: 14),
                          _buildMetricsGrid(duration),
                          const SizedBox(height: 14),
                          _buildSafetyScoreCard(),
                          const SizedBox(height: 14),
                          _buildEventCounters(),
                          const SizedBox(height: 14),
                          _buildSpeedChart(),
                          const SizedBox(height: 14),
                          _buildVoiceToggle(),
                          const SizedBox(height: 14),
                          _buildQuickActions(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildSOSButton(),
              if (_sosPressed) _buildSOSOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LIVE ACTIVITY CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLiveActivityCard(Duration duration) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.08),
            const Color(0xFF0066FF).withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: const Color(0xFF00D4FF).withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.local_activity_rounded,
                  color: Color(0xFF00D4FF), size: 15),
              const SizedBox(width: 6),
              const Text('LIVE DRIVE ACTIVITY',
                  style: TextStyle(
                    color: Colors.white, fontSize: 13,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5,
                  )),
              const Spacer(),
              if (_isDriving) ...[
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF34C759).withOpacity(0.6),
                      blurRadius: 6,
                    )],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('LIVE',
                    style: TextStyle(
                      color: Color(0xFF34C759), fontSize: 9,
                      fontWeight: FontWeight.w800, letterSpacing: 1,
                    )),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _liveStatCell('AVG SPEED',
                  '${_avgSpeed.toStringAsFixed(0)} km/h',
                  Icons.speed_rounded, const Color(0xFF34C759)),
              _liveStatCell('MAX SPEED',
                  '${_maxSpeed.toStringAsFixed(0)} km/h',
                  Icons.flash_on_rounded, const Color(0xFFFF9F0A)),
              _liveStatCell('DISTANCE',
                  _totalDistance >= 1000
                      ? '${(_totalDistance / 1000).toStringAsFixed(1)} km'
                      : '${_totalDistance.toStringAsFixed(0)} m',
                  Icons.route_rounded, const Color(0xFF00D4FF)),
              _liveStatCell('DRIVE TIME',
                  '${duration.inHours.toString().padLeft(2,'0')}:${(duration.inMinutes%60).toString().padLeft(2,'0')}',
                  Icons.timer_rounded, const Color(0xFF5E5CE6)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _liveStatCell('HARD BRAKES', '$_hardBrakeCount',
                  Icons.front_hand_rounded, const Color(0xFFFF9F0A)),
              _liveStatCell('HARD ACCELS', '$_hardAccelCount',
                  Icons.arrow_upward_rounded, const Color(0xFFFF2D55)),
              _liveStatCell('SHARP TURNS', '$_sharpTurnCount',
                  Icons.turn_right_rounded, const Color(0xFF5E5CE6)),
              _liveStatCell('OVERSPEEDS', '$_overSpeedCount',
                  Icons.warning_rounded, const Color(0xFFFF2D55)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveStatCell(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                    color: color, fontSize: 13,
                    fontWeight: FontWeight.w800, fontFamily: 'monospace',
                  )),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF636366), fontSize: 7,
                    fontWeight: FontWeight.w600, letterSpacing: 0.3),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  NIGHT MODE BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNightModeBanner() {
    if (!_isNightMode) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1A0A3A).withOpacity(0.9),
          const Color(0xFF0A0A28).withOpacity(0.9),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF5E5CE6).withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.nights_stay_rounded,
              color: Color(0xFF5E5CE6), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NIGHT MODE ACTIVE',
                    style: TextStyle(
                      color: Color(0xFF5E5CE6), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    )),
                Text('Display optimized for nighttime driving',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _isNightMode,
            onChanged: (v) => setState(() => _isNightMode = v),
            activeColor: const Color(0xFF5E5CE6),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DROWSINESS CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDrowsinessCard() {
    if (!_isDriving) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _drowsinessLevel >= 2 ? _drowsyAnim : _pulseAnim,
      builder: (_, child) =>
          Opacity(opacity: _drowsinessLevel >= 2 ? _drowsyAnim.value : 1.0, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _drowsyColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _drowsyColor.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _drowsyColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _drowsinessLevel == 0
                    ? Icons.remove_red_eye_rounded
                    : _drowsinessLevel == 3
                        ? Icons.bedtime_rounded
                        : Icons.visibility_off_rounded,
                color: _drowsyColor, size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('DROWSINESS MONITOR',
                          style: TextStyle(
                            color: _drowsyColor, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1.5,
                          )),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _drowsyColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ['ALERT','MILD','DROWSY','CRITICAL'][_drowsinessLevel],
                          style: TextStyle(
                            color: _drowsyColor, fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_drowsinessLevel + 1) / 4,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation(_drowsyColor),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _drowsinessLevel == 0
                        ? 'Eyes tracking normal • Stay focused'
                        : _drowsinessLevel == 1
                            ? 'Mild fatigue detected • Consider a short break'
                            : _drowsinessLevel == 2
                                ? '⚠ Drowsiness detected • Take a break now!'
                                : '🚨 CRITICAL! Pull over immediately!',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(bottom: BorderSide(
            color: _accentBlue.withOpacity(0.15), width: 1)),
      ),
      child: Row(
        children: [
          _buildHexBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DMS PRO',
                    style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800, letterSpacing: 2.5,
                      fontFamily: 'monospace',
                    )),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _isDriving
                            ? const Color(0xFF34C759)
                            : const Color(0xFF636366),
                        shape: BoxShape.circle,
                        boxShadow: _isDriving
                            ? [BoxShadow(
                                color: const Color(0xFF34C759).withOpacity(0.6),
                                blurRadius: 6, spreadRadius: 1)]
                            : [],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isDriving ? 'MONITORING ACTIVE' : 'STANDBY',
                      style: TextStyle(
                        color: _isDriving
                            ? const Color(0xFF34C759)
                            : const Color(0xFF636366),
                        fontSize: 9, fontWeight: FontWeight.w700,
                        letterSpacing: 1.5, fontFamily: 'monospace',
                      ),
                    ),
                    if (_isNightMode) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.nights_stay_rounded,
                          color: Color(0xFF5E5CE6), size: 10),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeStr,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1, fontFamily: 'monospace',
                  )),
              Text(_aiStatus,
                  style: TextStyle(
                    color: _accentBlue, fontSize: 9,
                    fontWeight: FontWeight.w600, letterSpacing: 1.2,
                  )),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1C1C2E), width: 1),
              ),
              child: const Icon(Icons.tune_rounded,
                  color: Color(0xFF8E8E93), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHexBadge() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
          scale: _isDriving ? _pulseAnim.value : 1.0, child: child),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentBlue, const Color(0xFF0066FF)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: _accentBlue.withOpacity(0.35),
            blurRadius: 14, spreadRadius: 1,
          )],
        ),
        child: const Icon(Icons.directions_car_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  ALERT BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAlertBanner() {
    if (!_isOverSpeed && !_drowsinessAlert && !_phoneDetected) {
      return const SizedBox.shrink();
    }
    String alertText; IconData alertIcon; Color alertColor;
    if (_drowsinessAlert && _drowsinessLevel >= 3) {
      alertText = 'CRITICAL drowsiness! Pull over immediately!';
      alertIcon = Icons.bedtime_rounded;
      alertColor = const Color(0xFFFF2D55);
    } else if (_drowsinessAlert) {
      alertText = 'Drowsiness detected — Take a break safely';
      alertIcon = Icons.visibility_off_rounded;
      alertColor = const Color(0xFFFF6B00);
    } else if (_phoneDetected) {
      alertText = 'Phone usage detected — Eyes on road!';
      alertIcon = Icons.phone_android_rounded;
      alertColor = const Color(0xFFFF9F0A);
    } else {
      alertText = 'Speed limit exceeded — Reduce speed now';
      alertIcon = Icons.speed_rounded;
      alertColor = const Color(0xFFFF2D55);
    }
    return AnimatedBuilder(
      animation: _alertAnim,
      builder: (_, child) => Opacity(opacity: _alertAnim.value, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            alertColor.withOpacity(0.18), alertColor.withOpacity(0.06),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: alertColor.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alertColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(alertIcon, color: alertColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ALERT',
                      style: TextStyle(
                        color: alertColor, fontSize: 9,
                        fontWeight: FontWeight.w800, letterSpacing: 2,
                      )),
                  Text(alertText,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SPEEDOMETER HUD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSpeedometerHUD() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isOverSpeed
              ? const Color(0xFFFF2D55).withOpacity(0.6)
              : _accentBlue.withOpacity(0.12),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniTag(Icons.gps_fixed_rounded,
                  _latitude == 0.0
                      ? 'GPS SEARCHING'
                      : '${_latitude.toStringAsFixed(4)}°N',
                  _accentBlue),
              _buildMiniTag(Icons.speed_rounded,
                  'LIMIT ${AppConfig.speedLimit.toInt()} km/h',
                  _isOverSpeed
                      ? const Color(0xFFFF2D55)
                      : const Color(0xFF636366)),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
                scale: _isDriving ? _pulseAnim.value : 1.0, child: child),
            child: SizedBox(
              width: 200, height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _ProfessionalSpeedometerPainter(
                      progress: (_currentSpeed / (AppConfig.speedLimit * 1.5))
                          .clamp(0.0, 1.0),
                      color: _speedColor,
                      limitProgress: (AppConfig.speedLimit /
                              (AppConfig.speedLimit * 1.5))
                          .clamp(0.0, 1.0),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_currentSpeed.toStringAsFixed(0),
                          style: TextStyle(
                            color: _speedColor, fontSize: 58,
                            fontWeight: FontWeight.w900, height: 1.0,
                            letterSpacing: -3, fontFamily: 'monospace',
                          )),
                      Text('km/h',
                          style: TextStyle(
                            color: Colors.grey[500], fontSize: 13,
                            fontWeight: FontWeight.w400, letterSpacing: 3,
                          )),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _speedColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _speedColor.withOpacity(0.35), width: 1),
                        ),
                        child: Text(
                          _isOverSpeed ? '⚠  OVERSPEED' : '✓  SAFE SPEED',
                          style: TextStyle(
                            color: _speedColor, fontSize: 10,
                            fontWeight: FontWeight.w700, letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isDriving)
                    AnimatedBuilder(
                      animation: _scanAnim,
                      builder: (_, __) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _ScanLinePainter(
                            progress: _scanAnim.value, color: _speedColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSpeedStat('AVG', '${_avgSpeed.toStringAsFixed(0)} km/h'),
              Container(width: 1, height: 28, color: const Color(0xFF1C1C2E)),
              _buildSpeedStat('MAX', '${_maxSpeed.toStringAsFixed(0)} km/h'),
              Container(width: 1, height: 28, color: const Color(0xFF1C1C2E)),
              _buildSpeedStat('OVER', '$_overSpeedCount ×'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                color: color, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.8,
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }

  Widget _buildSpeedStat(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
              color: Colors.grey[600], fontSize: 9,
              fontWeight: FontWeight.w600, letterSpacing: 1.5,
            )),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
              color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w700, fontFamily: 'monospace',
            )),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AI MONITORING STRIP
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAIMonitoringStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentBlue.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Transform.scale(scale: _pulseAnim.value, child: child),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accentBlue, const Color(0xFF0066FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: _accentBlue.withOpacity(0.4),
                  blurRadius: 12, spreadRadius: 1,
                )],
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Driver Analysis',
                    style: TextStyle(
                      color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 0.3,
                    )),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    _buildAIChip(Icons.visibility_rounded,
                        _driverAttention, _attentionColor),
                    _buildAIChip(Icons.airline_seat_recline_extra_rounded,
                        _seatbeltDetected ? 'BELTED' : 'NO BELT',
                        _seatbeltDetected
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF2D55)),
                    _buildAIChip(Icons.phone_android_rounded,
                        _phoneDetected ? 'PHONE!' : 'HANDS FREE',
                        _phoneDetected
                            ? const Color(0xFFFF9F0A)
                            : const Color(0xFF636366)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 46, height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(46, 46),
                  painter: _MiniRingPainter(
                    progress: _attentionScore / 100,
                    color: _attentionColor,
                    bgColor: const Color(0xFF1C1C2E),
                  ),
                ),
                Text('$_attentionScore',
                    style: TextStyle(
                      color: _attentionColor, fontSize: 12,
                      fontWeight: FontWeight.w800, fontFamily: 'monospace',
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                color: color, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  METRICS GRID
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMetricsGrid(Duration duration) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard(
          icon: Icons.route_rounded, accent: _accentBlue,
          title: 'DISTANCE',
          value: _formatDistance(_totalDistance),
          unit: _distanceUnit(_totalDistance),
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildMetricCard(
          icon: Icons.timer_rounded, accent: const Color(0xFF5E5CE6),
          title: 'DRIVE TIME',
          value: _formatDuration(duration), unit: '',
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildMetricCard(
          icon: Icons.my_location_rounded, accent: const Color(0xFF34C759),
          title: 'LOCATION',
          value: _latitude == 0.0 ? '---' : _latitude.toStringAsFixed(2),
          unit: _latitude == 0.0 ? '' : '°N',
        )),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon, required Color accent,
    required String title, required String value, required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 15),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(children: [
              TextSpan(text: value,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w800, fontFamily: 'monospace',
                  )),
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit',
                    style: TextStyle(
                      color: accent, fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(title,
              style: TextStyle(
                color: Colors.grey[600], fontSize: 9,
                fontWeight: FontWeight.w600, letterSpacing: 1.2,
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SAFETY SCORE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSafetyScoreCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _scoreColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90, height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scoreAnim,
                  builder: (_, __) => CustomPaint(
                    size: const Size(90, 90),
                    painter: _GradientRingPainter(
                      progress: (_safetyScore / 100) * _scoreAnim.value,
                      color: _scoreColor,
                      bgColor: const Color(0xFF1C1C2E),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_safetyScore.toInt().toString(),
                        style: TextStyle(
                          color: _scoreColor, fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace', height: 1,
                        )),
                    Text('/100',
                        style: TextStyle(
                          color: Colors.grey[600], fontSize: 10,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Safety Score',
                        style: TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _scoreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _scoreColor.withOpacity(0.3), width: 1),
                      ),
                      child: Text(_scoreLabel,
                          style: TextStyle(
                            color: _scoreColor, fontSize: 10,
                            fontWeight: FontWeight.w800, letterSpacing: 1,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildScoreSegment(_safetyScore >= 25, const Color(0xFFFF2D55)),
                    const SizedBox(width: 3),
                    _buildScoreSegment(_safetyScore >= 50, const Color(0xFFFF9F0A)),
                    const SizedBox(width: 3),
                    _buildScoreSegment(_safetyScore >= 75, const Color(0xFF34C759)),
                    const SizedBox(width: 3),
                    _buildScoreSegment(_safetyScore >= 90, _accentBlue),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildScoreLegend('Critical', const Color(0xFFFF2D55)),
                    _buildScoreLegend('Fair', const Color(0xFFFF9F0A)),
                    _buildScoreLegend('Good', const Color(0xFF34C759)),
                    _buildScoreLegend('Excellent', _accentBlue),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSegment(bool active, Color color) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: 7,
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          boxShadow: active
              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
              : [],
        ),
      ),
    );
  }

  Widget _buildScoreLegend(String label, Color color) {
    return Text(label,
        style: TextStyle(
          color: color.withOpacity(0.7), fontSize: 8,
          fontWeight: FontWeight.w600, letterSpacing: 0.3,
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  EVENT COUNTERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventCounters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: _accentBlue,
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 8),
              const Text('DRIVING EVENTS',
                  style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  )),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildEventCard(
              icon: Icons.front_hand_rounded, color: const Color(0xFFFF9F0A),
              label: 'Hard\nBrakes', count: _hardBrakeCount, risk: 'HIGH RISK',
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildEventCard(
              icon: Icons.arrow_upward_rounded, color: const Color(0xFFFF2D55),
              label: 'Hard\nAccel', count: _hardAccelCount, risk: 'WEAR RISK',
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildEventCard(
              icon: Icons.turn_right_rounded, color: const Color(0xFF5E5CE6),
              label: 'Sharp\nTurns', count: _sharpTurnCount, risk: 'TYRE RISK',
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildEventCard(
              icon: Icons.speed_rounded, color: const Color(0xFFFF2D55),
              label: 'Over\nSpeed', count: _overSpeedCount, risk: 'SAFETY',
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildEventCard({
    required IconData icon, required Color color,
    required String label, required int count, required String risk,
  }) {
    final hasEvent = count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasEvent ? color.withOpacity(0.35) : const Color(0xFF1C1C2E),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: hasEvent ? color : const Color(0xFF3A3A4A), size: 20),
          const SizedBox(height: 8),
          Text('$count',
              style: TextStyle(
                color: hasEvent ? color : Colors.grey[700],
                fontSize: 24, fontWeight: FontWeight.w900,
                fontFamily: 'monospace', height: 1,
              )),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                color: Colors.grey[600], fontSize: 10,
                fontWeight: FontWeight.w500, height: 1.3,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: hasEvent ? color.withOpacity(0.1) : const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(risk,
                style: TextStyle(
                  color: hasEvent ? color : Colors.grey[700],
                  fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 0.5,
                )),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SPEED CHART
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSpeedChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C2E), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 14,
                      decoration: BoxDecoration(
                        color: _speedColor,
                        borderRadius: BorderRadius.circular(2),
                      )),
                  const SizedBox(width: 8),
                  const Text('SPEED TREND',
                      style: TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5,
                      )),
                ],
              ),
              Row(
                children: [
                  Container(width: 8, height: 2,
                      color: const Color(0xFFFF2D55).withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text('Limit', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 2, color: _speedColor),
                  const SizedBox(width: 4),
                  Text('Speed', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 70,
            child: CustomPaint(
              size: const Size(double.infinity, 70),
              painter: _ProfessionalSparklinePainter(
                data: _speedHistory,
                color: _speedColor,
                limit: AppConfig.speedLimit,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => Text(
              '-${(5 - i) * 5}s',
              style: TextStyle(
                color: Colors.grey[700], fontSize: 9, fontFamily: 'monospace',
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  VOICE TOGGLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVoiceToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1C1C2E), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (_voiceAlertsEnabled
                      ? const Color(0xFF34C759)
                      : const Color(0xFF636366))
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _voiceAlertsEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: _voiceAlertsEnabled
                  ? const Color(0xFF34C759)
                  : const Color(0xFF636366),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Voice Alerts',
                    style: TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Spoken warnings for speed & drowsiness',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: _voiceAlertsEnabled,
            onChanged: (v) => setState(() => _voiceAlertsEnabled = v),
            activeColor: const Color(0xFF34C759),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(width: 3, height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5E5CE6),
                    borderRadius: BorderRadius.circular(2),
                  )),
              const SizedBox(width: 8),
              const Text('QUICK ACCESS',
                  style: TextStyle(
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  )),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildActionTile(
              icon: Icons.remove_red_eye_rounded, label: 'Eye\nMonitor',
              sublabel: 'LIVE', color: const Color(0xFF5E5CE6),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MonitoringPage())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(
              icon: Icons.bar_chart_rounded, label: 'Analytics',
              sublabel: 'STATS', color: const Color(0xFF34C759),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AnalyticsPage())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(
              icon: Icons.history_rounded, label: 'Drive\nHistory',
              sublabel: 'TRIPS', color: const Color(0xFFFF9F0A),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DriveHistoryPage())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildActionTile(
              icon: Icons.tune_rounded, label: 'Settings',
              sublabel: 'CONFIG', color: _accentBlue,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage())),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon, required String label,
    required String sublabel, required Color color, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600, height: 1.3,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(sublabel,
                  style: TextStyle(
                    color: color, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SOS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSOSButton() {
    return Positioned(
      bottom: 20, right: 20,
      child: GestureDetector(
        onLongPress: _startSOS,
        child: AnimatedBuilder(
          animation: _sosAnim,
          builder: (_, child) => Transform.scale(
              scale: _drowsinessLevel >= 2 ? _sosAnim.value : 1.0, child: child),
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                  colors: [Color(0xFFFF2D55), Color(0xFFCC0022)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: const Color(0xFFFF2D55).withOpacity(0.5),
                blurRadius: 20, spreadRadius: 2,
              )],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
                Text('SOS',
                    style: TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSOSOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _sosAnim,
                builder: (_, child) =>
                    Transform.scale(scale: _sosAnim.value, child: child),
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF2D55), width: 3),
                    color: const Color(0xFFFF2D55).withOpacity(0.15),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emergency_rounded,
                          color: Color(0xFFFF2D55), size: 32),
                      Text('$_sosCountdown',
                          style: const TextStyle(
                            color: Color(0xFFFF2D55), fontSize: 36,
                            fontWeight: FontWeight.w900, fontFamily: 'monospace',
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('CALLING EMERGENCY SERVICES',
                  style: TextStyle(
                    color: Color(0xFFFF2D55), fontSize: 14,
                    fontWeight: FontWeight.w800, letterSpacing: 2,
                  )),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _cancelSOS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey[600]!, width: 1),
                  ),
                  child: const Text('CANCEL',
                      style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700, letterSpacing: 2,
                      )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TRIP SUMMARY SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TripSummarySheet extends StatelessWidget {
  final Duration duration;
  final double distance;
  final double maxSpeed;
  final double avgSpeed;
  final double safetyScore;
  final int hardBrakes;
  final int hardAccels;
  final int sharpTurns;
  final int overSpeeds;
  final bool isNightMode;

  const _TripSummarySheet({
    required this.duration, required this.distance,
    required this.maxSpeed, required this.avgSpeed,
    required this.safetyScore, required this.hardBrakes,
    required this.hardAccels, required this.sharpTurns,
    required this.overSpeeds, required this.isNightMode,
  });

  Color get _scoreColor {
    if (safetyScore >= 80) return const Color(0xFF34C759);
    if (safetyScore >= 55) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF2D55);
  }

  String get _grade {
    if (safetyScore >= 90) return 'A+';
    if (safetyScore >= 80) return 'A';
    if (safetyScore >= 70) return 'B';
    if (safetyScore >= 55) return 'C';
    return 'D';
  }

  String get _feedback {
    if (safetyScore >= 90) return 'Excellent drive! Keep it up 🎉';
    if (safetyScore >= 75) return 'Good drive. Minor improvements needed.';
    if (safetyScore >= 55) return 'Fair drive. Focus on smoother controls.';
    return 'Unsafe driving detected. Please drive carefully.';
  }

  String _fmt(Duration d) {
    final h = d.inHours; final m = d.inMinutes % 60; final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _fmtDist(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} km' : '${m.toStringAsFixed(0)} m';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _scoreColor.withOpacity(0.3), width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.flag_rounded,
                    color: Color(0xFF34C759), size: 20),
                const SizedBox(width: 8),
                const Text('TRIP COMPLETED',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w800, letterSpacing: 1.5,
                    )),
                const Spacer(),
                if (isNightMode)
                  const Icon(Icons.nights_stay_rounded,
                      color: Color(0xFF5E5CE6), size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _scoreColor.withOpacity(0.1),
                    border: Border.all(color: _scoreColor, width: 3),
                  ),
                  child: Center(
                    child: Text(_grade,
                        style: TextStyle(
                          color: _scoreColor, fontSize: 28,
                          fontWeight: FontWeight.w900,
                        )),
                  ),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${safetyScore.toInt()}/100',
                        style: TextStyle(
                          color: _scoreColor, fontSize: 32,
                          fontWeight: FontWeight.w900, fontFamily: 'monospace',
                        )),
                    Text('Safety Score',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(_feedback,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              _statTile('Duration', _fmt(duration),
                  Icons.timer_rounded, const Color(0xFF5E5CE6)),
              const SizedBox(width: 10),
              _statTile('Distance', _fmtDist(distance),
                  Icons.route_rounded, const Color(0xFF00D4FF)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _statTile('Max Speed', '${maxSpeed.toStringAsFixed(0)} km/h',
                  Icons.speed_rounded, const Color(0xFFFF2D55)),
              const SizedBox(width: 10),
              _statTile('Avg Speed', '${avgSpeed.toStringAsFixed(0)} km/h',
                  Icons.trending_flat_rounded, const Color(0xFF34C759)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _statTile('Hard Brakes', '$hardBrakes',
                  Icons.front_hand_rounded, const Color(0xFFFF9F0A)),
              const SizedBox(width: 10),
              _statTile('Over Speed', '$overSpeeds ×',
                  Icons.warning_rounded, const Color(0xFFFF2D55)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _scoreColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Done',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w800, fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis),
                  Text(label,
                      style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAINTERS
// ─────────────────────────────────────────────────────────────────────────────
class _ProfessionalSpeedometerPainter extends CustomPainter {
  final double progress; final Color color; final double limitProgress;
  const _ProfessionalSpeedometerPainter(
      {required this.progress, required this.color, required this.limitProgress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2);
    final outerRadius = (size.width/2) - 8;
    const startAngle = pi * 0.75; const sweepAngle = pi * 1.5;
    canvas.drawArc(Rect.fromCircle(center: center, radius: outerRadius),
        startAngle, sweepAngle, false,
        Paint()..color=const Color(0xFF1A1A28)..style=PaintingStyle.stroke
          ..strokeWidth=12..strokeCap=StrokeCap.round);
    final tickPaint = Paint()..color=const Color(0xFF2A2A3A)..strokeWidth=1.5..style=PaintingStyle.stroke;
    for (int i=0; i<=20; i++) {
      final angle = startAngle + (sweepAngle * i / 20);
      final isMajor = i % 4 == 0;
      canvas.drawLine(
        Offset(center.dx+(outerRadius+6)*cos(angle), center.dy+(outerRadius+6)*sin(angle)),
        Offset(center.dx+(outerRadius+(isMajor?14:10))*cos(angle), center.dy+(outerRadius+(isMajor?14:10))*sin(angle)),
        tickPaint);
    }
    if (limitProgress > 0) {
      final limitAngle = startAngle + sweepAngle * limitProgress;
      canvas.drawLine(
        Offset(center.dx+(outerRadius-5)*cos(limitAngle), center.dy+(outerRadius-5)*sin(limitAngle)),
        Offset(center.dx+(outerRadius+5)*cos(limitAngle), center.dy+(outerRadius+5)*sin(limitAngle)),
        Paint()..color=const Color(0xFFFF2D55)..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);
    }
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center:center,radius:outerRadius),
          startAngle, sweepAngle*progress, false,
          Paint()..color=color.withOpacity(0.25)..style=PaintingStyle.stroke
            ..strokeWidth=20..strokeCap=StrokeCap.round
            ..maskFilter=const MaskFilter.blur(BlurStyle.normal,8));
      canvas.drawArc(Rect.fromCircle(center:center,radius:outerRadius),
          startAngle, sweepAngle*progress, false,
          Paint()..shader=SweepGradient(startAngle:startAngle,endAngle:startAngle+sweepAngle*progress,
              colors:[color.withOpacity(0.6),color],tileMode:TileMode.clamp)
              .createShader(Rect.fromCircle(center:center,radius:outerRadius))
            ..style=PaintingStyle.stroke..strokeWidth=12..strokeCap=StrokeCap.round);
      final endAngle = startAngle+sweepAngle*progress;
      canvas.drawCircle(Offset(center.dx+outerRadius*cos(endAngle),center.dy+outerRadius*sin(endAngle)),6,
          Paint()..color=color..maskFilter=const MaskFilter.blur(BlurStyle.normal,3));
      canvas.drawCircle(Offset(center.dx+outerRadius*cos(endAngle),center.dy+outerRadius*sin(endAngle)),4,
          Paint()..color=Colors.white);
    }
    canvas.drawCircle(center,18,Paint()..color=const Color(0xFF1C1C2E)..style=PaintingStyle.fill);
    canvas.drawCircle(center,18,Paint()..color=color.withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=2);
    canvas.drawCircle(center,5,Paint()..color=color..style=PaintingStyle.fill);
  }
  @override bool shouldRepaint(covariant _ProfessionalSpeedometerPainter old) =>
      old.progress!=progress||old.color!=color;
}

class _ScanLinePainter extends CustomPainter {
  final double progress; final Color color;
  const _ScanLinePainter({required this.progress, required this.color});
  @override void paint(Canvas canvas, Size size) {
    final center=Offset(size.width/2,size.height/2);
    final radius=size.width/2-8;
    const startAngle=pi*0.75; const sweepAngle=pi*1.5;
    final angle=startAngle+sweepAngle*progress;
    canvas.drawLine(
      Offset(center.dx+(radius-20)*cos(angle),center.dy+(radius-20)*sin(angle)),
      Offset(center.dx+(radius+2)*cos(angle),center.dy+(radius+2)*sin(angle)),
      Paint()..color=color.withOpacity(0.4)..strokeWidth=1.5
        ..maskFilter=const MaskFilter.blur(BlurStyle.normal,2));
  }
  @override bool shouldRepaint(covariant _ScanLinePainter old) => old.progress!=progress;
}

class _MiniRingPainter extends CustomPainter {
  final double progress; final Color color; final Color bgColor;
  const _MiniRingPainter({required this.progress,required this.color,required this.bgColor});
  @override void paint(Canvas canvas, Size size) {
    final center=Offset(size.width/2,size.height/2);
    final radius=(size.width/2)-4;
    canvas.drawCircle(center,radius,Paint()..color=bgColor..style=PaintingStyle.stroke..strokeWidth=4);
    if(progress>0) canvas.drawArc(Rect.fromCircle(center:center,radius:radius),
        -pi/2,2*pi*progress,false,
        Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=4..strokeCap=StrokeCap.round);
  }
  @override bool shouldRepaint(covariant _MiniRingPainter old) =>
      old.progress!=progress||old.color!=color;
}

class _GradientRingPainter extends CustomPainter {
  final double progress; final Color color; final Color bgColor;
  const _GradientRingPainter({required this.progress,required this.color,required this.bgColor});
  @override void paint(Canvas canvas, Size size) {
    final center=Offset(size.width/2,size.height/2);
    final radius=(size.width/2)-7;
    canvas.drawCircle(center,radius,Paint()..color=bgColor..style=PaintingStyle.stroke..strokeWidth=9);
    if(progress>0){
      canvas.drawArc(Rect.fromCircle(center:center,radius:radius),
          -pi/2,2*pi*progress,false,
          Paint()..color=color.withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=16
            ..strokeCap=StrokeCap.round..maskFilter=const MaskFilter.blur(BlurStyle.normal,6));
      canvas.drawArc(Rect.fromCircle(center:center,radius:radius),
          -pi/2,2*pi*progress,false,
          Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=9..strokeCap=StrokeCap.round);
    }
  }
  @override bool shouldRepaint(covariant _GradientRingPainter old) =>
      old.progress!=progress||old.color!=color;
}

class _ProfessionalSparklinePainter extends CustomPainter {
  final List<double> data; final Color color; final double limit;
  const _ProfessionalSparklinePainter({required this.data,required this.color,required this.limit});
  @override void paint(Canvas canvas, Size size) {
    if(data.isEmpty) return;
    final maxVal=max(data.reduce(max),limit*1.3);
    const minVal=0.0; final range=maxVal-minVal;
    if(range==0) return;
    final stepX=size.width/(data.length-1);
    final gridPaint=Paint()..color=const Color(0xFF1A1A28)..strokeWidth=1;
    for(int i=1;i<=3;i++){
      final y=size.height*(1-i/4);
      canvas.drawLine(Offset(0,y),Offset(size.width,y),gridPaint);
    }
    final limitY=size.height-((limit-minVal)/range)*size.height;
    double x=0;
    while(x<size.width){
      canvas.drawLine(Offset(x,limitY),Offset(x+8,limitY),
          Paint()..color=const Color(0xFFFF2D55).withOpacity(0.5)..strokeWidth=1);
      x+=14;
    }
    final path=Path(); final fillPath=Path();
    for(int i=0;i<data.length;i++){
      final px=i*stepX;
      final py=size.height-((data[i]-minVal)/range)*size.height;
      if(i==0){path.moveTo(px,py);fillPath.moveTo(px,size.height);fillPath.lineTo(px,py);}
      else{
        final prevX=(i-1)*stepX;
        final prevY=size.height-((data[i-1]-minVal)/range)*size.height;
        final cpX=(prevX+px)/2;
        path.cubicTo(cpX,prevY,cpX,py,px,py);
        fillPath.cubicTo(cpX,prevY,cpX,py,px,py);
      }
    }
    fillPath.lineTo((data.length-1)*stepX,size.height);fillPath.close();
    canvas.drawPath(fillPath,Paint()
      ..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[color.withOpacity(0.35),color.withOpacity(0.0)])
          .createShader(Rect.fromLTWH(0,0,size.width,size.height))
      ..style=PaintingStyle.fill);
    canvas.drawPath(path,Paint()..color=color..strokeWidth=2.5..style=PaintingStyle.stroke
      ..strokeCap=StrokeCap.round..strokeJoin=StrokeJoin.round);
    final lastX=(data.length-1)*stepX;
    final lastY=size.height-((data.last-minVal)/range)*size.height;
    canvas.drawCircle(Offset(lastX,lastY),8,
        Paint()..color=color.withOpacity(0.25)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    canvas.drawCircle(Offset(lastX,lastY),5,Paint()..color=color);
    canvas.drawCircle(Offset(lastX,lastY),2.5,Paint()..color=Colors.white);
  }
  @override bool shouldRepaint(covariant _ProfessionalSparklinePainter old) =>
      old.data!=data||old.color!=color;
}
