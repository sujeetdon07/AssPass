import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/marketplace_repository.dart';
import '../domain/entities/marketplace_category.dart';
import '../domain/entities/marketplace_filter.dart';
import 'marketplace_state.dart';

/// Provider for [MarketplaceController].
final marketplaceControllerProvider =
    StateNotifierProvider<MarketplaceController, MarketplaceState>((ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return MarketplaceController(repo);
});

class MarketplaceController extends StateNotifier<MarketplaceState> {
  MarketplaceController(this._repository) : super(const MarketplaceState());

  final MarketplaceRepository _repository;

  /// Load marketplace listings with active filters and optional coordinates.
  Future<void> loadListings({
    bool refresh = false,
    double? latitude,
    double? longitude,
  }) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(
      isLoading: !refresh,
      isRefreshing: refresh,
      clearError: true,
      clearCursor: refresh,
    );

    try {
      final page = await _repository.getListings(
        query: state.filter.query,
        category: state.filter.category?.value,
        condition: state.filter.condition?.value,
        minPrice: state.filter.minPrice,
        maxPrice: state.filter.maxPrice,
        locality: state.filter.locality,
        city: state.filter.city,
        radius: state.filter.radiusKm,
        latitude: latitude,
        longitude: longitude,
        sortBy: state.filter.sortBy,
        limit: 20,
      );

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
            'Unable to load marketplace listings: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Load the next page of marketplace listings using cursor pagination.
  Future<void> loadMore({
    double? latitude,
    double? longitude,
  }) async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.getListings(
        query: state.filter.query,
        category: state.filter.category?.value,
        condition: state.filter.condition?.value,
        minPrice: state.filter.minPrice,
        maxPrice: state.filter.maxPrice,
        locality: state.filter.locality,
        city: state.filter.city,
        radius: state.filter.radiusKm,
        latitude: latitude,
        longitude: longitude,
        sortBy: state.filter.sortBy,
        cursor: state.nextCursor,
        limit: 20,
      );

      state = state.copyWith(
        isLoadingMore: false,
        listings: [...state.listings, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Update search query and reload.
  Future<void> setSearchQuery(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(
      filter: state.filter
          .copyWith(query: query.trim().isEmpty ? null : query.trim()),
    );
    await loadListings(refresh: true, latitude: latitude, longitude: longitude);
  }

  /// Update category filter and reload.
  Future<void> setCategory(
    MarketplaceCategory? category, {
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(
      filter: state.filter.copyWith(
        category: category,
        clearCategory: category == null,
      ),
    );
    await loadListings(refresh: true, latitude: latitude, longitude: longitude);
  }

  /// Apply comprehensive filter object and reload.
  Future<void> setFilter(
    MarketplaceFilter filter, {
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(filter: filter);
    await loadListings(refresh: true, latitude: latitude, longitude: longitude);
  }

  /// Toggle favorite on a listing with optimistic UI update and error rollback.
  Future<void> toggleFavorite(String listingId) async {
    final originalListings = state.listings;
    final index = originalListings.indexWhere((l) => l.id == listingId);
    if (index == -1) return;

    final current = originalListings[index];
    final targetFavorited = !current.isFavorited;
    final updatedListings = List.of(originalListings);
    updatedListings[index] = current.copyWith(
      isFavorited: targetFavorited,
      favoriteCount: targetFavorited
          ? current.favoriteCount + 1
          : (current.favoriteCount > 0 ? current.favoriteCount - 1 : 0),
    );

    state = state.copyWith(listings: updatedListings);

    try {
      if (targetFavorited) {
        await _repository.favoriteListing(listingId);
      } else {
        await _repository.unfavoriteListing(listingId);
      }
    } catch (_) {
      // Rollback optimistic update on failure
      state = state.copyWith(listings: originalListings);
    }
  }
}
