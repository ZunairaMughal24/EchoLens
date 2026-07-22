import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';
import '../../domain/entities/echo_node.dart';
import '../../domain/entities/user_location.dart';
import '../../domain/exceptions/location_exceptions.dart';

/// Sentinel so `copyWith` can tell "omitted, leave unchanged" apart from
/// "explicitly set to null" for nullable fields — see [SpatialScanUiState.copyWith].
const _unset = Object();

/// Which settings page can actually resolve a given location failure.
enum LocationErrorAction { openLocationSettings, openAppSettings }

class LocationFailure {
  const LocationFailure(this.message, this.action);
  final String message;
  final LocationErrorAction action;
}

/// A one-shot "this node just unlocked" signal for the UI to react to (a
/// shockwave burst, a card pulse) — deliberately a fresh object identity on
/// every unlock rather than a plain node reference, so `ref.listen` can
/// detect "this is a new event" via identity even if the same node were to
/// unlock again later after re-locking.
class UnlockEvent {
  UnlockEvent(this.node) : timestamp = DateTime.now();
  final EchoNode node;
  final DateTime timestamp;
}

class SpatialScanUiState {
  const SpatialScanUiState({
    this.nodes = const [],
    this.isScanning = true,
    this.userLocation,
    this.locationFailure,
    this.playingNodeId,
    this.unlockEvent,
  });

  final List<EchoNode> nodes;
  final bool isScanning;
  final UserLocation? userLocation;

  /// Set when location permission/service failed. Null while everything is
  /// fine or a fix simply hasn't arrived yet.
  final LocationFailure? locationFailure;

  /// Id of the [EchoNode] currently playing its voice note, if any.
  final String? playingNodeId;

  /// The most recent lock→unlock transition, if any recompute has produced
  /// one yet. Consumed by the UI via `ref.listen` for one-shot celebration
  /// effects — see [UnlockEvent].
  final UnlockEvent? unlockEvent;

  SpatialScanUiState copyWith({
    List<EchoNode>? nodes,
    bool? isScanning,
    UserLocation? userLocation,
    Object? locationFailure = _unset,
    Object? playingNodeId = _unset,
    Object? unlockEvent = _unset,
  }) {
    return SpatialScanUiState(
      nodes: nodes ?? this.nodes,
      isScanning: isScanning ?? this.isScanning,
      userLocation: userLocation ?? this.userLocation,
      locationFailure: identical(locationFailure, _unset)
          ? this.locationFailure
          : locationFailure as LocationFailure?,
      playingNodeId: identical(playingNodeId, _unset)
          ? this.playingNodeId
          : playingNodeId as String?,
      unlockEvent: identical(unlockEvent, _unset)
          ? this.unlockEvent
          : unlockEvent as UnlockEvent?,
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
      final updatedNodes = evaluateSignalProximity(_latestRawNodes, _latestUserLocation);
      final justUnlocked = _findNewlyUnlocked(previous: state.nodes, updated: updatedNodes);
      if (justUnlocked != null) {
        HapticFeedback.heavyImpact();
        state = state.copyWith(
          nodes: updatedNodes,
          userLocation: _latestUserLocation,
          unlockEvent: UnlockEvent(justUnlocked),
        );
      } else {
        state = state.copyWith(nodes: updatedNodes, userLocation: _latestUserLocation);
      }
    }

    _echoSubscription = watchNearbyEchoes().listen((nodes) {
      _latestRawNodes = nodes;
      recompute();
    });

    _locationSubscription = watchUserLocation().listen(
      (location) {
        _latestUserLocation = location;
        state = state.copyWith(locationFailure: null);
        recompute();
      },
      onError: (Object error) {
        final message = error is LocationException
            ? error.message
            : 'Unable to read device location.';
        final action = error is LocationServiceDisabledException
            ? LocationErrorAction.openLocationSettings
            : LocationErrorAction.openAppSettings;
        state = state.copyWith(locationFailure: LocationFailure(message, action));
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

  /// Finds the first geo-anchored node that just flipped from locked to
  /// unlocked — a node not present in [previous] is treated as "was
  /// locked" so a signal that unlocks on the very first evaluation (e.g.
  /// planting one while already standing on it) still counts, not just
  /// ones discovered while already-known-locked. Drives both the haptic
  /// pulse and the celebratory UI effects in [recompute].
  EchoNode? _findNewlyUnlocked({
    required List<EchoNode> previous,
    required List<EchoNode> updated,
  }) {
    final previousLockById = {for (final node in previous) node.id: node.isLocked};
    for (final node in updated) {
      if (!node.isGeoAnchored || node.isLocked) continue;
      if (previousLockById[node.id] ?? true) return node;
    }
    return null;
  }

  void toggleScanning() {
    state = state.copyWith(isScanning: !state.isScanning);
  }

  /// Deep-links to whichever settings page can resolve the current
  /// [LocationFailure] — called from the SnackBar's action button.
  Future<void> resolveLocationFailure() async {
    final action = state.locationFailure?.action;
    if (action == null) return;
    final locationRepository = ref.read(locationRepositoryProvider);
    switch (action) {
      case LocationErrorAction.openLocationSettings:
        await locationRepository.openLocationSettings();
      case LocationErrorAction.openAppSettings:
        await locationRepository.openAppSettings();
    }
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
