import 'package:geolocator/geolocator.dart';

import '../../domain/services/distance_calculator.dart';

class GeolocatorDistanceCalculator implements DistanceCalculator {
  const GeolocatorDistanceCalculator();

  @override
  double metersBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
