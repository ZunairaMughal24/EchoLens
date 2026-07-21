import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/echo_scan_datasource.dart';
import '../../data/datasources/location_datasource.dart';
import '../../data/repositories/echo_scan_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/services/geolocator_distance_calculator.dart';
import '../../domain/entities/echo_node.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exceptions.dart';
import '../../domain/repositories/echo_scan_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/services/distance_calculator.dart';
import '../../domain/usecases/evaluate_signal_proximity.dart';
import '../../domain/usecases/watch_nearby_echoes.dart';
import '../../domain/usecases/watch_user_location.dart';

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

final _locationDataSourceProvider = Provider<LocationDataSource>(
  (ref) => const GeolocatorLocationDataSource(),
);

final _locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepositoryImpl(ref.watch(_locationDataSourceProvider)),
);

final _watchUserLocationProvider = Provider(
  (ref) => WatchUserLocation(ref.watch(_locationRepositoryProvider)),
);

final _distanceCalculatorProvider = Provider<DistanceCalculator>(
  (ref) => const GeolocatorDistanceCalculator(),
);

final _evaluateSignalProximityProvider = Provider(
  (ref) => EvaluateSignalProximity(ref.watch(_distanceCalculatorProvider)),
);

class SpatialScanUiState {
  const SpatialScanUiState({
    this.nodes = const [],
    this.isScanning = true,
    this.userLocation,
    this.locationErrorMessage,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final UserLocation? userLocation;

  /// Human-readable message when location permission/service failed. Null
  /// while everything is fine or a fix simply hasn't arrived yet.
  final String? locationErrorMessage;

  SpatialScanUiState copyWith({
    List<EchoNode>? nodes,
    bool? isScanning,
    UserLocation? userLocation,
    String? locationErrorMessage,
  }) {
    return SpatialScanUiState(
      nodes: nodes ?? this.nodes,
      isScanning: isScanning ?? this.isScanning,
      userLocation: userLocation ?? this.userLocation,
      locationErrorMessage: locationErrorMessage,
    );
  }
}

/// Owns the spatial-scan screen's state: subscribes to the live echo stream
/// and the live GPS stream, and recombines them through
/// [EvaluateSignalProximity] so geo-anchored nodes unlock in real time as the
/// user gets close. The screen only reads [SpatialScanUiState] and calls
/// [toggleScanning] — it never touches a repository/data-source directly.
class SpatialScanViewModel extends Notifier<SpatialScanUiState> {
  StreamSubscription<List<EchoNode>>? _echoSubscription;
  StreamSubscription<UserLocation>? _locationSubscription;

  List<EchoNode> _latestRawNodes = const [];
  UserLocation? _latestUserLocation;

  @override
  SpatialScanUiState build() {
    final watchNearbyEchoes = ref.watch(_watchNearbyEchoesProvider);
    final watchUserLocation = ref.watch(_watchUserLocationProvider);
    final evaluateSignalProximity = ref.watch(_evaluateSignalProximityProvider);

    void recompute() {
      state = state.copyWith(
        nodes: evaluateSignalProximity(_latestRawNodes, _latestUserLocation),
        userLocation: _latestUserLocation,
        // copyWith resets omitted nullable fields to null (needed so the
        // success handler below can *clear* an error) — pass the current
        // value through explicitly here so an in-flight error isn't wiped
        // out by an unrelated echo-stream tick.
        locationErrorMessage: state.locationErrorMessage,
      );
    }

    _echoSubscription = watchNearbyEchoes().listen((nodes) {
      _latestRawNodes = nodes;
      recompute();
    });

    _locationSubscription = watchUserLocation().listen(
      (location) {
        _latestUserLocation = location;
        state = state.copyWith(locationErrorMessage: null);
        recompute();
      },
      onError: (Object error) {
        final message = error is LocationException
            ? error.message
            : 'Unable to read device location.';
        state = state.copyWith(locationErrorMessage: message);
      },
    );

    ref.onDispose(() {
      _echoSubscription?.cancel();
      _locationSubscription?.cancel();
    });
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
