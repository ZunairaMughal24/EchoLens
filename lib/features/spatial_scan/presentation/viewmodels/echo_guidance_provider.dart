import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';
import '../../domain/entities/echo_node.dart';
import 'spatial_scan_viewmodel.dart';

/// Live guidance toward one specific geo-anchored node: how far off the
/// device's current facing direction the target currently is, plus the live
/// distance. Purely derived from data already being kept live elsewhere —
/// [SpatialScanViewModel]'s GPS-driven node list and the shared compass
/// stream — so opening a guide sheet starts no location/heading
/// subscriptions of its own.
class EchoGuidanceUiState {
  const EchoGuidanceUiState({
    this.distanceMeters,
    this.relativeBearingDegrees,
    this.isUnlocked = false,
  });

  final double? distanceMeters;

  /// Degrees clockwise from "straight ahead of the phone's current facing
  /// direction" to the target. Null until both a location fix and a compass
  /// reading have arrived — the guide sheet falls back to a distance-only
  /// display until then.
  final double? relativeBearingDegrees;

  final bool isUnlocked;
}

final echoGuidanceProvider = Provider.family<EchoGuidanceUiState, String>((
  ref,
  nodeId,
) {
  final scanState = ref.watch(spatialScanViewModelProvider);
  final node = _findNode(scanState.nodes, nodeId);
  if (node == null || !node.isGeoAnchored) {
    return const EchoGuidanceUiState();
  }

  final headingDegrees = ref.watch(watchDeviceHeadingProvider).valueOrNull;
  final userLocation = scanState.userLocation;

  double? relativeBearingDegrees;
  if (userLocation != null && headingDegrees != null) {
    final calculateGuidanceBearing = ref.watch(calculateGuidanceBearingProvider);
    relativeBearingDegrees = calculateGuidanceBearing(
      from: userLocation,
      headingDegrees: headingDegrees,
      targetLatitude: node.latitude!,
      targetLongitude: node.longitude!,
    );
  }

  return EchoGuidanceUiState(
    distanceMeters: node.distanceMeters,
    relativeBearingDegrees: relativeBearingDegrees,
    isUnlocked: !node.isLocked,
  );
});

EchoNode? _findNode(List<EchoNode> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
  }
  return null;
}
