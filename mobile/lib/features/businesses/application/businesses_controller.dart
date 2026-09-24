import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/businesses_repository.dart';
import '../domain/entities/business_category.dart';
import '../domain/entities/business_entity.dart';
import '../domain/entities/business_filter.dart';
import '../../nearby/application/location_controller.dart';
import '../../nearby/domain/entities/location_state.dart';

class BusinessesState {
  const BusinessesState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.businesses = const [],
    this.filter = const BusinessFilter(),
    this.errorMessage,
    this.nextCursor,
    this.hasMore = false,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final List<BusinessEntity> businesses;
  final BusinessFilter filter;
  final String? errorMessage;
  final String? nextCursor;
  final bool hasMore;

  BusinessesState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    List<BusinessEntity>? businesses,
    BusinessFilter? filter,
    String? errorMessage,
    bool clearError = false,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
  }) {
    return BusinessesState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      businesses: businesses ?? this.businesses,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final businessesControllerProvider =
    StateNotifierProvider<BusinessesController, BusinessesState>((ref) {
  final repository = ref.watch(businessesRepositoryProvider);
  return BusinessesController(repository, ref);
});

class BusinessesController extends StateNotifier<BusinessesState> {
  BusinessesController(this._repository, this._ref)
      : super(const BusinessesState()) {
    loadBusinesses();
  }

  final BusinessesRepository _repository;
  final Ref _ref;

  Future<void> loadBusinesses({bool isRefresh = false}) async {
    if (state.isLoading || state.isRefreshing) return;

    if (isRefresh) {
      state = state.copyWith(isRefreshing: true, clearError: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      double? lat;
      double? lng;
      final locState = _ref.read(locationControllerProvider);
      if (locState is LocationReady) {
        lat = locState.latitude;
        lng = locState.longitude;
      } else if (locState is LocationManualLocality) {
        lat = locState.latitude;
        lng = locState.longitude;
      }

      final page = await _repository.getBusinesses(
        query: state.filter.searchQuery,
        category: state.filter.category,
        locality: state.filter.locality,
        radius: state.filter.radiusKm,
        openNow: state.filter.openNow,
        sortBy: state.filter.sortBy,
        latitude: lat,
        longitude: lng,
        limit: 20,
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        businesses: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Failed to load businesses. Tap to retry.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      double? lat;
      double? lng;
      final locState = _ref.read(locationControllerProvider);
      if (locState is LocationReady) {
        lat = locState.latitude;
        lng = locState.longitude;
      } else if (locState is LocationManualLocality) {
        lat = locState.latitude;
        lng = locState.longitude;
      }

      final page = await _repository.getBusinesses(
        query: state.filter.searchQuery,
        category: state.filter.category,
        locality: state.filter.locality,
        radius: state.filter.radiusKm,
        openNow: state.filter.openNow,
        sortBy: state.filter.sortBy,
        latitude: lat,
        longitude: lng,
        cursor: state.nextCursor,
        limit: 20,
      );

      final combined = [...state.businesses, ...page.items];
      state = state.copyWith(
        isLoadingMore: false,
        businesses: combined,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setSearchQuery(String? query) {
    final updatedFilter = state.filter.copyWith(
      searchQuery: query,
      clearSearch: query == null || query.trim().isEmpty,
    );
    state = state.copyWith(filter: updatedFilter);
    loadBusinesses(isRefresh: true);
  }

  void setCategory(BusinessCategory? category) {
    final updatedFilter = state.filter.copyWith(
      category: category,
      clearCategory: category == null,
    );
    state = state.copyWith(filter: updatedFilter);
    loadBusinesses(isRefresh: true);
  }

  void setFilter(BusinessFilter filter) {
    state = state.copyWith(filter: filter);
    loadBusinesses(isRefresh: true);
  }

  Future<void> toggleFavorite(String businessId) async {
    final index = state.businesses.indexWhere((b) => b.id == businessId);
    if (index == -1) return;

    final current = state.businesses[index];
    final targetFav = !current.isFavorited;
    final targetCount =
        targetFav ? current.favoriteCount + 1 : current.favoriteCount - 1;

    final updated = BusinessEntity(
      id: current.id,
      ownerId: current.ownerId,
      owner: current.owner,
      name: current.name,
      slug: current.slug,
      description: current.description,
      category: current.category,
      status: current.status,
      verificationStatus: current.verificationStatus,
      countryCode: current.countryCode,
      state: current.state,
      district: current.district,
      city: current.city,
      locality: current.locality,
      neighborhood: current.neighborhood,
      address: current.address,
      contactPhone: current.contactPhone,
      contactEmail: current.contactEmail,
      website: current.website,
      timezone: current.timezone,
      operatingHours: current.operatingHours,
      operatingStatus: current.operatingStatus,
      favoriteCount: targetCount < 0 ? 0 : targetCount,
      isFavorited: targetFav,
      isOwner: current.isOwner,
      images: current.images,
      services: current.services,
      distance: current.distance,
      distanceMeters: current.distanceMeters,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );

    final updatedList = List<BusinessEntity>.from(state.businesses);
    updatedList[index] = updated;
    state = state.copyWith(businesses: updatedList);

    try {
      await _repository.toggleFavorite(businessId, targetFav);
    } catch (_) {
      // Revert on failure
      final revertedList = List<BusinessEntity>.from(state.businesses);
      revertedList[index] = current;
      state = state.copyWith(businesses: revertedList);
    }
  }

  void removeBusiness(String businessId) {
    final updated = state.businesses.where((b) => b.id != businessId).toList();
    state = state.copyWith(businesses: updated);
  }

  void updateBusinessInList(BusinessEntity business) {
    final index = state.businesses.indexWhere((b) => b.id == business.id);
    if (index != -1) {
      final updatedList = List<BusinessEntity>.from(state.businesses);
      updatedList[index] = business;
      state = state.copyWith(businesses: updatedList);
    }
  }
}
