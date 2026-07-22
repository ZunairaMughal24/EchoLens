import '../entities/user_location.dart';

/// Source of the user's live device position. Implementations own permission
/// handling and emit a [LocationException] (see location_exceptions.dart) on
/// the stream's error channel rather than throwing synchronously, so the
/// ViewModel can react the same way it reacts to any other stream error.
abstract interface class LocationRepository {
  Stream<UserLocation> watchPosition();

  /// A single current fix — used by the planting flow, which needs "where
  /// am I right now" rather than a continuous stream.
  Future<UserLocation> getCurrentPosition();

  /// Deep-links to the OS's location services toggle (service disabled).
  Future<void> openLocationSettings();

  /// Deep-links to this app's own permission page (permission denied).
  Future<void> openAppSettings();
}
