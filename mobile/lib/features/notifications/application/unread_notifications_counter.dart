import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../messaging/data/datasources/messaging_socket_service.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../domain/repositories/notification_repository.dart';

final unreadNotificationsCountProvider =
    StateNotifierProvider<UnreadNotificationsCounter, int>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final socketService = ref.watch(messagingSocketServiceProvider);
  return UnreadNotificationsCounter(repository, socketService);
});

class UnreadNotificationsCounter extends StateNotifier<int> {
  UnreadNotificationsCounter(this._repository, this._socketService) : super(0) {
    _init();
  }

  final NotificationRepository _repository;
  final MessagingSocketService _socketService;

  StreamSubscription<Map<String, dynamic>>? _unreadCountSub;
  StreamSubscription<Map<String, dynamic>>? _newNotificationSub;

  void _init() {
    loadCount();

    // Listen to real-time unread count updates from backend
    _unreadCountSub = _socketService.onNotificationUnreadCount.listen((data) {
      final count = (data['count'] as num?)?.toInt();
      if (count != null) {
        state = count;
      }
    });

    // Listen to incoming notifications to increment if unread count wasn't received
    _newNotificationSub = _socketService.onNewNotification.listen((_) {
      state = state + 1;
    });
  }

  Future<void> loadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      state = count;
    } catch (_) {
      // Silently fail in offline/mock mode
    }
  }

  void setCount(int count) {
    state = count < 0 ? 0 : count;
  }

  void increment() {
    state = state + 1;
  }

  void decrement() {
    if (state > 0) {
      state = state - 1;
    }
  }

  void clear() {
    state = 0;
  }

  @override
  void dispose() {
    _unreadCountSub?.cancel();
    _newNotificationSub?.cancel();
    super.dispose();
  }
}
