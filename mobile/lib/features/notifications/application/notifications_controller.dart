import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../messaging/data/datasources/messaging_socket_service.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../domain/models/notification_item.dart';
import '../domain/repositories/notification_repository.dart';
import 'notifications_state.dart';
import 'unread_notifications_counter.dart';

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final socketService = ref.watch(messagingSocketServiceProvider);
  final unreadCounter = ref.watch(unreadNotificationsCountProvider.notifier);
  return NotificationsController(repository, socketService, unreadCounter);
});

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(
    this._repository,
    this._socketService,
    this._unreadCounter,
  ) : super(const NotificationsState()) {
    _initSocketListeners();
    loadInitialNotifications();
  }

  final NotificationRepository _repository;
  final MessagingSocketService _socketService;
  final UnreadNotificationsCounter _unreadCounter;

  StreamSubscription<Map<String, dynamic>>? _newNotificationSub;
  StreamSubscription<Map<String, dynamic>>? _notificationReadSub;

  void _initSocketListeners() {
    _newNotificationSub = _socketService.onNewNotification.listen((data) {
      _handleIncomingNotification(data);
    });

    _notificationReadSub = _socketService.onNotificationRead.listen((data) {
      final id = data['id'] as String?;
      if (id != null) {
        _handleNotificationRead(id);
      }
    });
  }

  void _handleIncomingNotification(Map<String, dynamic> data) {
    try {
      final item = NotificationItem.fromJson(data);
      // Check if matches current filter
      if (_matchesFilter(item, state.selectedFilter)) {
        // Prevent duplicate if already exists
        if (!state.items.any((n) => n.id == item.id)) {
          state = state.copyWith(items: [item, ...state.items]);
        }
      }
    } catch (_) {
      // Ignored for malformed socket messages
    }
  }

  void _handleNotificationRead(String id) {
    final updated = state.items.map((item) {
      if (item.id == id && !item.isRead) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }
      return item;
    }).toList();

    state = state.copyWith(items: updated);
  }

  bool _matchesFilter(NotificationItem item, NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.all:
        return true;
      case NotificationFilter.unread:
        return !item.isRead;
      case NotificationFilter.messages:
        return item.category == NotificationCategory.messages;
      case NotificationFilter.social:
        return item.category == NotificationCategory.social;
      case NotificationFilter.community:
        return item.category == NotificationCategory.community;
      case NotificationFilter.marketplace:
        return item.category == NotificationCategory.marketplace;
      case NotificationFilter.business:
        return item.category == NotificationCategory.business;
      case NotificationFilter.system:
        return item.category == NotificationCategory.system;
    }
  }

  String? _categoryForFilter(NotificationFilter filter) {
    switch (filter) {
      case NotificationFilter.messages:
        return NotificationCategory.messages.value;
      case NotificationFilter.social:
        return NotificationCategory.social.value;
      case NotificationFilter.community:
        return NotificationCategory.community.value;
      case NotificationFilter.marketplace:
        return NotificationCategory.marketplace.value;
      case NotificationFilter.business:
        return NotificationCategory.business.value;
      case NotificationFilter.system:
        return NotificationCategory.system.value;
      case NotificationFilter.all:
      case NotificationFilter.unread:
        return null;
    }
  }

  Future<void> loadInitialNotifications({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNextCursor: refresh,
    );

    try {
      final unreadOnly = state.selectedFilter == NotificationFilter.unread;
      final category = _categoryForFilter(state.selectedFilter);

      final result = await _repository.getNotifications(
        limit: 20,
        unreadOnly: unreadOnly ? true : null,
        category: category,
      );

      state = state.copyWith(
        items: result.items,
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMoreNotifications() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final unreadOnly = state.selectedFilter == NotificationFilter.unread;
      final category = _categoryForFilter(state.selectedFilter);

      final result = await _repository.getNotifications(
        limit: 20,
        cursor: state.nextCursor,
        unreadOnly: unreadOnly ? true : null,
        category: category,
      );

      state = state.copyWith(
        items: [...state.items, ...result.items],
        nextCursor: result.nextCursor,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setFilter(NotificationFilter filter) {
    if (state.selectedFilter == filter) return;
    state = state.copyWith(
      selectedFilter: filter,
      items: [],
      hasMore: false,
      clearNextCursor: true,
    );
    loadInitialNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    final itemIndex = state.items.indexWhere((n) => n.id == notificationId);
    if (itemIndex == -1) return;

    final item = state.items[itemIndex];
    if (item.isRead) return;

    // Optimistic update
    final updatedList = List<NotificationItem>.from(state.items);
    updatedList[itemIndex] =
        item.copyWith(isRead: true, readAt: DateTime.now());
    state = state.copyWith(items: updatedList);
    _unreadCounter.decrement();

    try {
      await _repository.markAsRead(notificationId);
    } catch (_) {
      // Revert if failed
      updatedList[itemIndex] = item;
      state = state.copyWith(items: updatedList);
      _unreadCounter.increment();
    }
  }

  Future<void> markAllAsRead() async {
    final unreadItems = state.items.where((n) => !n.isRead).toList();
    if (unreadItems.isEmpty) return;

    // Optimistic update
    final updatedList = state.items.map((n) {
      return n.isRead ? n : n.copyWith(isRead: true, readAt: DateTime.now());
    }).toList();

    state = state.copyWith(items: updatedList);
    _unreadCounter.clear();

    try {
      await _repository.markAllAsRead();
    } catch (_) {
      // Revert if failed
      state = state.copyWith(items: state.items);
      _unreadCounter.loadCount();
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final itemIndex = state.items.indexWhere((n) => n.id == notificationId);
    if (itemIndex == -1) return;

    final item = state.items[itemIndex];
    final wasUnread = !item.isRead;

    // Optimistic removal
    final updatedList = List<NotificationItem>.from(state.items)
      ..removeAt(itemIndex);
    state = state.copyWith(items: updatedList);
    if (wasUnread) {
      _unreadCounter.decrement();
    }

    try {
      await _repository.deleteNotification(notificationId);
    } catch (_) {
      // Revert on failure
      final reverted = List<NotificationItem>.from(state.items)
        ..insert(itemIndex, item);
      state = state.copyWith(items: reverted);
      if (wasUnread) {
        _unreadCounter.increment();
      }
    }
  }

  @override
  void dispose() {
    _newNotificationSub?.cancel();
    _notificationReadSub?.cancel();
    super.dispose();
  }
}
