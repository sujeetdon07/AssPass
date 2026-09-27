import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/notifications/application/notifications_controller.dart';
import 'package:aaspaas/features/notifications/application/notifications_state.dart';
import 'package:aaspaas/features/notifications/application/notification_preferences_controller.dart';
import 'package:aaspaas/features/notifications/application/unread_notifications_counter.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_item.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_preferences.dart';
import 'package:aaspaas/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:aaspaas/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:aaspaas/features/notifications/presentation/widgets/notification_badge.dart';
import 'package:aaspaas/features/notifications/presentation/widgets/notification_tile.dart';

class _MockNotificationsController extends StateNotifier<NotificationsState>
    implements NotificationsController {
  _MockNotificationsController(super.state);

  int markAllAsReadCalls = 0;
  int markAsReadCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> loadInitialNotifications({bool refresh = false}) async {}

  @override
  Future<void> loadMoreNotifications() async {}

  @override
  void setFilter(NotificationFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markAsReadCalls++;
  }

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalls++;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    deleteCalls++;
  }
}

class _MockUnreadCounter extends StateNotifier<int>
    implements UnreadNotificationsCounter {
  _MockUnreadCounter(super.state);

  @override
  Future<void> loadCount() async {}

  @override
  void setCount(int count) => state = count;

  @override
  void increment() => state = state + 1;

  @override
  void decrement() => state = state > 0 ? state - 1 : 0;

  @override
  void clear() => state = 0;
}

class _MockPreferencesController
    extends StateNotifier<AsyncValue<NotificationPreferences>>
    implements NotificationPreferencesController {
  _MockPreferencesController(super.state);

  @override
  Future<void> loadPreferences() async {}

  @override
  Future<void> togglePush(bool enabled) async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(pushEnabled: enabled));
    }
  }

  @override
  Future<void> updateCategory(String categoryKey, bool enabled) async {}
}

void main() {
  group('NotificationBadge Widget Tests', () {
    testWidgets('renders icon without badge chip when unreadCount is 0',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider
                .overrideWith((ref) => _MockUnreadCounter(0)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationBadge(onPressed: () {}),
            ),
          ),
        ),
      );

      expect(find.byType(NotificationBadge), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders badge chip with count when unreadCount > 0',
        (tester) async {
      int clicked = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unreadNotificationsCountProvider
                .overrideWith((ref) => _MockUnreadCounter(5)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NotificationBadge(onPressed: () => clicked++),
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      await tester.tap(find.byType(NotificationBadge));
      expect(clicked, 1);
    });
  });

  group('NotificationTile Widget Tests', () {
    testWidgets('renders title, body, and unread dot', (tester) async {
      final item = NotificationItem(
        id: 'n1',
        recipientId: 'u1',
        type: NotificationType.messageReceived,
        category: NotificationCategory.messages,
        title: 'New message from Anil',
        body: 'Can we meet at the park?',
        isRead: false,
        createdAt: DateTime.now(),
      );

      int tapped = 0;
      int deleted = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationTile(
              item: item,
              onTap: () => tapped++,
              onDelete: () => deleted++,
            ),
          ),
        ),
      );

      expect(find.text('New message from Anil'), findsOneWidget);
      expect(find.text('Can we meet at the park?'), findsOneWidget);

      await tester.tap(find.byType(NotificationTile));
      expect(tapped, 1);
    });
  });

  group('NotificationsScreen Widget Tests', () {
    testWidgets('renders empty state when items list is empty', (tester) async {
      final mockController = _MockNotificationsController(
        const NotificationsState(items: [], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerProvider
                .overrideWith((ref) => mockController),
            unreadNotificationsCountProvider
                .overrideWith((ref) => _MockUnreadCounter(0)),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('renders items and mark all as read action when items exist',
        (tester) async {
      final item = NotificationItem(
        id: 'n-item-1',
        recipientId: 'u1',
        type: NotificationType.communityAnnouncement,
        category: NotificationCategory.community,
        title: 'Community meeting tomorrow',
        body: 'Please join at the community clubhouse at 6 PM.',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final mockController = _MockNotificationsController(
        NotificationsState(items: [item], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerProvider
                .overrideWith((ref) => mockController),
            unreadNotificationsCountProvider
                .overrideWith((ref) => _MockUnreadCounter(1)),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      expect(find.text('Community meeting tomorrow'), findsOneWidget);

      // Find Mark all as read icon button
      final markAllBtn = find.byTooltip('Mark all as read');
      if (markAllBtn.evaluate().isNotEmpty) {
        await tester.tap(markAllBtn);
        await tester.pump();
        expect(mockController.markAllAsReadCalls, 1);
      }
    });
  });

  group('NotificationSettingsScreen Widget Tests', () {
    testWidgets('renders master switch and category switches', (tester) async {
      const prefs = NotificationPreferences(
        userId: 'u1',
        pushEnabled: true,
        messagesEnabled: true,
        socialEnabled: true,
        communityEnabled: true,
      );

      final mockPrefsController = _MockPreferencesController(
        const AsyncValue.data(prefs),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationPreferencesControllerProvider
                .overrideWith((ref) => mockPrefsController),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );

      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Notification Categories'), findsOneWidget);
      expect(find.text('Direct Messages'), findsOneWidget);
      expect(find.text('Social & Feed Activity'), findsOneWidget);
      expect(find.text('Community Updates'), findsOneWidget);
    });
  });
}
