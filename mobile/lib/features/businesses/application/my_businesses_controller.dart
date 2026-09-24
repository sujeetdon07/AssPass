import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/businesses_repository.dart';
import '../domain/entities/business_entity.dart';

class MyBusinessesState {
  const MyBusinessesState({
    this.isLoading = false,
    this.businesses = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  final bool isLoading;
  final List<BusinessEntity> businesses;
  final BusinessStatus? selectedStatus;
  final String? errorMessage;

  MyBusinessesState copyWith({
    bool? isLoading,
    List<BusinessEntity>? businesses,
    BusinessStatus? selectedStatus,
    bool clearStatus = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyBusinessesState(
      isLoading: isLoading ?? this.isLoading,
      businesses: businesses ?? this.businesses,
      selectedStatus:
          clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final myBusinessesControllerProvider = StateNotifierProvider.autoDispose<
    MyBusinessesController, MyBusinessesState>((ref) {
  final repo = ref.watch(businessesRepositoryProvider);
  return MyBusinessesController(repo);
});

class MyBusinessesController extends StateNotifier<MyBusinessesState> {
  MyBusinessesController(this._repository) : super(const MyBusinessesState()) {
    loadMyBusinesses();
  }

  final BusinessesRepository _repository;

  Future<void> loadMyBusinesses({BusinessStatus? status}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedStatus: status,
    );

    try {
      final page = await _repository.getMyBusinesses(
        status: status,
        limit: 50,
      );

      state = state.copyWith(isLoading: false, businesses: page.items);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Unable to load your businesses: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  Future<void> filterByStatus(BusinessStatus? status) async {
    await loadMyBusinesses(status: status);
  }
}
