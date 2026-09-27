import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final remoteDataSource = ref.watch(notificationsRemoteDataSourceProvider);
  return NotificationRepositoryImpl(remoteDataSource);
});

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remoteDataSource);

  final NotificationsRemoteDataSource _remoteDataSource;

  @override
  Future<PaginatedNotificationsResult> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
    String? category,
  }) {
    return _remoteDataSource.getNotifications(
      limit: limit,
      cursor: cursor,
      unreadOnly: unreadOnly,
      category: category,
    );
  }

  @override
  Future<int> getUnreadCount() {
    return _remoteDataSource.getUnreadCount();
  }

  @override
  Future<NotificationItem> markAsRead(String notificationId) {
    return _remoteDataSource.markAsRead(notificationId);
  }

  @override
  Future<int> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }

  @override
  Future<void> deleteNotification(String notificationId) {
    return _remoteDataSource.deleteNotification(notificationId);
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) {
    return _remoteDataSource.registerDeviceToken(
      token: token,
      platform: platform,
      deviceId: deviceId,
    );
  }

  @override
  Future<void> unregisterDeviceToken(String token) {
    return _remoteDataSource.unregisterDeviceToken(token);
  }

  @override
  Future<NotificationPreferences> getPreferences() {
    return _remoteDataSource.getPreferences();
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> updates,
  ) {
    return _remoteDataSource.updatePreferences(updates);
  }
}
