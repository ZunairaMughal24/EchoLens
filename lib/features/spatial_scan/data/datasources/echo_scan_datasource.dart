import 'dart:async';
import 'dart:math';

import '../models/echo_node_model.dart';
import '../services/local_signal_store.dart';
import '../../domain/entities/echo_node.dart';

abstract interface class EchoScanDataSource {
  Stream<List<EchoNodeModel>> watch();

  /// Injects a newly-planted node into the live scan pool immediately —
  /// used by [SignalRepositoryImpl] so a freshly planted echo shows up on
  /// the radar without waiting for the next drift tick.
  void plantNode(EchoNodeModel node);
}

/// Demo data source that simulates a live ambient scan with gently drifting
/// readings. Swap this for a BLE/Wi-Fi/GPS-backed implementation behind the
/// same [EchoScanDataSource] contract — nothing above the data layer changes.
///
/// Holds its node list and stream as instance state (rather than rebuilding
/// them per [watch] call) so [plantNode] can push updates to whichever
/// listener is already attached — this datasource is registered as a single
/// app-lifetime provider, so the scan screen and the planting flow always
/// share the same instance.
class MockEchoScanDataSource implements EchoScanDataSource {
  MockEchoScanDataSource({Random? random, LocalSignalStore? signalStore})
      : _random = random ?? Random(),
        _signalStore = signalStore ?? LocalSignalStore() {
    _nodes = List.generate(6, (i) => _seedNode(i));
    _controller = StreamController<List<EchoNodeModel>>.broadcast(
      onListen: () {
        _ticker = Timer.periodic(const Duration(milliseconds: 900), (_) {
          _nodes = [for (final node in _nodes) _drift(node)];
          _controller.add(_nodes);
        });
      },
      onCancel: () => _ticker?.cancel(),
    );
    // Fire-and-forget: restoring planted echoes shouldn't block the radar
    // from showing the ambient seeds immediately. They join the pool (and
    // get broadcast to whoever's already listening) a moment later.
    unawaited(_restorePersistedNodes());
  }

  final Random _random;
  final LocalSignalStore _signalStore;
  late List<EchoNodeModel> _nodes;
  final List<EchoNodeModel> _plantedNodes = [];
  late final StreamController<List<EchoNodeModel>> _controller;
  Timer? _ticker;

  static const _labels = [
    'Signal Cluster',
    'Ambient Presence',
    'Air Quality Drift',
    'Unmapped Anomaly',
    'Beacon Echo',
    'Thermal Trace',
  ];

  // Hardcoded demo target for the Phase 2 proximity-unlock flow. "Signal
  // Cluster" (index 0) starts encrypted and only reveals itself once the
  // user's live GPS fix is within EvaluateSignalProximity.unlockRadiusMeters
  // of this point.
  //
  // These coordinates won't be anywhere near you — to test the unlock
  // locally, run the app once, log the values coming out of
  // WatchUserLocation, and paste your own current lat/lng in here.
  static const _signalTargetLatitude = 37.4220;
  static const _signalTargetLongitude = -122.0841;
  static const _signalLockedLabel = 'FREQ #409';

  @override
  Stream<List<EchoNodeModel>> watch() {
    // Broadcast streams don't replay past events to a new listener, so hand
    // it the current snapshot right after `.listen()` attaches.
    Future.microtask(() => _controller.add(_nodes));
    return _controller.stream;
  }

  @override
  void plantNode(EchoNodeModel node) {
    _nodes = [..._nodes, node];
    _plantedNodes.add(node);
    _controller.add(_nodes);
    unawaited(_signalStore.savePlantedNodes(_plantedNodes));
  }

  Future<void> _restorePersistedNodes() async {
    final persisted = await _signalStore.loadPlantedNodes();
    if (persisted.isEmpty) return;
    _plantedNodes.addAll(persisted);
    _nodes = [..._nodes, ...persisted];
    _controller.add(_nodes);
  }

  EchoNodeModel _seedNode(int index) {
    // Place seeds in evenly-spaced sectors (with a little jitter) rather
    // than pure random angles, so their glass cards don't land on top of
    // each other — a fully random draw noticeably clustered on-device.
    final sectorAngle = (2 * pi / 6) * index;
    final jitter = (_random.nextDouble() - 0.5) * (pi / 6);
    final isSignalTarget = index == 0;
    return EchoNodeModel(
      id: 'echo_$index',
      label: _labels[index % _labels.length],
      category: EchoCategory.values[index % EchoCategory.values.length],
      angleRadians: sectorAngle + jitter,
      distance: 0.3 + _random.nextDouble() * 0.65,
      depth: _random.nextDouble(),
      intensity: 0.4 + _random.nextDouble() * 0.6,
      latitude: isSignalTarget ? _signalTargetLatitude : null,
      longitude: isSignalTarget ? _signalTargetLongitude : null,
      isLocked: isSignalTarget,
      lockedLabel: isSignalTarget ? _signalLockedLabel : null,
      // Guided so the built-in demo target works with the compass-guide
      // feature out of the box, without needing to plant a fresh echo first.
      isGuided: true,
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
      // Geo anchor and lock metadata are static/derived, not part of the
      // visual drift — carry them through untouched so EvaluateSignalProximity
      // keeps working and the node doesn't momentarily "re-lock" every tick.
      latitude: node.latitude,
      longitude: node.longitude,
      isLocked: node.isLocked,
      lockedLabel: node.lockedLabel,
      distanceMeters: node.distanceMeters,
      audioFilePath: node.audioFilePath,
      isGuided: node.isGuided,
    );
  }
}
