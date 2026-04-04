import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initSettings);
    await requestPermissions();
    await debugNotificationStatus();
  }

  static Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final granted = await android?.requestNotificationsPermission();
    debugPrint('Notification permission request result: $granted');

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> debugNotificationStatus() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final enabled = await android?.areNotificationsEnabled();
    final active = await _plugin.getActiveNotifications();

    debugPrint('Notifications enabled: $enabled');
    debugPrint('Active notifications count: ${active.length}');
  }

  static Future<void> showNoiseAlert({
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'noise_alerts_channel',
        'Noise Alerts',
        channelDescription: 'Warnings for unsafe sound exposure',
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      debugPrint('Trying to show notification id=$id');
      debugPrint('Title: $title');
      debugPrint('Body: $body');

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );

      debugPrint('Notification show() completed');
      await debugNotificationStatus();
    } catch (e, stackTrace) {
      debugPrint('Notification error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
