import 'package:geolocator/geolocator.dart';

import '../../domain/entities/user_location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._dataSource);

  final LocationDataSource _dataSource;

  @override
  Stream<UserLocation> watchPosition() {
    return _dataSource.watchPosition().map(_toUserLocation);
  }

  @override
  Future<UserLocation> getCurrentPosition() async {
    return _toUserLocation(await _dataSource.getCurrentPosition());
  }

  UserLocation _toUserLocation(Position position) => UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
}
