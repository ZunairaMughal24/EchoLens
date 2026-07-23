import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';
import '../../domain/entities/cardinal_offset.dart';
import '../../domain/entities/echo_node.dart';
import 'spatial_scan_viewmodel.dart';

/// Live guidance toward one specific geo-anchored node: how far off the
/// device's current facing direction the target currently is, plus the
/// straight-line distance decomposed into cardinal (N/S/E/W) components.
/// Purely derived from data already being kept live elsewhere —
/// [SpatialScanViewModel]'s GPS-driven node list and the shared compass
/// stream — so opening a guide sheet starts no location/heading
/// subscriptions of its own.
class EchoGuidanceUiState {
  const EchoGuidanceUiState({
    this.distanceMeters,
    this.relativeBearingDegrees,
    this.cardinalOffset,
    this.isUnlocked = false,
  });

  final double? distanceMeters;

  /// Degrees clockwise from "straight ahead of the phone's current facing
  /// direction" to the target. Null until both a location fix and a compass
  /// reading have arrived — the rotating arrow falls back to a resting
  /// state until then.
  final double? relativeBearingDegrees;

  /// "12m north, 4m east" as raw numbers — needs only a location fix, not a
  /// compass reading, so this is available (and the guide sheet can show
  /// real walking directions) well before/even without [relativeBearingDegrees].
  final CardinalOffset? cardinalOffset;

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

  final userLocation = scanState.userLocation;

  double? relativeBearingDegrees;
  CardinalOffset? cardinalOffset;

  if (userLocation != null) {
    final bearingCalculator = ref.watch(bearingCalculatorProvider);
    final absoluteBearingDegrees = _normalize(
      bearingCalculator.bearingBetween(
        userLocation.latitude,
        userLocation.longitude,
        node.latitude!,
        node.longitude!,
      ),
    );

    final distanceMeters = node.distanceMeters;
    if (distanceMeters != null) {
      final decomposeCardinalOffset = ref.watch(decomposeCardinalOffsetProvider);
      cardinalOffset = decomposeCardinalOffset(
        distanceMeters: distanceMeters,
        absoluteBearingDegrees: absoluteBearingDegrees,
      );
    }

    // Relative bearing (for the rotating arrow) additionally needs a
    // compass reading, which cardinal text guidance above deliberately
    // doesn't depend on — the compass is the flakier sensor of the two.
    final headingDegrees = ref.watch(watchDeviceHeadingProvider).valueOrNull;
    if (headingDegrees != null) {
      relativeBearingDegrees = _normalize(absoluteBearingDegrees - headingDegrees);
    }
  }

  return EchoGuidanceUiState(
    distanceMeters: node.distanceMeters,
    relativeBearingDegrees: relativeBearingDegrees,
    cardinalOffset: cardinalOffset,
    isUnlocked: !node.isLocked,
  );
});

double _normalize(double degrees) => ((degrees % 360) + 360) % 360;

EchoNode? _findNode(List<EchoNode> nodes, String id) {
  for (final node in nodes) {
    if (node.id == id) return node;
  }
  return null;
}
