import 'dart:async';
import 'dart:math';

import '../models/echo_node_model.dart';
import '../../domain/entities/echo_node.dart';

abstract interface class EchoScanDataSource {
  Stream<List<EchoNodeModel>> watch();
}

/// Demo data source that simulates a live ambient scan with gently drifting
/// readings. Swap this for a BLE/Wi-Fi/GPS-backed implementation behind the
/// same [EchoScanDataSource] contract — nothing above the data layer changes.
class MockEchoScanDataSource implements EchoScanDataSource {
  MockEchoScanDataSource({Random? random}) : _random = random ?? Random();

  final Random _random;
  static const _labels = [
    'Signal Cluster',
    'Ambient Presence',
    'Air Quality Drift',
    'Unmapped Anomaly',
    'Beacon Echo',
    'Thermal Trace',
  ];

  @override
  Stream<List<EchoNodeModel>> watch() {
    var nodes = List.generate(6, (i) => _seedNode(i));
    Timer? ticker;
    late final StreamController<List<EchoNodeModel>> controller;

    // Timer.periodic (vs. a recursive `Future.delayed` loop) so that
    // cancelling the subscription actually stops the polling — a
    // `Future.delayed` already in flight can't be cancelled once scheduled,
    // which would leak a timer for as long as the process runs.
    controller = StreamController<List<EchoNodeModel>>(
      onListen: () {
        controller.add(nodes);
        ticker = Timer.periodic(const Duration(milliseconds: 900), (_) {
          nodes = [for (final node in nodes) _drift(node)];
          controller.add(nodes);
        });
      },
      onCancel: () => ticker?.cancel(),
    );
    return controller.stream;
  }

  EchoNodeModel _seedNode(int index) {
    // Place seeds in evenly-spaced sectors (with a little jitter) rather
    // than pure random angles, so their glass cards don't land on top of
    // each other — a fully random draw noticeably clustered on-device.
    final sectorAngle = (2 * pi / 6) * index;
    final jitter = (_random.nextDouble() - 0.5) * (pi / 6);
    return EchoNodeModel(
      id: 'echo_$index',
      label: _labels[index % _labels.length],
      category: EchoCategory.values[index % EchoCategory.values.length],
      angleRadians: sectorAngle + jitter,
      distance: 0.3 + _random.nextDouble() * 0.65,
      depth: _random.nextDouble(),
      intensity: 0.4 + _random.nextDouble() * 0.6,
    );
  }

  EchoNodeModel _drift(EchoNodeModel node) {
    double clamp01(double v) => v.clamp(0.0, 1.0);
    return EchoNodeModel(
      id: node.id,
      label: node.label,
      category: node.category,
      angleRadians: node.angleRadians + (_random.nextDouble() - 0.5) * 0.08,
      distance: clamp01(node.distance + (_random.nextDouble() - 0.5) * 0.04),
      depth: clamp01(node.depth + (_random.nextDouble() - 0.5) * 0.06),
      intensity:
          clamp01(node.intensity + (_random.nextDouble() - 0.5) * 0.15),
    );
  }
}
