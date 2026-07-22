import 'package:geolocator/geolocator.dart';

import '../../domain/services/bearing_calculator.dart';

class GeolocatorBearingCalculator implements BearingCalculator {
  const GeolocatorBearingCalculator();

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    final bearing = Geolocator.bearingBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    // Geolocator returns -180..180; normalize to the 0..360 clockwise-from-
    // north range the rest of the guidance math expects.
    return (bearing + 360) % 360;
  }
}
