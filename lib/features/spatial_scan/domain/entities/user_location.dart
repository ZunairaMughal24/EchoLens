/// The user's live real-world position. A domain-owned value object so
/// upper layers never depend on `package:geolocator`'s `Position` type —
/// only [LocationRepositoryImpl] (data layer) knows that type exists.
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy of the fix, in meters, if the platform reports it.
  final double? accuracyMeters;
}
