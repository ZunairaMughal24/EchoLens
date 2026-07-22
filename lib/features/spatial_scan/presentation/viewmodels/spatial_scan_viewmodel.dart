import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';
import '../../domain/entities/echo_node.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exceptions.dart';

/// Sentinel so `copyWith` can tell "omitted, leave unchanged" apart from
/// "explicitly set to null" for nullable fields — see [SpatialScanUiState.copyWith].
const _unset = Object();

class SpatialScanUiState {
  const SpatialScanUiState({
    this.nodes = const [],
    this.isScanning = true,
    this.userLocation,
    this.locationErrorMessage,
    this.playingNodeId,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final UserLocation? userLocation;

  /// Human-readable message when location permission/service failed. Null
  /// while everything is fine or a fix simply hasn't arrived yet.
  final String? locationErrorMessage;

  /// Id of the [EchoNode] currently playing its voice note, if any.
  final String? playingNodeId;

  SpatialScanUiState copyWith({
    List<EchoNode>? nodes,
    bool? isScanning,
    UserLocation? userLocation,
    Object? locationErrorMessage = _unset,
    Object? playingNodeId = _unset,
  }) {
    return SpatialScanUiState(
      nodes: nodes ?? this.nodes,
      isScanning: isScanning ?? this.isScanning,
      userLocation: userLocation ?? this.userLocation,
      locationErrorMessage: identical(locationErrorMessage, _unset)
          ? this.locationErrorMessage
          : locationErrorMessage as String?,
      playingNodeId: identical(playingNodeId, _unset)
          ? this.playingNodeId
          : playingNodeId as String?,
    );
  }
}

/// Owns the spatial-scan screen's state: subscribes to the live echo
/// stream, the live GPS stream, and voice-note playback state, recombining
/// the first two through [EvaluateSignalProximity] so geo-anchored nodes
/// unlock in real time as the user gets close. The screen only reads
/// [SpatialScanUiState] and calls [toggleScanning]/[playSignal] — it never
/// touches a repository/data-source directly.
class SpatialScanViewModel extends Notifier<SpatialScanUiState> {
  StreamSubscription<List<EchoNode>>? _echoSubscription;
  StreamSubscription<UserLocation>? _locationSubscription;
  StreamSubscription<bool>? _playbackSubscription;

  List<EchoNode> _latestRawNodes = const [];
  UserLocation? _latestUserLocation;

  @override
  SpatialScanUiState build() {
    final watchNearbyEchoes = ref.watch(watchNearbyEchoesProvider);
    final watchUserLocation = ref.watch(watchUserLocationProvider);
    final evaluateSignalProximity = ref.watch(evaluateSignalProximityProvider);
    final audioPlayer = ref.watch(audioPlayerProvider);

    void recompute() {
      state = state.copyWith(
        nodes: evaluateSignalProximity(_latestRawNodes, _latestUserLocation),
        userLocation: _latestUserLocation,
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

    _playbackSubscription = audioPlayer.watchIsPlaying().listen((isPlaying) {
      if (!isPlaying) {
        state = state.copyWith(playingNodeId: null);
      }
    });

    ref.onDispose(() {
      _echoSubscription?.cancel();
      _locationSubscription?.cancel();
      _playbackSubscription?.cancel();
    });
    return const SpatialScanUiState();
  }

  void toggleScanning() {
    state = state.copyWith(isScanning: !state.isScanning);
  }

  /// Plays (or, if this node is already playing, stops) a node's voice
  /// note. No-ops for nodes without one — the UI should only offer this on
  /// unlocked nodes with [EchoNode.hasVoiceNote].
  Future<void> playSignal(EchoNode node) async {
    final path = node.audioFilePath;
    if (path == null) return;

    final audioPlayer = ref.read(audioPlayerProvider);
    if (state.playingNodeId == node.id) {
      await audioPlayer.stop();
      state = state.copyWith(playingNodeId: null);
      return;
    }
    state = state.copyWith(playingNodeId: node.id);
    await audioPlayer.play(path);
  }
}

final spatialScanViewModelProvider =
    NotifierProvider<SpatialScanViewModel, SpatialScanUiState>(
  SpatialScanViewModel.new,
);
