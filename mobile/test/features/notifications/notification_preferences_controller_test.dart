import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/notifications/application/notification_preferences_controller.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_item.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_preferences.dart';
import 'package:aaspaas/features/notifications/domain/repositories/notification_repository.dart';

class _FakeNotificationRepository implements NotificationRepository {
  NotificationPreferences prefs = const NotificationPreferences(
    userId: 'usr-1',
    messagesEnabled: true,
    socialEnabled: true,
    pushEnabled: true,
  );
  bool shouldThrow = false;

  @override
  Future<NotificationPreferences> getPreferences() async {
    if (shouldThrow) throw Exception('Failed to load preferences');
    return prefs;
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> updates,
  ) async {
    if (shouldThrow) throw Exception('Failed to update preferences');
    prefs = NotificationPreferences.fromJson({
      ...prefs.toJson(),
      ...updates,
    });
    return prefs;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {}

  @override
  Future<PaginatedNotificationsResult> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
    String? category,
  }) async {
    return const PaginatedNotificationsResult(items: [], hasMore: false);
  }

  @override
  Future<int> getUnreadCount() async => 0;

  @override
  Future<int> markAllAsRead() async => 0;

  @override
  Future<NotificationItem> markAsRead(String notificationId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) async {}

  @override
  Future<void> unregisterDeviceToken(String token) async {}
}

void main() {
  late _FakeNotificationRepository repo;
  late NotificationPreferencesController controller;

  setUp(() {
    repo = _FakeNotificationRepository();
  });

  test('loadPreferences successfully loads preferences into state', () async {
    controller = NotificationPreferencesController(repo);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.hasValue, true);
    final value = controller.state.value!;
    expect(value.userId, 'usr-1');
    expect(value.pushEnabled, true);
    expect(value.messagesEnabled, true);
  });

  test('togglePush updates pushEnabled state and persists', () async {
    controller = NotificationPreferencesController(repo);
    await Future<void>.delayed(Duration.zero);

    await controller.togglePush(false);

    expect(controller.state.value!.pushEnabled, false);
    expect(repo.prefs.pushEnabled, false);
  });

  test('updateCategory toggles specific category switch', () async {
    controller = NotificationPreferencesController(repo);
    await Future<void>.delayed(Duration.zero);

    await controller.updateCategory('social', false);

    expect(controller.state.value!.socialEnabled, false);
    expect(controller.state.value!.messagesEnabled, true);
  });

  test('updateCategory handles error and reverts state', () async {
    controller = NotificationPreferencesController(repo);
    await Future<void>.delayed(Duration.zero);

    repo.shouldThrow = true;
    await controller.updateCategory('messages', false);

    expect(controller.state is AsyncError, true);
  });
}
