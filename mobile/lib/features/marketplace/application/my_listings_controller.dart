import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/marketplace_repository.dart';
import '../domain/entities/marketplace_listing_entity.dart';
import '../domain/entities/marketplace_status.dart';

class MyListingsState {
  const MyListingsState({
    this.isLoading = false,
    this.listings = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  final bool isLoading;
  final List<MarketplaceListingEntity> listings;
  final MarketplaceListingStatus? selectedStatus;
  final String? errorMessage;

  MyListingsState copyWith({
    bool? isLoading,
    List<MarketplaceListingEntity>? listings,
    MarketplaceListingStatus? selectedStatus,
    bool clearStatus = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyListingsState(
      isLoading: isLoading ?? this.isLoading,
      listings: listings ?? this.listings,
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final myListingsControllerProvider =
    StateNotifierProvider.autoDispose<MyListingsController, MyListingsState>(
        (ref) {
  final repo = ref.watch(marketplaceRepositoryProvider);
  return MyListingsController(repo);
});

class MyListingsController extends StateNotifier<MyListingsState> {
  MyListingsController(this._repository) : super(const MyListingsState()) {
    loadMyListings();
  }

  final MarketplaceRepository _repository;

  Future<void> loadMyListings({MarketplaceListingStatus? status}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedStatus: status,
    );

    try {
      final page = await _repository.getMyListings(
        status: status?.value,
        limit: 50,
      );

      state = state.copyWith(isLoading: false, listings: page.items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Unable to load your listings: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  Future<void> filterByStatus(MarketplaceListingStatus? status) async {
    await loadMyListings(status: status);
  }
}
