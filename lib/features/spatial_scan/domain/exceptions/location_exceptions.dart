/// Domain-level location failures. Kept free of any geolocator import so
/// presentation code can catch/display these without depending on a
/// third-party package — [LocationDataSource] is responsible for mapping
/// geolocator's own exceptions/enum states onto these.
sealed class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
}

class LocationServiceDisabledException extends LocationException {
  const LocationServiceDisabledException()
      : super('Location services are turned off for this device.');
}

class LocationPermissionDeniedException extends LocationException {
  const LocationPermissionDeniedException({this.isPermanent = false})
      : super(
          isPermanent
              ? 'Location permission is permanently denied. Enable it from '
                  'system settings to unlock nearby signals.'
              : 'Location permission was denied.',
        );

  /// True when the platform will no longer show the permission prompt
  /// (Android "deny forever" / iOS after repeated denials) — the UI should
  /// direct the user to app settings rather than re-requesting.
  final bool isPermanent;
}
