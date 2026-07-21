import '../entities/echo_node.dart';
import '../entities/user_location.dart';
import '../services/distance_calculator.dart';

/// Business rule: a geo-anchored [EchoNode] unlocks once the user is within
/// [unlockRadiusMeters] of it. Pure — takes the current node list and the
/// latest user fix, returns a new node list with `isLocked`/`distanceMeters`
/// recomputed. Nodes without coordinates pass through untouched.
class EvaluateSignalProximity {
  const EvaluateSignalProximity(this._distanceCalculator);

  final DistanceCalculator _distanceCalculator;

  static const unlockRadiusMeters = 5.0;

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
    return node.copyWith(
      distanceMeters: meters,
      isLocked: meters > unlockRadiusMeters,
    );
  }
}
