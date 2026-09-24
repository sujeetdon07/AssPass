/// Represents the strongly-typed lifecycle of device location acquisition
/// and manual locality fallback for Nearby discovery.
sealed class LocationState {
  const LocationState();
}

/// Initial state explaining why location is requested.
class LocationInitial extends LocationState {
  const LocationInitial();
}

/// A request for permission is in progress.
class LocationRequestingPermission extends LocationState {
  const LocationRequestingPermission();
}

/// Permission was denied by the user.
class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}

/// Permission was permanently denied (user must open settings).
class LocationPermissionPermanentlyDenied extends LocationState {
  const LocationPermissionPermanentlyDenied();
}

/// Device location services (GPS) are disabled.
class LocationServiceDisabled extends LocationState {
  const LocationServiceDisabled();
}

/// Coordinates are actively being acquired from the device.
class LocationAcquiring extends LocationState {
  const LocationAcquiring();
}

/// Device coordinates acquired successfully.
class LocationReady extends LocationState {
  const LocationReady({
    required this.latitude,
    required this.longitude,
    this.isApproximate = false,
  });

  final double latitude;
  final double longitude;
  final bool isApproximate;
}

/// User chose a manual locality fallback instead of device GPS.
class LocationManualLocality extends LocationState {
  const LocationManualLocality({
    required this.localityName,
    required this.cityName,
    required this.latitude,
    required this.longitude,
  });

  final String localityName;
  final String cityName;
  final double latitude;
  final double longitude;

  String get displayName => '$localityName, $cityName';
}

/// An error occurred during location acquisition.
class LocationError extends LocationState {
  const LocationError(this.message);

  final String message;
}
