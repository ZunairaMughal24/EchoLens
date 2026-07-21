import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

/// Streams the user's live GPS position.
class WatchUserLocation {
  const WatchUserLocation(this._repository);

  final LocationRepository _repository;

  Stream<UserLocation> call() => _repository.watchPosition();
}
