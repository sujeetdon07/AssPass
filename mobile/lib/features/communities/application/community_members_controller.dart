import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/communities_repository.dart';
import '../domain/entities/community_member_entity.dart';

class CommunityMembersState {
  const CommunityMembersState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.members = const [],
    this.hasMore = false,
    this.nextCursor,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<CommunityMemberEntity> members;
  final bool hasMore;
  final String? nextCursor;
  final String? errorMessage;

  bool get isEmpty => !isLoading && members.isEmpty;

  CommunityMembersState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<CommunityMemberEntity>? members,
    bool? hasMore,
    String? nextCursor,
    String? errorMessage,
  }) {
    return CommunityMembersState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      members: members ?? this.members,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for [CommunityMembersController] family keyed by communityId.
final communityMembersControllerProvider = StateNotifierProvider.autoDispose
    .family<CommunityMembersController, CommunityMembersState, String>(
        (ref, communityId) {
  final repository = ref.watch(communitiesRepositoryProvider);
  return CommunityMembersController(communityId, repository);
});

/// StateNotifier controlling paginated member list of a community.
class CommunityMembersController extends StateNotifier<CommunityMembersState> {
  CommunityMembersController(this.communityId, this._repository)
      : super(const CommunityMembersState()) {
    loadMembers();
  }

  final String communityId;
  final CommunitiesRepository _repository;

  Future<void> loadMembers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final page = await _repository.getCommunityMembers(id: communityId);
      state = state.copyWith(
        isLoading: false,
        members: page.members,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load community members.',
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.isLoading ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.getCommunityMembers(
        id: communityId,
        cursor: state.nextCursor,
      );

      final existingIds = state.members.map((m) => m.id).toSet();
      final newMembers =
          page.members.where((m) => !existingIds.contains(m.id)).toList();

      state = state.copyWith(
        isLoadingMore: false,
        members: [...state.members, ...newMembers],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}
