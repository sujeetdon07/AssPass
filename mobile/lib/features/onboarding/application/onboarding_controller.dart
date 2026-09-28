import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../data/repositories/onboarding_repository.dart';

class OnboardingFormState {
  const OnboardingFormState({
    this.displayName = '',
    this.username,
    this.selectedLocality,
    this.neighborhood = '',
    this.isLoading = false,
    this.errorMessage,
    this.completedUser,
  });

  final String displayName;
  final String? username;
  final LocalitySuggestion? selectedLocality;
  final String neighborhood;
  final bool isLoading;
  final String? errorMessage;
  final UserEntity? completedUser;

  OnboardingFormState copyWith({
    String? displayName,
    String? username,
    LocalitySuggestion? selectedLocality,
    String? neighborhood,
    bool? isLoading,
    String? errorMessage,
    UserEntity? completedUser,
  }) {
    return OnboardingFormState(
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      selectedLocality: selectedLocality ?? this.selectedLocality,
      neighborhood: neighborhood ?? this.neighborhood,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      completedUser: completedUser ?? this.completedUser,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingFormState> {
  OnboardingController({
    required OnboardingRepository onboardingRepository,
    required AuthController authController,
  })  : _onboardingRepository = onboardingRepository,
        _authController = authController,
        super(const OnboardingFormState());

  final OnboardingRepository _onboardingRepository;
  final AuthController _authController;

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  void setUsername(String? username) {
    state = state.copyWith(username: username);
  }

  void setLocality(LocalitySuggestion locality) {
    state = state.copyWith(selectedLocality: locality);
  }

  void setNeighborhood(String neighborhood) {
    state = state.copyWith(neighborhood: neighborhood);
  }

  /// Submit onboarding information to backend and mark onboarding completed.
  Future<UserEntity> submitOnboarding() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final updatedUser = await _onboardingRepository.completeOnboarding(
        displayName: state.displayName,
        username: state.username,
        countryCode: state.selectedLocality?.countryCode ?? 'IN',
        state: state.selectedLocality?.state,
        district: state.selectedLocality?.district,
        city: state.selectedLocality?.city,
        locality: state.selectedLocality?.locality,
        neighborhood: state.neighborhood.isNotEmpty ? state.neighborhood : null,
      );

      state = state.copyWith(isLoading: false, completedUser: updatedUser);

      // Update AuthController state to AuthAuthenticated(updatedUser)
      _authController.updateUser(updatedUser);

      return updatedUser;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }
}

/// Riverpod provider for [OnboardingController].
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingFormState>((ref) {
  final repository = ref.watch(onboardingRepositoryProvider);
  final authController = ref.watch(authControllerProvider.notifier);
  return OnboardingController(
    onboardingRepository: repository,
    authController: authController,
  );
});
