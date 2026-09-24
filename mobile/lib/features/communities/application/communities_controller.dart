import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/communities_repository.dart';
import '../domain/entities/community_category.dart';
import '../domain/entities/community_entity.dart';
import 'communities_state.dart';

/// Provider for [CommunitiesController].
final communitiesControllerProvider =
    StateNotifierProvider<CommunitiesController, CommunitiesState>((ref) {
  final repository = ref.watch(communitiesRepositoryProvider);
  return CommunitiesController(repository);
});

/// StateNotifier controlling community list discovery, pagination, category filtering, and tab selection.
class CommunitiesController extends StateNotifier<CommunitiesState> {
  CommunitiesController(this._repository) : super(const CommunitiesState()) {
    loadCommunities();
  }

  final CommunitiesRepository _repository;

  /// Load or refresh communities list.
  Future<void> loadCommunities({bool isRefresh = false}) async {
    if (state.isLoading || state.isRefreshing) return;

    state = state.copyWith(
      status:
          isRefresh ? CommunitiesStatus.refreshing : CommunitiesStatus.loading,
      errorMessage: null,
    );

    try {
      final scope = state.selectedTab == CommunitiesTab.local
          ? 'local'
          : (state.selectedTab == CommunitiesTab.joined ? 'joined' : 'all');
      final joinedOnly =
          state.selectedTab == CommunitiesTab.joined ? true : null;

      final page = await _repository.getCommunities(
        category: state.selectedCategory?.value,
        scope: scope,
        joinedOnly: joinedOnly,
      );
      debugPrint(
        '[CommunitiesController] page loaded: ${page.communities.length} items, hasMore=${page.hasMore}',
      );

      state = state.copyWith(
        status: CommunitiesStatus.loaded,
        communities: page.communities,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e, st) {
      debugPrint('[CommunitiesController] loadCommunities error: $e\n$st');
      state = state.copyWith(
        status: CommunitiesStatus.error,
        errorMessage: 'Unable to load communities. Tap retry.',
      );
    }
  }

  /// Load the next page of communities using cursor pagination.
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.isLoading ||
        state.isRefreshing ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(status: CommunitiesStatus.loadingMore);

    try {
      final scope = state.selectedTab == CommunitiesTab.local
          ? 'local'
          : (state.selectedTab == CommunitiesTab.joined ? 'joined' : 'all');
      final joinedOnly =
          state.selectedTab == CommunitiesTab.joined ? true : null;

      final page = await _repository.getCommunities(
        cursor: state.nextCursor,
        category: state.selectedCategory?.value,
        scope: scope,
        joinedOnly: joinedOnly,
      );

      final existingIds = state.communities.map((c) => c.id).toSet();
      final newCommunities =
          page.communities.where((c) => !existingIds.contains(c.id)).toList();

      state = state.copyWith(
        status: CommunitiesStatus.loaded,
        communities: [...state.communities, ...newCommunities],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(status: CommunitiesStatus.loaded);
    }
  }

  /// Switch category filter.
  void setCategory(CommunityCategory? category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
    loadCommunities();
  }

  /// Switch tab (All / In My Area / My Communities).
  void setTab(CommunitiesTab tab) {
    if (state.selectedTab == tab) return;
    state = state.copyWith(selectedTab: tab);
    loadCommunities();
  }

  /// Optimistic join/leave toggle from the community card or listing.
  Future<void> toggleJoin(CommunityEntity community) async {
    final index = state.communities.indexWhere((c) => c.id == community.id);
    if (index == -1) return;

    final original = state.communities[index];
    final willJoin = !original.currentUserMember;
    final newCount = willJoin
        ? original.memberCount + 1
        : (original.memberCount > 1 ? original.memberCount - 1 : 1);

    final updated = original.copyWith(
      currentUserMember: willJoin,
      memberCount: newCount,
      currentUserRole: willJoin ? 'member' : null,
    );

    final list = List<CommunityEntity>.from(state.communities);
    list[index] = updated;
    state = state.copyWith(communities: list);

    try {
      if (willJoin) {
        final serverUpdated = await _repository.joinCommunity(community.id);
        final curIdx =
            state.communities.indexWhere((c) => c.id == community.id);
        if (curIdx != -1) {
          final reconciled = List<CommunityEntity>.from(state.communities);
          reconciled[curIdx] = serverUpdated;
          state = state.copyWith(communities: reconciled);
        }
      } else {
        final serverUpdated = await _repository.leaveCommunity(community.id);
        final curIdx =
            state.communities.indexWhere((c) => c.id == community.id);
        if (curIdx != -1) {
          final reconciled = List<CommunityEntity>.from(state.communities);
          reconciled[curIdx] = serverUpdated;
          state = state.copyWith(communities: reconciled);
        }
      }
    } catch (_) {
      // Revert on failure
      final rollback = List<CommunityEntity>.from(state.communities);
      final curIdx = rollback.indexWhere((c) => c.id == community.id);
      if (curIdx != -1) {
        rollback[curIdx] = original;
        state = state.copyWith(communities: rollback);
      }
    }
  }

  /// Add a newly created community to the front of list.
  void addCommunity(CommunityEntity community) {
    state = state.copyWith(
      communities: [community, ...state.communities],
      status: CommunitiesStatus.loaded,
    );
  }

  /// Update an edited community in place.
  void updateCommunity(CommunityEntity updated) {
    final list = state.communities.map((c) {
      return c.id == updated.id ? updated : c;
    }).toList();
    state = state.copyWith(communities: list);
  }
}
