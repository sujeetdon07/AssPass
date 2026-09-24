import '../../feed/domain/entities/post_entity.dart';

/// State representing the nearby discovery feed, radius options, and pagination.
class NearbyState {
  const NearbyState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.posts = const [],
    this.radiusKm = 5,
    this.selectedCategory,
    this.nextCursor,
    this.hasMore = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final List<PostEntity> posts;
  final int radiusKm;
  final PostCategory? selectedCategory;
  final String? nextCursor;
  final bool hasMore;
  final String? errorMessage;

  bool get isEmpty => !isLoading && posts.isEmpty && errorMessage == null;

  NearbyState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    List<PostEntity>? posts,
    int? radiusKm,
    PostCategory? selectedCategory,
    bool clearCategory = false,
    String? nextCursor,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NearbyState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      posts: posts ?? this.posts,
      radiusKm: radiusKm ?? this.radiusKm,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
