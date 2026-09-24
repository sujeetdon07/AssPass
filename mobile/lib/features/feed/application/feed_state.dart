import '../domain/entities/post_entity.dart';

enum FeedStatus {
  initial,
  loading,
  refreshing,
  loaded,
  loadingMore,
  error,
}

/// State representation for the Community Feed.
class FeedState {
  const FeedState({
    this.status = FeedStatus.initial,
    this.posts = const [],
    this.hasMore = false,
    this.nextCursor,
    this.selectedCategory,
    this.selectedScope = 'local',
    this.errorMessage,
  });

  final FeedStatus status;
  final List<PostEntity> posts;
  final bool hasMore;
  final String? nextCursor;
  final PostCategory? selectedCategory;
  final String selectedScope;
  final String? errorMessage;

  bool get isLoading => status == FeedStatus.loading;
  bool get isRefreshing => status == FeedStatus.refreshing;
  bool get isLoadingMore => status == FeedStatus.loadingMore;
  bool get hasError => status == FeedStatus.error;
  bool get isEmpty => status == FeedStatus.loaded && posts.isEmpty;

  FeedState copyWith({
    FeedStatus? status,
    List<PostEntity>? posts,
    bool? hasMore,
    String? nextCursor,
    PostCategory? selectedCategory,
    bool clearCategory = false,
    String? selectedScope,
    String? errorMessage,
  }) {
    return FeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedScope: selectedScope ?? this.selectedScope,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
