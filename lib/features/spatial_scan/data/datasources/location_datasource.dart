import 'package:geolocator/geolocator.dart';

// Prefixed: geolocator_platform_interface also exports a
// LocationServiceDisabledException, which collides with our own domain
// exception of the same name.
import '../../domain/exceptions/location_exceptions.dart' as domain;

abstract interface class LocationDataSource {
  Stream<Position> watchPosition();
  Future<Position> getCurrentPosition();
  Future<void> openLocationSettings();
  Future<void> openAppSettings();
}

/// Wraps `package:geolocator`: initializes permissions cleanly before ever
/// touching the device GPS, then bridges to a live position stream. Any
/// permission/service failure is thrown as a domain [LocationException]
/// rather than a raw geolocator/platform exception, so nothing above the
/// data layer needs to know this package exists.
class GeolocatorLocationDataSource implements LocationDataSource {
  const GeolocatorLocationDataSource();

  // 1m filter matches the granularity we actually care about — the 5m
  // signal-unlock radius — without flooding the stream on every GPS jitter.
  static const _settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 1,
  );

  @override
  Stream<Position> watchPosition() async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(locationSettings: _settings);
  }

  @override
  Future<Position> getCurrentPosition() async {
    await _ensurePermission();
    return Geolocator.getCurrentPosition(locationSettings: _settings);
  }

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const domain.LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const domain.LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const domain.LocationPermissionDeniedException(isPermanent: true);
    }
  }
}
