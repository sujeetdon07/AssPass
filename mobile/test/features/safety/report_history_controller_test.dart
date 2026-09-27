import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/safety/application/report_history_controller.dart';
import 'package:aaspaas/features/safety/data/repositories/safety_repository.dart';
import 'package:aaspaas/features/safety/domain/models/blocked_user_record.dart';
import 'package:aaspaas/features/safety/domain/models/safety_enums.dart';
import 'package:aaspaas/features/safety/domain/models/safety_report_item.dart';

class _FakeSafetyRepo implements SafetyRepository {
  List<SafetyReportItem> reportItems = [];
  bool shouldThrow = false;
  bool hasMore = false;
  String? nextCursor;

  @override
  Future<void> blockUser(String userId) async {}

  @override
  Future<void> unblockUser(String userId) async {}

  @override
  Future<({List<BlockedUserRecord> items, String? nextCursor, bool hasMore})>
      getBlockedUsers({int limit = 20, String? cursor}) async {
    return (items: <BlockedUserRecord>[], nextCursor: null, hasMore: false);
  }

  @override
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
    String? secondaryId,
  }) async {}

  @override
  Future<({List<SafetyReportItem> items, String? nextCursor, bool hasMore})>
      getMyReports({int limit = 20, String? cursor}) async {
    if (shouldThrow) throw Exception('Network error');
    return (
      items: List<SafetyReportItem>.from(reportItems),
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }
}

void main() {
  late _FakeSafetyRepo fakeRepo;
  late ProviderContainer container;

  setUp(() {
    fakeRepo = _FakeSafetyRepo();
    fakeRepo.reportItems = [
      SafetyReportItem(
        id: 'rep-1',
        targetType: ReportTargetType.user,
        targetId: 'usr-1',
        reason: ReportReason.harassment,
        status: ReportStatus.pending,
        createdAt: DateTime.now(),
      ),
      SafetyReportItem(
        id: 'rep-2',
        targetType: ReportTargetType.post,
        targetId: 'post-1',
        reason: ReportReason.spam,
        status: ReportStatus.actioned,
        createdAt: DateTime.now(),
      ),
    ];
    container = ProviderContainer(
      overrides: [
        safetyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ReportHistoryController Tests', () {
    test('initial state loads reports from repository', () async {
      final sub = container.listen(
        reportHistoryControllerProvider,
        (_, __) {},
      );

      // Initial state is loading
      expect(sub.read().isLoading, true);

      // Wait for microtask
      await container.read(reportHistoryControllerProvider.notifier).load();

      final state = sub.read();
      expect(state.isLoading, false);
      expect(state.hasError, false);
      expect(state.items.length, 2);
      expect(state.items.first.id, 'rep-1');
      expect(state.items.first.targetType, ReportTargetType.user);
    });

    test('sets error on repository exception', () async {
      fakeRepo.shouldThrow = true;
      final sub = container.listen(
        reportHistoryControllerProvider,
        (_, __) {},
      );

      await container.read(reportHistoryControllerProvider.notifier).load();

      final state = sub.read();
      expect(state.isLoading, false);
      expect(state.hasError, true);
      expect(state.error, contains('Unable to load report history'));
    });

    test('refresh reloads reports and clears error', () async {
      fakeRepo.shouldThrow = true;
      final sub = container.listen(
        reportHistoryControllerProvider,
        (_, __) {},
      );

      await container.read(reportHistoryControllerProvider.notifier).load();
      expect(sub.read().hasError, true);

      // Recover and refresh
      fakeRepo.shouldThrow = false;
      await container.read(reportHistoryControllerProvider.notifier).refresh();

      final state = sub.read();
      expect(state.hasError, false);
      expect(state.items.length, 2);
    });

    test('loadMore appends items when hasMore is true', () async {
      fakeRepo.hasMore = true;
      fakeRepo.nextCursor = 'cursor-1';
      final sub = container.listen(
        reportHistoryControllerProvider,
        (_, __) {},
      );

      await container.read(reportHistoryControllerProvider.notifier).load();
      expect(sub.read().items.length, 2);
      expect(sub.read().hasMore, true);

      // Setup page 2
      fakeRepo.reportItems = [
        SafetyReportItem(
          id: 'rep-3',
          targetType: ReportTargetType.conversation,
          targetId: 'conv-1',
          reason: ReportReason.scamOrFraud,
          status: ReportStatus.reviewing,
          createdAt: DateTime.now(),
        ),
      ];
      fakeRepo.hasMore = false;
      fakeRepo.nextCursor = null;

      await container.read(reportHistoryControllerProvider.notifier).loadMore();

      final state = sub.read();
      expect(state.items.length, 3);
      expect(state.items.last.id, 'rep-3');
      expect(state.hasMore, false);
    });
  });
}
