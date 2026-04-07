import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification_model.dart';

final ValueNotifier<List<AppNotificationModel>> notificationsNotifier =
    ValueNotifier<List<AppNotificationModel>>([]);

const String _notificationStorageKey = 'saved_notifications';

Future<void> initializeNotifications() async {
  final prefs = await SharedPreferences.getInstance();
  final storedNotifications = prefs.getString(_notificationStorageKey);

  if (storedNotifications == null || storedNotifications.isEmpty) {
    notificationsNotifier.value = [];
    return;
  }

  final List<dynamic> decoded = jsonDecode(storedNotifications);
  notificationsNotifier.value = decoded
      .map(
        (item) =>
            AppNotificationModel.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList();
}

Future<void> addAppNotification(AppNotificationModel notification) async {
  final updatedNotifications = [notification, ...notificationsNotifier.value];
  notificationsNotifier.value = updatedNotifications;
  await _saveNotifications(updatedNotifications);
}

Future<void> markAllNotificationsAsRead() async {
  final updatedNotifications = notificationsNotifier.value
      .map((item) => item.copyWith(isRead: true))
      .toList();

  notificationsNotifier.value = updatedNotifications;
  await _saveNotifications(updatedNotifications);
}

Future<void> clearAllNotifications() async {
  notificationsNotifier.value = [];
  await _saveNotifications([]);
}

Future<void> _saveNotifications(
  List<AppNotificationModel> notifications,
) async {
  final prefs = await SharedPreferences.getInstance();
  final encoded = jsonEncode(
    notifications.map((item) => item.toJson()).toList(),
  );
  await prefs.setString(_notificationStorageKey, encoded);
}
