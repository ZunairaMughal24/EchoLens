import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/echo_scan_datasource.dart';
import '../../data/repositories/echo_scan_repository_impl.dart';
import '../../domain/entities/echo_node.dart';
import '../../domain/repositories/echo_scan_repository.dart';
import '../../domain/usecases/watch_nearby_echoes.dart';

// Dependency wiring (composition root for this feature). Swapping
// MockEchoScanDataSource for a real one only requires changing this line.
final _dataSourceProvider = Provider<EchoScanDataSource>(
  (ref) => MockEchoScanDataSource(),
);

final _repositoryProvider = Provider<EchoScanRepository>(
  (ref) => EchoScanRepositoryImpl(ref.watch(_dataSourceProvider)),
);

final _watchNearbyEchoesProvider = Provider(
  (ref) => WatchNearbyEchoes(ref.watch(_repositoryProvider)),
);

class SpatialScanUiState {
  const SpatialScanUiState({
    this.nodes = const [],
    this.isScanning = true,
  });

  final List<EchoNode> nodes;
  final bool isScanning;

  SpatialScanUiState copyWith({List<EchoNode>? nodes, bool? isScanning}) {
    return SpatialScanUiState(
      nodes: nodes ?? this.nodes,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

/// Owns the spatial-scan screen's state: subscribes to the live echo stream
/// via the domain use case and exposes UI-ready state + intents. The screen
/// only reads [SpatialScanUiState] and calls [toggleScanning] — it never
/// touches the repository/data-source directly.
class SpatialScanViewModel extends Notifier<SpatialScanUiState> {
  StreamSubscription<List<EchoNode>>? _subscription;

  @override
  SpatialScanUiState build() {
    final watchNearbyEchoes = ref.watch(_watchNearbyEchoesProvider);
    _subscription = watchNearbyEchoes().listen((nodes) {
      state = state.copyWith(nodes: nodes);
    });
    ref.onDispose(() => _subscription?.cancel());
    return const SpatialScanUiState();
  }

  void toggleScanning() {
    state = state.copyWith(isScanning: !state.isScanning);
  }
}

final spatialScanViewModelProvider =
    NotifierProvider<SpatialScanViewModel, SpatialScanUiState>(
  SpatialScanViewModel.new,
);
