import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/services_repository.dart';
import '../domain/entities/service_category.dart';
import '../domain/entities/service_listing_entity.dart';

class MyServicesState {
  const MyServicesState({
    this.isLoading = false,
    this.services = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  final bool isLoading;
  final List<ServiceListingEntity> services;
  final ServiceStatus? selectedStatus;
  final String? errorMessage;

  MyServicesState copyWith({
    bool? isLoading,
    List<ServiceListingEntity>? services,
    ServiceStatus? selectedStatus,
    bool clearStatus = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyServicesState(
      isLoading: isLoading ?? this.isLoading,
      services: services ?? this.services,
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final myServicesControllerProvider =
    StateNotifierProvider.autoDispose<MyServicesController, MyServicesState>(
        (ref) {
  final repo = ref.watch(servicesRepositoryProvider);
  return MyServicesController(repo);
});

class MyServicesController extends StateNotifier<MyServicesState> {
  MyServicesController(this._repository) : super(const MyServicesState()) {
    loadMyServices();
  }

  final ServicesRepository _repository;

  Future<void> loadMyServices({ServiceStatus? status}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedStatus: status,
    );

    try {
      final page = await _repository.getMyServices(
        status: status,
        limit: 50,
      );

      state = state.copyWith(isLoading: false, services: page.items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Unable to load your services: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  Future<void> filterByStatus(ServiceStatus? status) async {
    await loadMyServices(status: status);
  }
}
