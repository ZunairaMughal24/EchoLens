import '../entities/user_location.dart';
import '../repositories/location_repository.dart';

/// Fetches a single current GPS fix — for "capture where I am right now"
/// moments (planting a signal), as opposed to [WatchUserLocation]'s
/// continuous stream.
class GetCurrentUserLocation {
  const GetCurrentUserLocation(this._repository);

  final LocationRepository _repository;

  Future<UserLocation> call() => _repository.getCurrentPosition();
}
