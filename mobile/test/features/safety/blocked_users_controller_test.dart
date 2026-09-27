import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/safety/application/blocked_users_controller.dart';
import 'package:aaspaas/features/safety/data/repositories/safety_repository.dart';
import 'package:aaspaas/features/safety/domain/models/blocked_user_record.dart';
import 'package:aaspaas/features/safety/domain/models/safety_enums.dart';
import 'package:aaspaas/features/safety/domain/models/safety_report_item.dart';

class _FakeSafetyRepository implements SafetyRepository {
  List<BlockedUserRecord> blockedList = [];
  bool shouldThrow = false;
  String? lastUnblockedUserId;
  String? lastBlockedUserId;

  @override
  Future<void> blockUser(String userId) async {
    if (shouldThrow) throw Exception('Network error');
    lastBlockedUserId = userId;
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (shouldThrow) throw Exception('Network error');
    lastUnblockedUserId = userId;
    blockedList.removeWhere((r) => r.blockedUserId == userId);
  }

  @override
  Future<({List<BlockedUserRecord> items, String? nextCursor, bool hasMore})>
      getBlockedUsers({int limit = 20, String? cursor}) async {
    if (shouldThrow) throw Exception('Network error');
    return (
      items: List<BlockedUserRecord>.from(blockedList),
      hasMore: false,
      nextCursor: null,
    );
  }

  @override
  Future<void> submitReport({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
    String? secondaryId,
  }) async {
    if (shouldThrow) throw Exception('Network error');
  }

  @override
  Future<({List<SafetyReportItem> items, String? nextCursor, bool hasMore})>
      getMyReports({int limit = 20, String? cursor}) async {
    if (shouldThrow) throw Exception('Network error');
    return (
      items: <SafetyReportItem>[],
      hasMore: false,
      nextCursor: null,
    );
  }
}

void main() {
  late _FakeSafetyRepository fakeRepo;
  late ProviderContainer container;
  late ProviderSubscription<BlockedUsersState> subscription;

  setUp(() {
    fakeRepo = _FakeSafetyRepository();
    fakeRepo.blockedList = [
      BlockedUserRecord(
        blockId: 'blk-1',
        blockedAt: DateTime.now(),
        blockedUserId: 'user-2',
        displayName: 'Neighbour Two',
        locality: 'Indiranagar',
        city: 'Bengaluru',
      ),
      BlockedUserRecord(
        blockId: 'blk-2',
        blockedAt: DateTime.now(),
        blockedUserId: 'user-3',
        displayName: 'Neighbour Three',
      ),
    ];

    container = ProviderContainer(
      overrides: [
        safetyRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    // Keep autoDispose provider alive during the test
    subscription = container.listen(
      blockedUsersControllerProvider,
      (_, __) {},
    );
  });

  tearDown(() {
    subscription.close();
    container.dispose();
  });

  group('BlockedUsersController Tests', () {
    test('initial state loads blocked users from repository', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = subscription.read();
      expect(state.isLoading, false);
      expect(state.items.length, 2);
      expect(state.items.first.displayName, 'Neighbour Two');
      expect(state.hasError, false);
    });

    test('load sets error on repository exception', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fakeRepo.shouldThrow = true;
      final controller =
          container.read(blockedUsersControllerProvider.notifier);

      await controller.load();

      final state = subscription.read();
      expect(state.isLoading, false);
      expect(state.hasError, true);
      expect(state.error, isNotNull);
    });

    test('unblock removes user optimistically and delegates to repository',
        () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final controller =
          container.read(blockedUsersControllerProvider.notifier);

      final success = await controller.unblock('user-2');

      expect(success, true);
      expect(fakeRepo.lastUnblockedUserId, 'user-2');
      final state = subscription.read();
      expect(state.items.length, 1);
      expect(state.items.first.blockedUserId, 'user-3');
    });

    test('unblock rolls back state if repository call fails', () async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      fakeRepo.shouldThrow = true;
      final controller =
          container.read(blockedUsersControllerProvider.notifier);

      final success = await controller.unblock('user-2');

      expect(success, false);
      final state = subscription.read();
      expect(state.items.length, 2); // rolled back
    });
  });
}
