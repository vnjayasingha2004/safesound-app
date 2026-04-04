import 'package:flutter/material.dart';
import '../data/notification_store.dart';
import '../models/app_notification_model.dart';
import '../services/local_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'reminder':
        return Icons.notifications_active_outlined;
      case 'tip':
        return Icons.lightbulb_outline;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'warning':
        return Colors.red;
      case 'reminder':
        return Colors.blue;
      case 'tip':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Noise alerts and reminders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(AppNotificationModel item) {
    final color = _colorForType(item.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(_iconForType(item.type), color: color),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.message),
              const SizedBox(height: 6),
              Text(
                item.time,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        trailing: item.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await markAllNotificationsAsRead();
            },
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark all as read',
          ),
          IconButton(
            onPressed: () async {
              await LocalNotificationService.showNoiseAlert(
                title: 'Test Notification',
                body: 'This is a manual notification test.',
              );
            },
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test notification',
          ),
          IconButton(
            onPressed: () async {
              await clearAllNotifications();
            },
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<AppNotificationModel>>(
          valueListenable: notificationsNotifier,
          builder: (context, notifications, _) {
            if (notifications.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return _buildNotificationTile(item);
              },
            );
          },
        ),
      ),
    );
  }
}
