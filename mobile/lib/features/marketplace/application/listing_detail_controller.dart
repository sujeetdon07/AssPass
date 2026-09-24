import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/marketplace_repository.dart';
import '../domain/entities/marketplace_listing_entity.dart';
import '../domain/entities/marketplace_status.dart';

class ListingDetailState {
  const ListingDetailState({
    this.isLoading = false,
    this.isUpdatingStatus = false,
    this.isDeleting = false,
    this.listing,
    this.errorMessage,
    this.isDeleted = false,
  });

  final bool isLoading;
  final bool isUpdatingStatus;
  final bool isDeleting;
  final MarketplaceListingEntity? listing;
  final String? errorMessage;
  final bool isDeleted;

  ListingDetailState copyWith({
    bool? isLoading,
    bool? isUpdatingStatus,
    bool? isDeleting,
    MarketplaceListingEntity? listing,
    String? errorMessage,
    bool clearError = false,
    bool? isDeleted,
  }) {
    return ListingDetailState(
      isLoading: isLoading ?? this.isLoading,
      isUpdatingStatus: isUpdatingStatus ?? this.isUpdatingStatus,
      isDeleting: isDeleting ?? this.isDeleting,
      listing: listing ?? this.listing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// Family provider for [ListingDetailController] by listing ID.
final listingDetailControllerProvider = StateNotifierProvider.autoDispose
    .family<ListingDetailController, ListingDetailState, String>((ref, id) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return ListingDetailController(repo, id);
});

class ListingDetailController extends StateNotifier<ListingDetailState> {
  ListingDetailController(this._repository, this._listingId)
      : super(const ListingDetailState()) {
    loadListing();
  }

  final MarketplaceRepository _repository;
  final String _listingId;

  /// Load listing detail from backend.
  Future<void> loadListing() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final listing = await _repository.getListingById(_listingId);
      state = state.copyWith(isLoading: false, listing: listing);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Unable to load listing: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Toggle favorite on this listing.
  Future<void> toggleFavorite() async {
    final current = state.listing;
    if (current == null) return;

    final targetFavorited = !current.isFavorited;
    final updated = current.copyWith(
      isFavorited: targetFavorited,
      favoriteCount: targetFavorited
          ? current.favoriteCount + 1
          : (current.favoriteCount > 0 ? current.favoriteCount - 1 : 0),
    );

    state = state.copyWith(listing: updated);

    try {
      if (targetFavorited) {
        await _repository.favoriteListing(_listingId);
      } else {
        await _repository.unfavoriteListing(_listingId);
      }
    } catch (_) {
      // Revert on failure
      state = state.copyWith(listing: current);
    }
  }

  /// Update listing lifecycle status (active, sold, archived).
  Future<bool> updateStatus(MarketplaceListingStatus status) async {
    state = state.copyWith(isUpdatingStatus: true, clearError: true);

    try {
      final updated =
          await _repository.updateListingStatus(_listingId, status.value);
      state = state.copyWith(isUpdatingStatus: false, listing: updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUpdatingStatus: false,
        errorMessage:
            'Failed to update listing status: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
      return false;
    }
  }

  /// Soft delete own listing.
  Future<bool> deleteListing() async {
    state = state.copyWith(isDeleting: true, clearError: true);

    try {
      await _repository.deleteListing(_listingId);
      state = state.copyWith(isDeleting: false, isDeleted: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage:
            'Failed to delete listing: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
      return false;
    }
  }

  /// Report this listing.
  Future<bool> reportListing({
    required String reason,
    String? details,
  }) async {
    try {
      await _repository.reportListing(
        _listingId,
        reason: reason,
        details: details,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage:
            'Failed to submit report: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
      return false;
    }
  }
}
