import '../domain/entities/marketplace_filter.dart';
import '../domain/entities/marketplace_listing_entity.dart';

class MarketplaceState {
  const MarketplaceState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.listings = const [],
    this.filter = const MarketplaceFilter(),
    this.nextCursor,
    this.hasMore = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final List<MarketplaceListingEntity> listings;
  final MarketplaceFilter filter;
  final String? nextCursor;
  final bool hasMore;
  final String? errorMessage;

  bool get isEmpty => !isLoading && listings.isEmpty && errorMessage == null;

  MarketplaceState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    List<MarketplaceListingEntity>? listings,
    MarketplaceFilter? filter,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MarketplaceState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      listings: listings ?? this.listings,
      filter: filter ?? this.filter,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
