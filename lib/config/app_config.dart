import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../models/settings.dart';
import '../models/driver_profile.dart';
import '../services/learning_service.dart';

class AppConfig {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Database ──────────────────────────────
  static const String dbName = 'safe_drive_monitor.db';
  static const String recordsTable = 'driving_records';
  static const String drivesTable = 'drives';
  static const int batchSize = 10;
  static int retentionDays = 90;

  // ── Sampling Rate ─────────────────────────
  static double minRecordingSpeed = 10.0;
  static const Map<int, Duration> speedSamplingRates = {
    10: Duration(seconds: 5), // 10–30 km/h: every 5s
    30: Duration(seconds: 2), // 30–60 km/h: every 2s
    60: Duration(seconds: 1), // >60 km/h:   every 1s
  };

  // ── Drive Detection ───────────────────────
  static double driveStartSpeed = 10.0; // km/h
  static const int driveStartDuration = 60; // seconds
  static const double driveEndSpeed = 10.0; // km/h
  static const int driveEndDuration = 1800; // seconds

  // ── Speed Monitoring ──────────────────────
  static double speedThreshold = 110.0; // km/h

  /// Alias used by DashboardPage — always mirrors speedThreshold
  static double get speedLimit => speedThreshold;

  static double speedWarningThreshold = 110.0; // km/h

  // ── Acceleration Monitoring ───────────────
  static double suddenAccelerationThreshold = 3.0; // m/s²
  static double suddenBrakingThreshold = -3.0; // m/s²
  static double sharpTurnThreshold = 3.0; // m/s²
  static const int suddenEventGroupInterval = 10; // seconds

  // ── UI ────────────────────────────────────
  static const int warningDisplaySeconds = 5;

  // ── Adaptive Learning ─────────────────────
  static bool adaptiveLearningEnabled = false;
  static DriverProfile driverProfile = DriverProfile.defaultProfile();

  /// Effective speed threshold — raised slightly for experienced drivers
  static double get effectiveSpeedThreshold =>
      adaptiveLearningEnabled && driverProfile.isInitialized
          ? (speedThreshold *
                  (1 + driverProfile.averageOverSpeedRatio * 0.6))
              .clamp(speedThreshold, speedThreshold + 25)
          : speedThreshold;

  /// Effective sudden-acceleration threshold
  static double get effectiveSuddenAccelerationThreshold =>
      adaptiveLearningEnabled && driverProfile.isInitialized
          ? (suddenAccelerationThreshold +
                  (driverProfile.averageEventRate - 0.02) * 1.5)
              .clamp(1.5, 5.0)
          : suddenAccelerationThreshold;

  /// Effective sudden-braking threshold (negative value)
  static double get effectiveSuddenBrakingThreshold =>
      adaptiveLearningEnabled && driverProfile.isInitialized
          ? (suddenBrakingThreshold -
                  (driverProfile.averageEventRate - 0.02) * 1.5)
              .clamp(-5.0, -1.5)
          : suddenBrakingThreshold;

  /// Effective sharp-turn threshold
  static double get effectiveSharpTurnThreshold =>
      adaptiveLearningEnabled && driverProfile.isInitialized
          ? (sharpTurnThreshold +
                  (driverProfile.averageEventRate - 0.02) * 1.5)
              .clamp(1.5, 5.0)
          : sharpTurnThreshold;

  // ── Telegram Notification Intervals ───────
  static const int speedAlertInterval = 1800; // 30 minutes
  static const int suddenEventAlertInterval = 300; // 5 minutes

  // ── Telegram Config ───────────────────────
  static const String telegramBotName = 'safe_drive_monitor_bot';
  static String get telegramBotToken =>
      dotenv.env['TELEGRAM_BOT_TOKEN'] ?? '';
  static String get telegramChatId =>
      _prefs?.getString('telegram_chat_id') ?? '';
  static bool get isTelegramConfigured =>
      telegramBotToken.isNotEmpty && telegramChatId.isNotEmpty;

  // ── Load / Save Settings ──────────────────
  static Future<void> loadSettings() async {
    if (_prefs == null) await init();

    final settingsJson = _prefs?.getString('settings');
    if (settingsJson != null) {
      final settings = Settings.fromJson(jsonDecode(settingsJson));
      retentionDays = settings.retentionDays;
      minRecordingSpeed = settings.minDrivingSpeed;
      speedThreshold = settings.speedLimit;
      suddenAccelerationThreshold = settings.suddenAccThreshold;
      suddenBrakingThreshold = settings.suddenBrakeThreshold;
      sharpTurnThreshold = settings.sharpTurnThreshold;
      adaptiveLearningEnabled = settings.adaptiveLearningEnabled;
      // Keep speedWarningThreshold in sync with speedThreshold
      speedWarningThreshold = speedThreshold;
    }

    if (adaptiveLearningEnabled) {
      driverProfile = await LearningService.loadProfile();
    }
  }

  static Future<void> saveSettings(Settings settings) async {
    if (_prefs == null) await init();
    await _prefs?.setString('settings', jsonEncode(settings.toJson()));
    // Reload so all getters stay consistent
    await loadSettings();
  }
}