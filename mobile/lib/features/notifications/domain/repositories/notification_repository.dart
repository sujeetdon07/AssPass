import 'package:flutter/foundation.dart';
import '../models/notification_item.dart';
import '../models/notification_preferences.dart';

@immutable
class PaginatedNotificationsResult {
  const PaginatedNotificationsResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<NotificationItem> items;
  final String? nextCursor;
  final bool hasMore;
}

abstract class NotificationRepository {
  Future<PaginatedNotificationsResult> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
    String? category,
  });

  Future<int> getUnreadCount();

  Future<NotificationItem> markAsRead(String notificationId);

  Future<int> markAllAsRead();

  Future<void> deleteNotification(String notificationId);

  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  });

  Future<void> unregisterDeviceToken(String token);

  Future<NotificationPreferences> getPreferences();

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> updates,
  );
}
