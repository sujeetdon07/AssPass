import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/messaging/data/datasources/messaging_socket_service.dart';
import 'package:aaspaas/features/notifications/application/notifications_controller.dart';
import 'package:aaspaas/features/notifications/application/unread_notifications_counter.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_item.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_preferences.dart';
import 'package:aaspaas/features/notifications/domain/repositories/notification_repository.dart';

class _FakeNotificationRepository implements NotificationRepository {
  List<NotificationItem> itemsToReturn = [];
  bool hasMoreToReturn = false;
  String? nextCursorToReturn;
  int unreadCountToReturn = 0;
  bool shouldThrow = false;

  int markAsReadCalls = 0;
  int markAllAsReadCalls = 0;
  int deleteCalls = 0;

  @override
  Future<PaginatedNotificationsResult> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
    String? category,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return PaginatedNotificationsResult(
      items: itemsToReturn,
      nextCursor: nextCursorToReturn,
      hasMore: hasMoreToReturn,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    if (shouldThrow) throw Exception('Network error');
    return unreadCountToReturn;
  }

  @override
  Future<NotificationItem> markAsRead(String notificationId) async {
    markAsReadCalls++;
    if (shouldThrow) throw Exception('Network error');
    final item = itemsToReturn.firstWhere((n) => n.id == notificationId);
    return item.copyWith(isRead: true);
  }

  @override
  Future<int> markAllAsRead() async {
    markAllAsReadCalls++;
    if (shouldThrow) throw Exception('Network error');
    return itemsToReturn.where((n) => !n.isRead).length;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    deleteCalls++;
    if (shouldThrow) throw Exception('Network error');
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) async {}

  @override
  Future<void> unregisterDeviceToken(String token) async {}

  @override
  Future<NotificationPreferences> getPreferences() async {
    return const NotificationPreferences(userId: 'u1');
  }

  @override
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> updates,
  ) async {
    return const NotificationPreferences(userId: 'u1');
  }
}

class _FakeMessagingSocketService extends Fake
    implements MessagingSocketService {
  final _newNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onNewNotification =>
      _newNotificationController.stream;

  final _notificationReadController =
      StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onNotificationRead =>
      _notificationReadController.stream;

  final _notificationUnreadCountController =
      StreamController<Map<String, dynamic>>.broadcast();
  @override
  Stream<Map<String, dynamic>> get onNotificationUnreadCount =>
      _notificationUnreadCountController.stream;

  void emitNew(Map<String, dynamic> data) =>
      _newNotificationController.add(data);
  void emitRead(Map<String, dynamic> data) =>
      _notificationReadController.add(data);
  void emitUnreadCount(int count) =>
      _notificationUnreadCountController.add({'count': count});

  void closeStreams() {
    _newNotificationController.close();
    _notificationReadController.close();
    _notificationUnreadCountController.close();
  }
}

void main() {
  late _FakeNotificationRepository repo;
  late _FakeMessagingSocketService socket;
  late UnreadNotificationsCounter counter;
  late NotificationsController controller;

  setUp(() {
    repo = _FakeNotificationRepository();
    socket = _FakeMessagingSocketService();
    counter = UnreadNotificationsCounter(repo, socket);
  });

  tearDown(() {
    socket.closeStreams();
  });

  NotificationItem makeItem({
    required String id,
    bool isRead = false,
    NotificationCategory category = NotificationCategory.social,
  }) {
    return NotificationItem(
      id: id,
      recipientId: 'u1',
      type: NotificationType.postLiked,
      category: category,
      title: 'Post Liked',
      body: 'Someone liked your post',
      isRead: isRead,
      createdAt: DateTime.now(),
    );
  }

  test('loadInitialNotifications populates state with items', () async {
    repo.itemsToReturn = [
      makeItem(id: 'n1', isRead: false),
      makeItem(id: 'n2', isRead: true),
    ];
    repo.hasMoreToReturn = false;

    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.items.length, 2);
    expect(controller.state.items[0].id, 'n1');
    expect(controller.state.hasMore, false);
    expect(controller.state.isLoading, false);
  });

  test('setFilter resets items and reloads with selected filter', () async {
    repo.itemsToReturn = [makeItem(id: 'n1')];
    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    controller.setFilter(NotificationFilter.unread);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.selectedFilter, NotificationFilter.unread);
  });

  test('markAsRead optimistically updates notification state and counter',
      () async {
    final item = makeItem(id: 'n1', isRead: false);
    repo.itemsToReturn = [item];
    counter.setCount(1);

    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    await controller.markAsRead('n1');

    expect(controller.state.items.first.isRead, true);
    expect(repo.markAsReadCalls, 1);
    expect(counter.state, 0);
  });

  test('markAllAsRead marks all items read and clears unread counter',
      () async {
    repo.itemsToReturn = [
      makeItem(id: 'n1', isRead: false),
      makeItem(id: 'n2', isRead: false),
    ];
    counter.setCount(2);

    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    await controller.markAllAsRead();

    expect(controller.state.items.every((n) => n.isRead), true);
    expect(repo.markAllAsReadCalls, 1);
    expect(counter.state, 0);
  });

  test('deleteNotification optimistically removes item and decrements counter',
      () async {
    repo.itemsToReturn = [
      makeItem(id: 'n1', isRead: false),
      makeItem(id: 'n2', isRead: true),
    ];
    counter.setCount(1);

    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    await controller.deleteNotification('n1');

    expect(controller.state.items.length, 1);
    expect(controller.state.items.first.id, 'n2');
    expect(repo.deleteCalls, 1);
    expect(counter.state, 0);
  });

  test('socket onNewNotification prepends notification to list', () async {
    repo.itemsToReturn = [];
    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    socket.emitNew({
      'id': 'notif-live-1',
      'recipientId': 'u1',
      'type': 'MESSAGE_RECEIVED',
      'category': 'MESSAGES',
      'title': 'New chat',
      'body': 'You have a new message',
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.items.length, 1);
    expect(controller.state.items.first.id, 'notif-live-1');
  });

  test('socket onNotificationRead marks matching notification as read',
      () async {
    repo.itemsToReturn = [makeItem(id: 'n-read-1', isRead: false)];
    controller = NotificationsController(repo, socket, counter);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.items.first.isRead, false);

    socket.emitRead({'id': 'n-read-1'});
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.state.items.first.isRead, true);
  });
}
