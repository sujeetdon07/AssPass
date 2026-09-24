import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/data/repositories/feed_repository.dart';
import '../../feed/domain/entities/post_entity.dart';
import '../data/repositories/nearby_repository.dart';
import 'nearby_state.dart';

/// Provider for [NearbyController].
final nearbyControllerProvider =
    StateNotifierProvider<NearbyController, NearbyState>((ref) {
  final nearbyRepo = ref.watch(nearbyRepositoryProvider);
  final feedRepo = ref.watch(feedRepositoryProvider);
  return NearbyController(nearbyRepo, feedRepo);
});

class NearbyController extends StateNotifier<NearbyState> {
  NearbyController(this._nearbyRepository, this._feedRepository)
      : super(const NearbyState());

  final NearbyRepository _nearbyRepository;
  final FeedRepository _feedRepository;

  /// Fetch nearby posts for the given coordinates with optional refresh.
  Future<void> loadNearbyPosts({
    required double latitude,
    required double longitude,
    bool refresh = false,
  }) async {
    if (refresh) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final page = await _nearbyRepository.getNearbyPosts(
        latitude: latitude,
        longitude: longitude,
        radius: state.radiusKm,
        category: state.selectedCategory,
        limit: 20,
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        posts: page.posts,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Unable to load nearby posts. Please try again.',
      );
    }
  }

  /// Load next page of nearby results using cursor pagination.
  Future<void> loadMore({
    required double latitude,
    required double longitude,
  }) async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _nearbyRepository.getNearbyPosts(
        latitude: latitude,
        longitude: longitude,
        radius: state.radiusKm,
        category: state.selectedCategory,
        cursor: state.nextCursor,
        limit: 20,
      );

      state = state.copyWith(
        isLoadingMore: false,
        posts: [...state.posts, ...page.posts],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Change discovery radius and immediately reload posts.
  Future<void> setRadius(
    int radiusKm, {
    required double latitude,
    required double longitude,
  }) async {
    if (state.radiusKm == radiusKm) return;
    state = state.copyWith(radiusKm: radiusKm);
    await loadNearbyPosts(latitude: latitude, longitude: longitude);
  }

  /// Filter nearby posts by category.
  Future<void> setCategory(
    PostCategory? category, {
    required double latitude,
    required double longitude,
  }) async {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
    await loadNearbyPosts(latitude: latitude, longitude: longitude);
  }

  /// Optimistically toggle like on a nearby post.
  Future<void> toggleLike(String postId) async {
    final index = state.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final currentPost = state.posts[index];
    final newLiked = !currentPost.currentUserLiked;
    final newCount = newLiked
        ? currentPost.likeCount + 1
        : (currentPost.likeCount > 0 ? currentPost.likeCount - 1 : 0);

    final updated = currentPost.copyWith(
      currentUserLiked: newLiked,
      likeCount: newCount,
    );

    final updatedList = List<PostEntity>.from(state.posts);
    updatedList[index] = updated;
    state = state.copyWith(posts: updatedList);

    try {
      if (newLiked) {
        await _feedRepository.likePost(postId);
      } else {
        await _feedRepository.unlikePost(postId);
      }
    } catch (_) {
      // Revert optimistic update on failure
      final revertedList = List<PostEntity>.from(state.posts);
      revertedList[index] = currentPost;
      state = state.copyWith(posts: revertedList);
    }
  }
}
