import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';
import '../../domain/entities/echo_node.dart';

/// Sentinel so `copyWith` can tell "omitted, leave unchanged" apart from
/// "explicitly set to null" — see [MyEchoesUiState.copyWith].
const _unset = Object();

class MyEchoesUiState {
  const MyEchoesUiState({this.echoes = const [], this.playingId});

  final List<EchoNode> echoes;

  /// Id of the echo currently playing its voice note, if any.
  final String? playingId;

  MyEchoesUiState copyWith({
    List<EchoNode>? echoes,
    Object? playingId = _unset,
  }) {
    return MyEchoesUiState(
      echoes: echoes ?? this.echoes,
      playingId: identical(playingId, _unset)
          ? this.playingId
          : playingId as String?,
    );
  }
}

/// Owns the "My Echoes" screen: the user's own planted voice notes, newest
/// first, with playback and delete. Reuses the same shared [EchoScanDataSource]
/// planting/deletion already wired for the radar — deleting here removes the
/// echo from the live scan pool too, not just this list.
class MyEchoesViewModel extends AutoDisposeNotifier<MyEchoesUiState> {
  StreamSubscription<List<EchoNode>>? _echoesSubscription;
  StreamSubscription<bool>? _playbackSubscription;

  @override
  MyEchoesUiState build() {
    final watchPlantedEchoes = ref.watch(watchPlantedEchoesProvider);
    final audioPlayer = ref.watch(audioPlayerProvider);

    _echoesSubscription = watchPlantedEchoes().listen((echoes) {
      final sorted = [...echoes]..sort((a, b) {
        final aTime = a.plantedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.plantedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      state = state.copyWith(echoes: sorted);
    });

    _playbackSubscription = audioPlayer.watchIsPlaying().listen((isPlaying) {
      if (!isPlaying) state = state.copyWith(playingId: null);
    });

    ref.onDispose(() {
      _echoesSubscription?.cancel();
      _playbackSubscription?.cancel();
    });

    return const MyEchoesUiState();
  }

  /// Plays (or, if already playing, stops) an echo's voice note.
  Future<void> play(EchoNode node) async {
    final path = node.audioFilePath;
    if (path == null) return;

    final audioPlayer = ref.read(audioPlayerProvider);
    if (state.playingId == node.id) {
      await audioPlayer.stop();
      state = state.copyWith(playingId: null);
      return;
    }
    state = state.copyWith(playingId: node.id);
    await audioPlayer.play(path);
  }

  /// Permanently deletes an echo — stops playback first if it's the one
  /// currently playing, so audio doesn't keep running for a note that no
  /// longer exists.
  Future<void> delete(String id) async {
    if (state.playingId == id) {
      await ref.read(audioPlayerProvider).stop();
      state = state.copyWith(playingId: null);
    }
    await ref.read(deleteEchoProvider)(id);
  }
}

final myEchoesViewModelProvider =
    NotifierProvider.autoDispose<MyEchoesViewModel, MyEchoesUiState>(
  MyEchoesViewModel.new,
);
