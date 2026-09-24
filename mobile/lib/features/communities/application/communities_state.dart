import '../domain/entities/community_category.dart';
import '../domain/entities/community_entity.dart';

enum CommunitiesStatus {
  initial,
  loading,
  refreshing,
  loaded,
  loadingMore,
  error,
}

enum CommunitiesTab {
  all('all', 'All Communities'),
  local('local', 'In My Area'),
  joined('joined', 'My Communities');

  const CommunitiesTab(this.value, this.label);
  final String value;
  final String label;
}

/// State representation for the Communities discovery list.
class CommunitiesState {
  const CommunitiesState({
    this.status = CommunitiesStatus.initial,
    this.communities = const [],
    this.hasMore = false,
    this.nextCursor,
    this.selectedCategory,
    this.selectedTab = CommunitiesTab.all,
    this.searchQuery = '',
    this.errorMessage,
  });

  final CommunitiesStatus status;
  final List<CommunityEntity> communities;
  final bool hasMore;
  final String? nextCursor;
  final CommunityCategory? selectedCategory;
  final CommunitiesTab selectedTab;
  final String searchQuery;
  final String? errorMessage;

  bool get isLoading => status == CommunitiesStatus.loading;
  bool get isRefreshing => status == CommunitiesStatus.refreshing;
  bool get isLoadingMore => status == CommunitiesStatus.loadingMore;
  bool get hasError => status == CommunitiesStatus.error;
  bool get isEmpty => status == CommunitiesStatus.loaded && communities.isEmpty;

  CommunitiesState copyWith({
    CommunitiesStatus? status,
    List<CommunityEntity>? communities,
    bool? hasMore,
    String? nextCursor,
    CommunityCategory? selectedCategory,
    bool clearCategory = false,
    CommunitiesTab? selectedTab,
    String? searchQuery,
    String? errorMessage,
  }) {
    return CommunitiesState(
      status: status ?? this.status,
      communities: communities ?? this.communities,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
