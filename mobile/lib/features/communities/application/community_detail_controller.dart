import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/data/repositories/feed_repository.dart';
import '../../feed/domain/entities/post_entity.dart';
import '../data/repositories/communities_repository.dart';
import '../domain/entities/community_category.dart';
import 'communities_controller.dart';
import 'community_detail_state.dart';

/// Provider for [CommunityDetailController] family keyed by communityId.
final communityDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<CommunityDetailController, CommunityDetailState, String>(
        (ref, communityId) {
  final communitiesRepository = ref.watch(communitiesRepositoryProvider);
  final feedRepository = ref.watch(feedRepositoryProvider);
  return CommunityDetailController(
    communityId: communityId,
    communitiesRepository: communitiesRepository,
    feedRepository: feedRepository,
    ref: ref,
  );
});

/// StateNotifier controlling single community details, post feed, and membership actions.
class CommunityDetailController extends StateNotifier<CommunityDetailState> {
  CommunityDetailController({
    required this.communityId,
    required CommunitiesRepository communitiesRepository,
    required FeedRepository feedRepository,
    required Ref ref,
  })  : _communitiesRepository = communitiesRepository,
        _feedRepository = feedRepository,
        _ref = ref,
        super(const CommunityDetailState()) {
    loadDetails();
  }

  final String communityId;
  final CommunitiesRepository _communitiesRepository;
  final FeedRepository _feedRepository;
  final Ref _ref;

  /// Load community metadata and its post feed.
  Future<void> loadDetails() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final community =
          await _communitiesRepository.getCommunityById(communityId);
      state = state.copyWith(
        isLoading: false,
        community: community,
      );

