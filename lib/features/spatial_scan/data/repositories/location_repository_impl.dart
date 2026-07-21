import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._dataSource);

  final LocationDataSource _dataSource;

  @override
  Stream<UserLocation> watchPosition() {
    return _dataSource.watchPosition().map(
          (position) => UserLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy,
          ),
        );
  }
}
