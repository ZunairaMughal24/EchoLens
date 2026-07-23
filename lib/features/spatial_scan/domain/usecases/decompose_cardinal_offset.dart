import 'dart:math';

import '../entities/cardinal_offset.dart';

/// Splits a straight-line distance + absolute bearing into north/south and
/// east/west components. Pure trig, no dependencies — the bearing is
/// measured clockwise from true north (0 = N, 90 = E, 180 = S, 270 = W), the
/// same convention [BearingCalculator] returns.
class DecomposeCardinalOffset {
  const DecomposeCardinalOffset();

  CardinalOffset call({
    required double distanceMeters,
    required double absoluteBearingDegrees,
  }) {
    final radians = absoluteBearingDegrees * (pi / 180);
    final northMeters = distanceMeters * cos(radians);
    final eastMeters = distanceMeters * sin(radians);
    return CardinalOffset(
      northSouthMeters: northMeters.abs(),
      isNorth: northMeters >= 0,
      eastWestMeters: eastMeters.abs(),
      isEast: eastMeters >= 0,
    );
  }
}
