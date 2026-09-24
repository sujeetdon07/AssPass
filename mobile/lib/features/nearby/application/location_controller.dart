import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/entities/location_state.dart';
import '../domain/services/location_service.dart';

/// Provider for [LocationController] managing device location permissions and state.
final locationControllerProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
  final service = ref.watch(locationServiceProvider);
  return LocationController(service);
});

class LocationController extends StateNotifier<LocationState> {
  LocationController(this._locationService) : super(const LocationInitial());

  final LocationService _locationService;

  /// Initiate device location acquisition flow with permission and service checks.
  Future<void> requestLocation() async {
    state = const LocationRequestingPermission();

    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const LocationServiceDisabled();
        return;
      }

      var permission = await _locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
        if (permission == LocationPermission.denied) {
          state = const LocationPermissionDenied();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = const LocationPermissionPermanentlyDenied();
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        state = const LocationAcquiring();

        final position = await _locationService.getCurrentPosition();
        if (position != null) {
          state = LocationReady(
            latitude: position.latitude,
            longitude: position.longitude,
            isApproximate: position.accuracy > 100,
          );
        } else {
          state = const LocationError(
            'Unable to acquire current location fix. Please try again or select a locality.',
          );
        }
      }
    } catch (e) {
      state = LocationError(
        'Location check failed: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Manually select a locality as discovery center without granting device GPS.
  void setManualLocality({
    required String localityName,
    required String cityName,
    required double latitude,
    required double longitude,
  }) {
    state = LocationManualLocality(
      localityName: localityName,
      cityName: cityName,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Open application settings if permission was permanently denied.
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// Open device location services settings if disabled.
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Reset state to initial explanatory prompt.
  void reset() {
    state = const LocationInitial();
  }
}
