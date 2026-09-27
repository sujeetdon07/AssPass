import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/safety/domain/models/safety_enums.dart';
import 'package:aaspaas/features/safety/domain/models/safety_report_item.dart';

void main() {
  group('SafetyReportItem model tests', () {
    test('fromJson deserializes properly with all fields', () {
      final json = {
        'id': 'rep-123',
        'targetType': 'user',
        'targetId': 'usr-456',
        'reason': 'harassment',
        'status': 'reviewing',
        'details': 'Persistent unwanted messages',
        'createdAt': '2026-09-25T12:00:00.000Z',
      };

      final item = SafetyReportItem.fromJson(json);

      expect(item.id, 'rep-123');
      expect(item.targetType, ReportTargetType.user);
      expect(item.targetId, 'usr-456');
      expect(item.reason, ReportReason.harassment);
      expect(item.status, ReportStatus.reviewing);
      expect(item.details, 'Persistent unwanted messages');
      expect(item.createdAt.toIso8601String(), '2026-09-25T12:00:00.000Z');
    });

    test('fromJson handles null or missing optional fields gracefully', () {
      final json = {
        'id': 'rep-456',
        'targetType': 'conversation',
        'targetId': 'conv-789',
        'reason': 'spam',
        'status': 'pending',
      };

      final item = SafetyReportItem.fromJson(json);

      expect(item.id, 'rep-456');
      expect(item.targetType, ReportTargetType.conversation);
      expect(item.targetId, 'conv-789');
      expect(item.reason, ReportReason.spam);
      expect(item.status, ReportStatus.pending);
      expect(item.details, isNull);
      expect(item.createdAt, isNotNull);
    });

    test('ReportTargetType wire values support new types', () {
      expect(ReportTargetType.user.value, 'user');
      expect(ReportTargetType.user.label, 'User Profile');
      expect(ReportTargetType.conversation.value, 'conversation');
      expect(ReportTargetType.conversation.label, 'Conversation');
      expect(ReportTargetType.message.value, 'message');
      expect(ReportTargetType.message.label, 'Message');
    });

    test('ReportStatus fromString supports all lifecycle states', () {
      expect(ReportStatus.fromString('pending'), ReportStatus.pending);
      expect(ReportStatus.fromString('reviewing'), ReportStatus.reviewing);
      expect(ReportStatus.fromString('actioned'), ReportStatus.actioned);
      expect(ReportStatus.fromString('dismissed'), ReportStatus.dismissed);
      expect(ReportStatus.fromString('duplicate'), ReportStatus.duplicate);
      expect(ReportStatus.fromString('unknown'), ReportStatus.pending);
    });
  });
}
