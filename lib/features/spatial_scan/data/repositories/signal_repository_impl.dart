import 'dart:math';

import '../../domain/entities/echo_node.dart';
import '../../domain/entities/signal.dart';
import '../../domain/repositories/signal_repository.dart';
import '../datasources/echo_scan_datasource.dart';
import '../models/echo_node_model.dart';

/// Converts a planted [Signal] into a radar-displayable [EchoNodeModel] and
/// folds it into the shared scan pool. There's no backend here — this is
/// what makes a freshly planted echo show up on the *same device's* radar
/// immediately. Sharing planted signals across devices/users would mean
/// swapping this for an implementation backed by a real API instead of
/// [EchoScanDataSource].
class SignalRepositoryImpl implements SignalRepository {
  SignalRepositoryImpl(this._echoScanDataSource, {Random? random})
      : _random = random ?? Random();

  final EchoScanDataSource _echoScanDataSource;
  final Random _random;

  @override
  Future<void> plant(Signal signal) async {
    final node = EchoNodeModel(
      id: signal.id,
      label: signal.label,
      category: EchoCategory.signal,
      angleRadians: _random.nextDouble() * 2 * pi,
      distance: 0.3 + _random.nextDouble() * 0.65,
      depth: _random.nextDouble(),
      intensity: 0.85,
      latitude: signal.latitude,
      longitude: signal.longitude,
      // Starts locked like any geo-anchored node — since the planter is
      // standing right on top of it, EvaluateSignalProximity flips it to
      // unlocked on the very next location tick, giving instant "planted!"
      // feedback without special-casing the planter.
      isLocked: true,
      lockedLabel: _generateLockedLabel(),
      audioFilePath: signal.audioFilePath,
      isGuided: signal.isGuided,
      plantedAt: signal.recordedAt,
    );
    _echoScanDataSource.plantNode(node);
  }

  String _generateLockedLabel() => 'FREQ #${100 + _random.nextInt(900)}';
}