      // If user can view posts (public or member), load posts feed
      if (state.canViewPosts) {
        await loadPosts();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load community. Please try again.',
      );
    }
  }

  /// Load posts for this community.
  Future<void> loadPosts({bool isRefresh = false}) async {
    state = state.copyWith(isLoadingPosts: true, postsErrorMessage: null);

    try {
      final page =
          await _communitiesRepository.getCommunityPosts(id: communityId);
      state = state.copyWith(
        isLoadingPosts: false,
        posts: page.posts,
        hasMorePosts: page.hasMore,
        nextPostsCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPosts: false,
        postsErrorMessage: 'Unable to load community posts.',
      );
    }
  }

  /// Load next page of posts.
  Future<void> loadMorePosts() async {
    if (!state.hasMorePosts ||
        state.isLoadingMorePosts ||
        state.isLoadingPosts ||
        state.nextPostsCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMorePosts: true);

    try {
      final page = await _communitiesRepository.getCommunityPosts(
        id: communityId,
        cursor: state.nextPostsCursor,
      );

      final existingIds = state.posts.map((p) => p.id).toSet();
      final newPosts =
          page.posts.where((p) => !existingIds.contains(p.id)).toList();

      state = state.copyWith(
        isLoadingMorePosts: false,
        posts: [...state.posts, ...newPosts],
        hasMorePosts: page.hasMore,
        nextPostsCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMorePosts: false);
    }
  }

  /// Join this community.
  Future<bool> join() async {
    if (state.community == null || state.isActionLoading) return false;

    final currentCommunity = state.community!;
    state = state.copyWith(isActionLoading: true);

    // Optimistic update
    final updated = currentCommunity.copyWith(
      currentUserMember: true,
      memberCount: currentCommunity.memberCount + 1,
      currentUserRole: 'member',
    );
    state = state.copyWith(community: updated);

    try {
      final serverUpdated =
          await _communitiesRepository.joinCommunity(communityId);
      state = state.copyWith(
        isActionLoading: false,
        community: serverUpdated,
      );
      _ref
          .read(communitiesControllerProvider.notifier)
          .updateCommunity(serverUpdated);

      // If posts were hidden before, load them now
      if (state.posts.isEmpty) {
        await loadPosts();
      }
      return true;
    } catch (e) {
      // Rollback
      state = state.copyWith(
        isActionLoading: false,
        community: currentCommunity,
      );
      return false;
    }
  }

  /// Leave this community.
  Future<bool> leave() async {
    if (state.community == null || state.isActionLoading) return false;

    final currentCommunity = state.community!;
    state = state.copyWith(isActionLoading: true);

    // Optimistic update
    final updated = currentCommunity.copyWith(
      currentUserMember: false,
      memberCount: currentCommunity.memberCount > 1
          ? currentCommunity.memberCount - 1
          : 1,
      currentUserRole: null,
    );
    state = state.copyWith(community: updated);

    try {
      final serverUpdated =
          await _communitiesRepository.leaveCommunity(communityId);
      state = state.copyWith(
        isActionLoading: false,
        community: serverUpdated,
      );
      _ref
          .read(communitiesControllerProvider.notifier)
          .updateCommunity(serverUpdated);

      // If private community, clear posts
      if (serverUpdated.isPrivate) {
        state = state.copyWith(posts: const []);
      }
      return true;
    } catch (e) {
      // Rollback
      state = state.copyWith(
        isActionLoading: false,
        community: currentCommunity,
      );
      return false;
    }
  }

  /// Create a post inside this community.
  Future<PostEntity?> createPost({
    required String content,
    required PostCategory category,
  }) async {
    try {
      final post = await _communitiesRepository.createCommunityPost(
        id: communityId,
        content: content,
        category: category,
      );

      // Prepend to posts list and increment community postCount
      state = state.copyWith(
        posts: [post, ...state.posts],
        community: state.community?.copyWith(
          postCount: (state.community?.postCount ?? 0) + 1,
        ),
      );

      if (state.community != null) {
        _ref
            .read(communitiesControllerProvider.notifier)
            .updateCommunity(state.community!);
      }

      return post;
    } catch (e) {
      return null;
    }
  }

  /// Optimistic like toggle on a post in this community feed.
  Future<void> togglePostLike(String postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final originalPost = state.posts[index];
    final newLiked = !originalPost.currentUserLiked;
    final newCount = newLiked
        ? originalPost.likeCount + 1
        : (originalPost.likeCount > 0 ? originalPost.likeCount - 1 : 0);

    final updatedPost = originalPost.copyWith(
      currentUserLiked: newLiked,
      likeCount: newCount,
    );

    final updatedPosts = List<PostEntity>.from(state.posts);
    updatedPosts[index] = updatedPost;
    state = state.copyWith(posts: updatedPosts);

    try {
      if (newLiked) {
        final result = await _feedRepository.likePost(postId);
        final confirmedCount =
            (result['likeCount'] as num?)?.toInt() ?? newCount;
        if (confirmedCount != newCount) {
          final reconciled = updatedPost.copyWith(likeCount: confirmedCount);
          final list = List<PostEntity>.from(state.posts);
          final curIdx = list.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            list[curIdx] = reconciled;
            state = state.copyWith(posts: list);
          }
        }
      } else {
        final result = await _feedRepository.unlikePost(postId);
        final confirmedCount =
            (result['likeCount'] as num?)?.toInt() ?? newCount;
        if (confirmedCount != newCount) {
          final reconciled = updatedPost.copyWith(likeCount: confirmedCount);
          final list = List<PostEntity>.from(state.posts);
          final curIdx = list.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            list[curIdx] = reconciled;
            state = state.copyWith(posts: list);
          }
        }
      }
    } catch (_) {
      final rollback = List<PostEntity>.from(state.posts);
      final curIdx = rollback.indexWhere((p) => p.id == postId);
      if (curIdx != -1) {
        rollback[curIdx] = originalPost;
        state = state.copyWith(posts: rollback);
      }
    }
  }

  /// Report this community.
  Future<bool> report({required String reason, String? details}) async {
    try {
      await _communitiesRepository.reportCommunity(
        id: communityId,
        reason: reason,
        details: details,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update community settings (for owner/mod).
  Future<bool> updateCommunity({
    String? name,
    String? description,
    CommunityCategory? category,
    String? visibility,
    String? locality,
    String? neighborhood,
    String? coverImageUrl,
    String? avatarUrl,
  }) async {
    try {
      final updated = await _communitiesRepository.updateCommunity(
        id: communityId,
        name: name,
        description: description,
        category: category,
        visibility: visibility,
        locality: locality,
        neighborhood: neighborhood,
        coverImageUrl: coverImageUrl,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(community: updated);
      _ref
          .read(communitiesControllerProvider.notifier)
          .updateCommunity(updated);
      return true;
    } catch (_) {
      return false;
    }
  }
}
