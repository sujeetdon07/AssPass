import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_item.dart';
import 'package:aaspaas/features/notifications/domain/models/notification_preferences.dart';
import 'package:aaspaas/features/notifications/l10n/notifications_localizations.dart';

void main() {
  group('Notifications Localization Tests', () {
    test('Returns correct English and Hindi translations', () {
      expect(NotificationsStrings.get('notifications', 'en'), 'Notifications');
      expect(NotificationsStrings.get('notifications', 'hi'), 'सूचनाएं');
      expect(
        NotificationsStrings.get('notificationSettings', 'en'),
        'Notification Settings',
      );
      expect(
        NotificationsStrings.get('notificationSettings', 'hi'),
        'सूचना सेटिंग्स',
      );
      expect(
        NotificationsStrings.get('markAllAsRead', 'en'),
        'Mark all as read',
      );
      expect(
        NotificationsStrings.get('markAllAsRead', 'hi'),
        'सभी पढ़े गए चिह्नित करें',
      );
      expect(
        NotificationsStrings.get('pushNotifications', 'en'),
        'Push Notifications',
      );
      expect(
        NotificationsStrings.get('pushNotifications', 'hi'),
        'पुश सूचनाएं',
      );
    });
  });

  group('NotificationItem Model Tests', () {
    test('fromJson and toJson deserialize and serialize properly', () {
      final json = {
        'id': 'notif-123',
        'recipientId': 'user-1',
        'senderId': 'user-2',
        'sender': {
          'id': 'user-2',
          'displayName': 'Ramesh Kumar',
          'avatarUrl': 'https://example.com/avatar.jpg',
          'locality': 'Koramangala',
          'city': 'Bengaluru',
        },
        'type': 'POST_COMMENTED',
        'category': 'SOCIAL',
        'title': 'New comment on your post',
        'body': 'Ramesh Kumar commented on your post',
        'data': {'postId': 'post-abc'},
        'deepLink': '/feed/posts/post-abc',
        'isRead': false,
        'readAt': null,
        'createdAt': '2026-09-24T10:00:00.000Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, 'notif-123');
      expect(item.recipientId, 'user-1');
      expect(item.senderId, 'user-2');
      expect(item.sender?.displayName, 'Ramesh Kumar');
      expect(item.type, NotificationType.postCommented);
      expect(item.category, NotificationCategory.social);
      expect(item.title, 'New comment on your post');
      expect(item.body, 'Ramesh Kumar commented on your post');
      expect(item.data['postId'], 'post-abc');
      expect(item.deepLink, '/feed/posts/post-abc');
      expect(item.isRead, false);
      expect(item.readAt, isNull);

      final serialized = item.toJson();
      expect(serialized['id'], 'notif-123');
      expect(serialized['type'], 'POST_COMMENTED');
      expect(serialized['category'], 'SOCIAL');
    });

    test('copyWith updates properties correctly', () {
      final item = NotificationItem(
        id: 'notif-1',
        recipientId: 'u-1',
        type: NotificationType.messageReceived,
        category: NotificationCategory.messages,
        title: 'New message',
        body: 'Hello',
        isRead: false,
        createdAt: DateTime(2026, 9, 24),
      );

      final readItem = item.copyWith(
        isRead: true,
        readAt: DateTime(2026, 9, 24, 12),
      );

      expect(readItem.isRead, true);
      expect(readItem.readAt, DateTime(2026, 9, 24, 12));
      expect(readItem.id, 'notif-1');
    });
  });

  group('NotificationPreferences Model Tests', () {
    test('deserializes defaults and serialization preserves values', () {
      final json = {
        'userId': 'usr-1',
        'messagesEnabled': true,
        'socialEnabled': false,
        'communityEnabled': true,
        'marketplaceEnabled': true,
        'businessEnabled': false,
        'systemEnabled': true,
        'pushEnabled': true,
        'emailEnabled': false,
        'smsEnabled': false,
      };

      final prefs = NotificationPreferences.fromJson(json);
      expect(prefs.userId, 'usr-1');
      expect(prefs.messagesEnabled, true);
      expect(prefs.socialEnabled, false);
      expect(prefs.businessEnabled, false);

      final updated = prefs.copyWith(socialEnabled: true);
      expect(updated.socialEnabled, true);
      expect(updated.businessEnabled, false);
    });
  });
}
