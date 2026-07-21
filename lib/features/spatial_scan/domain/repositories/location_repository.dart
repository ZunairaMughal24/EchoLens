import '../entities/user_location.dart';

/// Source of the user's live device position. Implementations own permission
/// handling and emit a [LocationException] (see location_exceptions.dart) on
/// the stream's error channel rather than throwing synchronously, so the
/// ViewModel can react the same way it reacts to any other stream error.
abstract interface class LocationRepository {
  Stream<UserLocation> watchPosition();
}
