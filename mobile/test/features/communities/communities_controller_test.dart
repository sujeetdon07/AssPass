import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/communities/application/communities_controller.dart';
import 'package:aaspaas/features/communities/application/communities_state.dart';
import 'package:aaspaas/features/communities/data/models/communities_page_model.dart';
import 'package:aaspaas/features/communities/data/repositories/communities_repository.dart';
import 'package:aaspaas/features/communities/domain/entities/community_category.dart';
import 'package:aaspaas/features/communities/domain/entities/community_entity.dart';

class _FakeCommunitiesRepository extends Fake implements CommunitiesRepository {
  List<CommunityEntity> returnCommunities = [];
  bool shouldThrow = false;
  int joinCalls = 0;
  int leaveCalls = 0;

  @override
  Future<CommunitiesPageModel> getCommunities({
    String? cursor,
    int limit = 20,
    String? category,
    String? search,
    String scope = 'all',
    bool? joinedOnly,
    String? locality,
    String? city,
  }) async {
    if (shouldThrow) throw Exception('Network error');
    return CommunitiesPageModel(
      communities: returnCommunities,
      hasMore: returnCommunities.length >= limit,
      nextCursor: returnCommunities.isNotEmpty ? 'cursor-next' : null,
    );
  }

  @override
  Future<CommunityEntity> joinCommunity(String id) async {
    joinCalls++;
    if (shouldThrow) throw Exception('Join failed');
    final match = returnCommunities.firstWhere((c) => c.id == id);
    return match.copyWith(
      currentUserMember: true,
      memberCount: match.memberCount + 1,
      currentUserRole: 'member',
    );
  }

  @override
  Future<CommunityEntity> leaveCommunity(String id) async {
    leaveCalls++;
    if (shouldThrow) throw Exception('Leave failed');
    final match = returnCommunities.firstWhere((c) => c.id == id);
    return match.copyWith(
      currentUserMember: false,
      memberCount: match.memberCount > 1 ? match.memberCount - 1 : 1,
      currentUserRole: null,
    );
  }
}

CommunityEntity createTestCommunity({
  String id = 'comm-1',
  String name = 'Test Community',
  CommunityCategory category = CommunityCategory.society,
  bool currentUserMember = false,
  int memberCount = 10,
}) {
  return CommunityEntity(
    id: id,
    name: name,
    slug: name.toLowerCase().replaceAll(' ', '-'),
    description: 'Test community description',
    category: category,
    creatorId: 'user-creator',
    memberCount: memberCount,
    postCount: 5,
    currentUserMember: currentUserMember,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

void main() {
  late _FakeCommunitiesRepository repository;

  setUp(() {
    repository = _FakeCommunitiesRepository();
  });

  group('CommunitiesController', () {
    test('initial load fetches communities successfully', () async {
      final testComm = createTestCommunity();
      repository.returnCommunities = [testComm];

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      expect(controller.state.status, CommunitiesStatus.loaded);
      expect(controller.state.communities.length, 1);
      expect(controller.state.communities.first.name, 'Test Community');
      expect(controller.state.hasError, isFalse);
    });

    test('error during load sets error status', () async {
      repository.shouldThrow = true;

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      expect(controller.state.status, CommunitiesStatus.error);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.communities, isEmpty);
    });

    test('setCategory updates category and reloads', () async {
      repository.returnCommunities = [
        createTestCommunity(category: CommunityCategory.sports),
      ];

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      controller.setCategory(CommunityCategory.sports);
      expect(controller.state.selectedCategory, CommunityCategory.sports);

      // Toggling same category clears it
      controller.setCategory(CommunityCategory.sports);
      expect(controller.state.selectedCategory, isNull);
    });

    test('setTab updates tab selection', () async {
      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      controller.setTab(CommunitiesTab.joined);
      expect(controller.state.selectedTab, CommunitiesTab.joined);

      controller.setTab(CommunitiesTab.local);
      expect(controller.state.selectedTab, CommunitiesTab.local);
    });

    test('toggleJoin performs optimistic update when joining', () async {
      final comm = createTestCommunity(
        id: 'comm-join',
        currentUserMember: false,
        memberCount: 5,
      );
      repository.returnCommunities = [comm];

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      await controller.toggleJoin(comm);

      expect(repository.joinCalls, 1);
      expect(controller.state.communities.first.currentUserMember, isTrue);
      expect(controller.state.communities.first.memberCount, 6);
    });

    test('toggleJoin performs optimistic update when leaving', () async {
      final comm = createTestCommunity(
        id: 'comm-leave',
        currentUserMember: true,
        memberCount: 10,
      );
      repository.returnCommunities = [comm];

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      await controller.toggleJoin(comm);

      expect(repository.leaveCalls, 1);
      expect(controller.state.communities.first.currentUserMember, isFalse);
      expect(controller.state.communities.first.memberCount, 9);
    });

    test('toggleJoin rolls back on API failure', () async {
      final comm = createTestCommunity(
        id: 'comm-fail',
        currentUserMember: false,
        memberCount: 5,
      );
      repository.returnCommunities = [comm];

      final controller = CommunitiesController(repository);
      await controller.loadCommunities();

      // Trigger error on join call
      repository.shouldThrow = true;
      await controller.toggleJoin(comm);

      // Should rollback to original values
      expect(controller.state.communities.first.currentUserMember, isFalse);
      expect(controller.state.communities.first.memberCount, 5);
    });
  });
}
