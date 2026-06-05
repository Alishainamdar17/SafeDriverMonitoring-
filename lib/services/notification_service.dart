import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId   = 'drowsy_driver_alerts';
  static const String _channelName = 'Drowsy Driver Alerts';
  static const String _channelDesc =
      'Critical alerts when drowsiness or distraction is detected';

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS:     iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );

    // Create Android notification channel
    // FIX: removed Color() from const context — use non-const channel
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description:      _channelDesc,
      importance:       Importance.max,
      playSound:        false,
      enableVibration:  true,
      enableLights:     true,
      ledColor:         const Color(0xFFFF0000), // FIX: const here is fine
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: false,
        );

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> showAlertNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    // FIX: non-const AndroidNotificationDetails — Color() cannot be const
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance:         Importance.max,
      priority:           Priority.max,
      fullScreenIntent:   true,
      category:           AndroidNotificationCategory.alarm,
      visibility:         NotificationVisibility.public,
      autoCancel:         true,
      playSound:          false,
      enableVibration:    true,
      color:              const Color(0xFFFF0000),
      ticker:             'Driver alert',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert:      true,
      presentBadge:      true,
      presentSound:      false,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS:     iosDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
      payload: payload,
    );

    debugPrint('Notification shown: $title');
  }
}