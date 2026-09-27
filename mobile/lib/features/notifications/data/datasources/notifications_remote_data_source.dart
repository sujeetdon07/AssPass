import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/notification_item.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationsRemoteDataSourceProvider =
    Provider<NotificationsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationsRemoteDataSource(dio);
});

class NotificationsRemoteDataSource {
  NotificationsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PaginatedNotificationsResult> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    if (unreadOnly != null) {
      queryParams['unreadOnly'] = unreadOnly;
    }
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: queryParams,
    );

    final data = response.data ?? {};
    final itemsList = (data['items'] as List<dynamic>?) ?? [];
    final items = itemsList
        .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
        .toList();

    return PaginatedNotificationsResult(
      items: items,
      nextCursor: data['nextCursor'] as String?,
      hasMore: data['hasMore'] as bool? ?? false,
    );
  }

  Future<int> getUnreadCount() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    final data = response.data ?? {};
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<NotificationItem> markAsRead(String notificationId) async {
    final response = await _dio
        .patch<Map<String, dynamic>>('/notifications/$notificationId/read');
    return NotificationItem.fromJson(response.data ?? {});
  }

  Future<int> markAllAsRead() async {
    final response =
        await _dio.post<Map<String, dynamic>>('/notifications/read-all');
    final data = response.data ?? {};
    return (data['updatedCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteNotification(String notificationId) async {
    await _dio.delete<void>('/notifications/$notificationId');
  }

  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) async {
    await _dio.post<void>(
      '/notifications/devices',
      data: {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
  }

  Future<void> unregisterDeviceToken(String token) async {
    await _dio.delete<void>('/notifications/devices/$token');
  }

  Future<NotificationPreferences> getPreferences() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/notifications/preferences');
    return NotificationPreferences.fromJson(
      response.data ?? {},
    );
  }

  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> updates,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/notifications/preferences',
      data: updates,
    );
    return NotificationPreferences.fromJson(
      response.data ?? {},
    );
  }
}
