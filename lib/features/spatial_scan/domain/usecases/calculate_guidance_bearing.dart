import '../entities/user_location.dart';
import '../services/bearing_calculator.dart';

/// Business rule for the tap-to-guide feature: how far off the device's
/// current facing direction a target echo currently is, in degrees clockwise
/// (0 = straight ahead, 90 = to the right, 270 = to the left). Presentation
/// rotates a directional arrow by this value — it never touches bearing trig
/// itself.
class CalculateGuidanceBearing {
  const CalculateGuidanceBearing(this._bearingCalculator);

  final BearingCalculator _bearingCalculator;

  double call({
    required UserLocation from,
    required double headingDegrees,
    required double targetLatitude,
    required double targetLongitude,
  }) {
    final targetBearing = _bearingCalculator.bearingBetween(
      from.latitude,
      from.longitude,
      targetLatitude,
      targetLongitude,
    );
    return _normalize(targetBearing - headingDegrees);
  }

  double _normalize(double degrees) => ((degrees % 360) + 360) % 360;
}
