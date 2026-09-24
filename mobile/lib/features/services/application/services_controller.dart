import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/services_repository.dart';
import '../domain/entities/service_category.dart';
import '../domain/entities/service_filter.dart';
import '../domain/entities/service_listing_entity.dart';
import '../../nearby/application/location_controller.dart';
import '../../nearby/domain/entities/location_state.dart';

class ServicesState {
  const ServicesState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.services = const [],
    this.filter = const ServiceFilter(),
    this.errorMessage,
    this.nextCursor,
    this.hasMore = false,
  });

  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final List<ServiceListingEntity> services;
  final ServiceFilter filter;
  final String? errorMessage;
  final String? nextCursor;
  final bool hasMore;

  ServicesState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    List<ServiceListingEntity>? services,
    ServiceFilter? filter,
    String? errorMessage,
    bool clearError = false,
    String? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
  }) {
    return ServicesState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      services: services ?? this.services,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final servicesControllerProvider =
    StateNotifierProvider<ServicesController, ServicesState>((ref) {
  final repository = ref.watch(servicesRepositoryProvider);
  return ServicesController(repository, ref);
});

class ServicesController extends StateNotifier<ServicesState> {
  ServicesController(this._repository, this._ref)
      : super(const ServicesState()) {
    loadServices();
  }

  final ServicesRepository _repository;
  final Ref _ref;

  Future<void> loadServices({bool isRefresh = false}) async {
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

      final page = await _repository.getServices(
        query: state.filter.searchQuery,
        category: state.filter.category,
        pricingModel: state.filter.pricingModel,
        locality: state.filter.locality,
        radius: state.filter.radiusKm,
        sortBy: state.filter.sortBy,
        latitude: lat,
        longitude: lng,
        limit: 20,
      );

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        services: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Failed to load services. Tap to retry.',
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

      final page = await _repository.getServices(
        query: state.filter.searchQuery,
        category: state.filter.category,
        pricingModel: state.filter.pricingModel,
        locality: state.filter.locality,
        radius: state.filter.radiusKm,
        sortBy: state.filter.sortBy,
        latitude: lat,
        longitude: lng,
        cursor: state.nextCursor,
        limit: 20,
      );

      final combined = [...state.services, ...page.items];
      state = state.copyWith(
        isLoadingMore: false,
        services: combined,
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
    loadServices(isRefresh: true);
  }

  void setCategory(ServiceCategory? category) {
    final updatedFilter = state.filter.copyWith(
      category: category,
      clearCategory: category == null,
    );
    state = state.copyWith(filter: updatedFilter);
    loadServices(isRefresh: true);
  }

  void setPricingModel(PricingModel? pricingModel) {
    final updatedFilter = state.filter.copyWith(
      pricingModel: pricingModel,
      clearPricing: pricingModel == null,
    );
    state = state.copyWith(filter: updatedFilter);
    loadServices(isRefresh: true);
  }

  void setFilter(ServiceFilter filter) {
    state = state.copyWith(filter: filter);
    loadServices(isRefresh: true);
  }

  Future<void> toggleFavorite(String serviceId) async {
    final index = state.services.indexWhere((s) => s.id == serviceId);
    if (index == -1) return;

    final current = state.services[index];
    final targetFav = !current.isFavorited;
    final targetCount =
        targetFav ? current.favoriteCount + 1 : current.favoriteCount - 1;

    final updated = ServiceListingEntity(
      id: current.id,
      providerId: current.providerId,
      provider: current.provider,
      businessId: current.businessId,
      businessName: current.businessName,
      title: current.title,
      description: current.description,
      category: current.category,
      pricingModel: current.pricingModel,
      startingPrice: current.startingPrice,
      currency: current.currency,
      experienceYears: current.experienceYears,
      status: current.status,
      countryCode: current.countryCode,
      state: current.state,
      district: current.district,
      city: current.city,
      locality: current.locality,
      neighborhood: current.neighborhood,
      contactPhone: current.contactPhone,
      contactEmail: current.contactEmail,
      contactWhatsapp: current.contactWhatsapp,
      serviceRadiusKm: current.serviceRadiusKm,
      serviceAreaDescription: current.serviceAreaDescription,
      favoriteCount: targetCount < 0 ? 0 : targetCount,
      isFavorited: targetFav,
      isProvider: current.isProvider,
      distance: current.distance,
      distanceMeters: current.distanceMeters,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );

    final updatedList = List<ServiceListingEntity>.from(state.services);
    updatedList[index] = updated;
    state = state.copyWith(services: updatedList);

    try {
      await _repository.toggleFavorite(serviceId, targetFav);
    } catch (_) {
      // Revert on failure
      final revertedList = List<ServiceListingEntity>.from(state.services);
      revertedList[index] = current;
      state = state.copyWith(services: revertedList);
    }
  }

  void removeService(String serviceId) {
    final updated = state.services.where((s) => s.id != serviceId).toList();
    state = state.copyWith(services: updated);
  }

  void updateServiceInList(ServiceListingEntity service) {
    final index = state.services.indexWhere((s) => s.id == service.id);
    if (index != -1) {
      final updatedList = List<ServiceListingEntity>.from(state.services);
      updatedList[index] = service;
      state = state.copyWith(services: updatedList);
    }
  }
}
