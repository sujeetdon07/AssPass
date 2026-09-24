import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aaspaas/features/nearby/application/location_controller.dart';
import 'package:aaspaas/features/nearby/domain/entities/location_state.dart';
import 'package:aaspaas/features/nearby/domain/services/location_service.dart';

class _FakeLocationService implements LocationService {
  bool serviceEnabled = true;
  LocationPermission permissionStatus = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.whileInUse;
  Position? mockPosition;
  bool throwOnGetPosition = false;
  bool openedAppSettings = false;
  bool openedLocationSettings = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permissionStatus;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position?> getCurrentPosition() async {
    if (throwOnGetPosition) {
      throw Exception('GPS Timeout');
    }
    return mockPosition;
  }

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings = true;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings = true;
    return true;
  }
}

Position _createMockPosition({
  double latitude = 12.9352,
  double longitude = 77.6245,
  double accuracy = 15.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 9, 22),
    accuracy: accuracy,
    altitude: 900.0,
    altitudeAccuracy: 5.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  group('LocationController', () {
    late _FakeLocationService fakeService;
    late LocationController controller;

    setUp(() {
      fakeService = _FakeLocationService();
      controller = LocationController(fakeService);
    });

    test('initial state is LocationInitial', () {
      expect(controller.state, isA<LocationInitial>());
    });

    test(
        'transitions to LocationServiceDisabled when location service is disabled',
        () async {
      fakeService.serviceEnabled = false;

      await controller.requestLocation();

      expect(controller.state, isA<LocationServiceDisabled>());
    });

    test('transitions to LocationPermissionDenied when user denies permission',
        () async {
      fakeService.serviceEnabled = true;
      fakeService.permissionStatus = LocationPermission.denied;
      fakeService.requestResult = LocationPermission.denied;

      await controller.requestLocation();

      expect(controller.state, isA<LocationPermissionDenied>());
    });

    test(
        'transitions to LocationPermissionPermanentlyDenied when denied forever',
        () async {
      fakeService.serviceEnabled = true;
      fakeService.permissionStatus = LocationPermission.deniedForever;

      await controller.requestLocation();

      expect(controller.state, isA<LocationPermissionPermanentlyDenied>());
    });

    test(
        'transitions to LocationReady when permission is granted and position is acquired',
        () async {
      fakeService.serviceEnabled = true;
      fakeService.permissionStatus = LocationPermission.denied;
      fakeService.requestResult = LocationPermission.whileInUse;
      fakeService.mockPosition =
          _createMockPosition(latitude: 12.9352, longitude: 77.6245);

      await controller.requestLocation();

      expect(controller.state, isA<LocationReady>());
      final readyState = controller.state as LocationReady;
      expect(readyState.latitude, 12.9352);
      expect(readyState.longitude, 77.6245);
      expect(readyState.isApproximate, isFalse);
    });

    test('detects approximate location when accuracy is > 100m', () async {
      fakeService.serviceEnabled = true;
      fakeService.permissionStatus = LocationPermission.always;
      fakeService.mockPosition = _createMockPosition(accuracy: 150.0);

      await controller.requestLocation();

      expect(controller.state, isA<LocationReady>());
      final readyState = controller.state as LocationReady;
      expect(readyState.isApproximate, isTrue);
    });

    test('transitions to LocationError if getCurrentPosition throws', () async {
      fakeService.serviceEnabled = true;
      fakeService.permissionStatus = LocationPermission.whileInUse;
      fakeService.throwOnGetPosition = true;

      await controller.requestLocation();

      expect(controller.state, isA<LocationError>());
      final errorState = controller.state as LocationError;
      expect(errorState.message, contains('GPS Timeout'));
    });

    test('manual locality sets LocationManualLocality without GPS permission',
        () {
      controller.setManualLocality(
        localityName: 'Indiranagar',
        cityName: 'Bengaluru',
        latitude: 12.9784,
        longitude: 77.6408,
      );

      expect(controller.state, isA<LocationManualLocality>());
      final manual = controller.state as LocationManualLocality;
      expect(manual.localityName, 'Indiranagar');
      expect(manual.cityName, 'Bengaluru');
      expect(manual.latitude, 12.9784);
      expect(manual.longitude, 77.6408);
      expect(manual.displayName, 'Indiranagar, Bengaluru');
    });

    test('openAppSettings and openLocationSettings delegate to service',
        () async {
      await controller.openAppSettings();
      expect(fakeService.openedAppSettings, isTrue);

      await controller.openLocationSettings();
      expect(fakeService.openedLocationSettings, isTrue);
    });

    test('reset() returns state to LocationInitial', () {
      controller.setManualLocality(
        localityName: 'Koramangala',
        cityName: 'Bengaluru',
        latitude: 12.9352,
        longitude: 77.6245,
      );
      expect(controller.state, isA<LocationManualLocality>());

      controller.reset();
      expect(controller.state, isA<LocationInitial>());
    });
  });
}
