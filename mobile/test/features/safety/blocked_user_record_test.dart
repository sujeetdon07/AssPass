import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/safety/domain/models/blocked_user_record.dart';
import 'package:aaspaas/features/safety/domain/models/safety_enums.dart';

void main() {
  group('BlockedUserRecord model tests', () {
    test('fromJson deserializes properly with all fields', () {
      final json = {
        'blockId': 'block-123',
        'blockedAt': '2026-09-25T10:00:00.000Z',
        'blockedUser': {
          'id': 'user-456',
          'displayName': 'Suresh Raina',
          'avatarUrl': 'https://example.com/suresh.jpg',
          'locality': 'Indiranagar',
          'city': 'Bengaluru',
        },
      };

      final record = BlockedUserRecord.fromJson(json);

      expect(record.blockId, 'block-123');
      expect(record.blockedUserId, 'user-456');
      expect(record.displayName, 'Suresh Raina');
      expect(record.avatarUrl, 'https://example.com/suresh.jpg');
      expect(record.locality, 'Indiranagar');
      expect(record.city, 'Bengaluru');
      expect(record.blockedAt, DateTime.parse('2026-09-25T10:00:00.000Z'));
    });

    test('fromJson handles null optional fields gracefully', () {
      final json = {
        'blockId': 'block-999',
        'blockedAt': '2026-09-25T12:00:00.000Z',
        'blockedUser': {
          'id': 'user-789',
        },
      };

      final record = BlockedUserRecord.fromJson(json);

      expect(record.blockId, 'block-999');
      expect(record.blockedUserId, 'user-789');
      expect(record.displayName, 'Neighbor');
      expect(record.avatarUrl, isNull);
      expect(record.locality, isNull);
      expect(record.city, isNull);
    });
  });

  group('Safety Enums tests', () {
    test('ReportTargetType wire values match backend specification', () {
      expect(ReportTargetType.post.value, 'post');
      expect(ReportTargetType.post.label, 'Post');
      expect(ReportTargetType.comment.value, 'comment');
      expect(ReportTargetType.listing.value, 'listing');
      expect(ReportTargetType.business.value, 'business');
      expect(ReportTargetType.service.value, 'service');
    });

    test('ReportReason wire values and display labels', () {
      expect(ReportReason.spam.value, 'spam');
      expect(ReportReason.spam.label, 'Spam or commercial advertising');
      expect(ReportReason.harassment.value, 'harassment');
      expect(ReportReason.fraud.value, 'fraud');
      expect(ReportReason.illegalContent.value, 'illegal_content');
      expect(ReportReason.other.value, 'other');
    });
  });
}
