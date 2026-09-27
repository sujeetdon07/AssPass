import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/marketplace_repository.dart';
import '../domain/entities/marketplace_listing_entity.dart';

/// State for the user's favorite marketplace listings.
class FavoritesState {
  const FavoritesState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.listings = const [],
    this.nextCursor,
    this.hasMore = false,
    this.errorMessage,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final List<MarketplaceListingEntity> listings;
  final String? nextCursor;
  final bool hasMore;
  final String? errorMessage;

  FavoritesState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    List<MarketplaceListingEntity>? listings,
    String? nextCursor,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return FavoritesState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      listings: listings ?? this.listings,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Provider for [FavoritesController].
final favoritesControllerProvider =
    StateNotifierProvider.autoDispose<FavoritesController, FavoritesState>(
        (ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return FavoritesController(repo);
});

/// Controller managing user's saved/favorited marketplace listings.
class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController(this._repository) : super(const FavoritesState()) {
    loadFavorites();
  }

  final MarketplaceRepository _repository;

  /// Load user favorites with optional pull-to-refresh.
  Future<void> loadFavorites({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
      clearCursor: refresh,
    );

    try {
      final page = await _repository.getFavorites(limit: 20);
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        listings: page.items,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage:
            'Unable to load favorites: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Load next page of favorites.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.getFavorites(
        cursor: state.nextCursor,
        limit: 20,
      );

      state = state.copyWith(
        isLoadingMore: false,
        listings: [...state.listings, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Remove a listing from favorites optimistically with rollback on failure.
  Future<void> unfavorite(String listingId) async {
    final originalListings = state.listings;
    final updatedListings =
        originalListings.where((l) => l.id != listingId).toList();

    state = state.copyWith(listings: updatedListings);

    try {
      await _repository.unfavoriteListing(listingId);
    } catch (e) {
      // Rollback on failure
      state = state.copyWith(
        listings: originalListings,
        errorMessage: 'Failed to remove from favorites.',
      );
    }
  }
}
