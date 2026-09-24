import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/post_entity.dart';
import '../data/repositories/feed_repository.dart';
import 'feed_state.dart';

/// Provider for [FeedController].
final feedControllerProvider =
    StateNotifierProvider<FeedController, FeedState>((ref) {
  final repository = ref.watch(feedRepositoryProvider);
  return FeedController(repository);
});

/// StateNotifier controlling community feed retrieval, pagination, filtering, and optimistic likes.
class FeedController extends StateNotifier<FeedState> {
  FeedController(this._repository) : super(const FeedState()) {
    loadFeed();
  }

  final FeedRepository _repository;

  /// Load or refresh the feed posts.
  Future<void> loadFeed({bool isRefresh = false}) async {
    if (state.isLoading || state.isRefreshing) return;

    state = state.copyWith(
      status: isRefresh ? FeedStatus.refreshing : FeedStatus.loading,
      errorMessage: null,
    );

    try {
      final page = await _repository.getFeed(
        category: state.selectedCategory?.value,
        scope: state.selectedScope,
      );

      state = state.copyWith(
        status: FeedStatus.loaded,
        posts: page.posts,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        status: FeedStatus.error,
        errorMessage: 'Unable to load feed. Pull down or tap retry.',
      );
    }
  }

  /// Load the next page of posts using cursor pagination.
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.isLoading ||
        state.isRefreshing ||
        state.nextCursor == null) {
      return;
    }

    state = state.copyWith(status: FeedStatus.loadingMore);

    try {
      final page = await _repository.getFeed(
        cursor: state.nextCursor,
        category: state.selectedCategory?.value,
        scope: state.selectedScope,
      );

      // Deduplicate posts based on ID
      final existingIds = state.posts.map((p) => p.id).toSet();
      final newPosts =
          page.posts.where((p) => !existingIds.contains(p.id)).toList();

      state = state.copyWith(
        status: FeedStatus.loaded,
        posts: [...state.posts, ...newPosts],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      );
    } catch (e) {
      // Revert loadingMore status without wiping existing posts
      state = state.copyWith(status: FeedStatus.loaded);
    }
  }

  /// Change active category filter and reload feed.
  void setCategory(PostCategory? category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
    loadFeed();
  }

  /// Toggle feed scope between 'local' and 'all'.
  void setScope(String scope) {
    if (state.selectedScope == scope) return;
    state = state.copyWith(selectedScope: scope);
    loadFeed();
  }

  /// Optimistic like/unlike toggle.
  Future<void> toggleLike(String postId) async {
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

    // Optimistically update UI
    state = state.copyWith(posts: updatedPosts);

    try {
      if (newLiked) {
        final result = await _repository.likePost(postId);
        final confirmedCount =
            (result['likeCount'] as num?)?.toInt() ?? newCount;
        if (confirmedCount != newCount) {
          final reconciled = updatedPost.copyWith(likeCount: confirmedCount);
          final reconciledList = List<PostEntity>.from(state.posts);
          final curIdx = reconciledList.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            reconciledList[curIdx] = reconciled;
            state = state.copyWith(posts: reconciledList);
          }
        }
      } else {
        final result = await _repository.unlikePost(postId);
        final confirmedCount =
            (result['likeCount'] as num?)?.toInt() ?? newCount;
        if (confirmedCount != newCount) {
          final reconciled = updatedPost.copyWith(likeCount: confirmedCount);
          final reconciledList = List<PostEntity>.from(state.posts);
          final curIdx = reconciledList.indexWhere((p) => p.id == postId);
          if (curIdx != -1) {
            reconciledList[curIdx] = reconciled;
            state = state.copyWith(posts: reconciledList);
          }
        }
      }
    } catch (_) {
      // Revert to original state on failure
      final rollbackList = List<PostEntity>.from(state.posts);
      final curIdx = rollbackList.indexWhere((p) => p.id == postId);
      if (curIdx != -1) {
        rollbackList[curIdx] = originalPost;
        state = state.copyWith(posts: rollbackList);
      }
    }
  }

  /// Add newly created post to the top of feed.
  void addPost(PostEntity post) {
    // If a category filter is active and doesn't match, still insert if it's user's post
    state = state.copyWith(
      posts: [post, ...state.posts],
      status: FeedStatus.loaded,
    );
  }

  /// Update an edited post in place.
  void updatePost(PostEntity updatedPost) {
    final updatedList = state.posts.map((p) {
      return p.id == updatedPost.id ? updatedPost : p;
    }).toList();
    state = state.copyWith(posts: updatedList);
  }

  /// Remove a deleted post from the feed.
  void removePost(String postId) {
    final filtered = state.posts.where((p) => p.id != postId).toList();
    state = state.copyWith(posts: filtered);
  }
}
