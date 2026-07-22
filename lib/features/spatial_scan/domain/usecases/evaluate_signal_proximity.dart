import '../entities/echo_node.dart';
import '../entities/user_location.dart';
import '../services/distance_calculator.dart';

/// Business rule: a geo-anchored [EchoNode] unlocks once the user is within
/// [unlockRadiusMeters] of it. Pure — takes the current node list and the
/// latest user fix, returns a new node list with `isLocked`/`distanceMeters`
/// recomputed. Nodes without coordinates pass through untouched.
///
/// Also drives the radar's *visual* proximity: [EchoNode.distance] (radial
/// placement) and [EchoNode.depth] (parallax scale) are overridden for
/// geo-anchored nodes so the card actually glides toward the center and
/// grows as the user physically approaches — otherwise those fields stay
/// tied to the ambient mock drift, which has nothing to do with real GPS
/// distance and gives no visual feedback for "getting closer."
class EvaluateSignalProximity {
  const EvaluateSignalProximity(this._distanceCalculator);

  final DistanceCalculator _distanceCalculator;

  static const unlockRadiusMeters = 5.0;

  /// Real-world distance, in meters, a geo-anchored node maps to the
  /// radar's outer edge. Closer than this and it visibly moves inward;
  /// farther than this it just sits at the edge (still shows the live
  /// meter count in the card, it simply stops moving further out).
  static const visualRangeMeters = 60.0;

  List<EchoNode> call(List<EchoNode> nodes, UserLocation? userLocation) {
    if (userLocation == null) return nodes;

    return [
      for (final node in nodes)
        if (node.isGeoAnchored) _withProximity(node, userLocation) else node,
    ];
  }

  EchoNode _withProximity(EchoNode node, UserLocation userLocation) {
    final meters = _distanceCalculator.metersBetween(
      userLocation.latitude,
      userLocation.longitude,
      node.latitude!,
      node.longitude!,
    );
    final proximityFraction = (meters / visualRangeMeters).clamp(0.0, 1.0);
    return node.copyWith(
      distanceMeters: meters,
      isLocked: meters > unlockRadiusMeters,
      // Small floor (0.08) rather than 0 so it never sits exactly under
      // the core's glow and disappears visually.
      distance: 0.08 + proximityFraction * 0.92,
      depth: 1.0 - proximityFraction,
    );
  }
}
