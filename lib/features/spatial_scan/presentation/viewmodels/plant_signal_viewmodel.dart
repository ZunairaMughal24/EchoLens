import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spatial_scan_providers.dart';

enum RecordingStatus { idle, recording, recorded, planting, planted, error }

class PlantSignalUiState {
  const PlantSignalUiState({
    this.status = RecordingStatus.idle,
    this.recordedFilePath,
    this.errorMessage,
  });

  final RecordingStatus status;
  final String? recordedFilePath;
  final String? errorMessage;

  PlantSignalUiState copyWith({
    RecordingStatus? status,
    String? recordedFilePath,
    String? errorMessage,
  }) {
    return PlantSignalUiState(
      status: status ?? this.status,
      recordedFilePath: recordedFilePath ?? this.recordedFilePath,
      errorMessage: errorMessage,
    );
  }
}

/// Owns the "plant an echo" flow: record a voice note, then plant it at the
/// user's current position. Recording start/stop is interactive (driven by
/// button taps), so it's orchestrated here rather than folded into a single
/// use case; [PlantSignal] itself only owns the business rule of anchoring
/// the result to the user's current GPS fix.
class PlantSignalViewModel extends AutoDisposeNotifier<PlantSignalUiState> {
  @override
  PlantSignalUiState build() {
    // Covers the back-button/swipe-away case, not just the explicit close
    // button: if the screen is torn down mid-recording, stop the recorder
    // rather than leaving the mic hot in the background.
    ref.onDispose(() {
      if (state.status == RecordingStatus.recording) {
        ref.read(audioRecorderProvider).stop();
      }
    });
    return const PlantSignalUiState();
  }

  Future<void> startRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    try {
      final granted = await recorder.hasPermission();
      if (!granted) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: 'Microphone permission is required to plant an echo.',
        );
        return;
      }
      await recorder.start();
      state = state.copyWith(status: RecordingStatus.recording, errorMessage: null);
    } catch (_) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Could not start recording — check microphone access and try again.',
      );
    }
  }

  Future<void> stopRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    try {
      final path = await recorder.stop();
      if (path == null) {
        state = state.copyWith(
          status: RecordingStatus.error,
          errorMessage: 'Recording failed — try again.',
        );
        return;
      }
      state = state.copyWith(status: RecordingStatus.recorded, recordedFilePath: path);
    } catch (_) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Could not save the recording — try again.',
      );
    }
  }

  Future<void> plant({required String label}) async {
    // Guards against a fast double-tap on "Plant Echo" firing this twice —
    // the second call sees planting already in flight and bails out,
    // regardless of whether the UI has rebuilt to hide the button yet.
    if (state.status == RecordingStatus.planting) return;

    final path = state.recordedFilePath;
    if (path == null) return;

    state = state.copyWith(status: RecordingStatus.planting);
    try {
      final plantSignal = ref.read(plantSignalProvider);
      final resolvedLabel = label.trim().isEmpty ? 'Untitled Echo' : label.trim();
      await plantSignal(label: resolvedLabel, audioFilePath: path);
      state = state.copyWith(status: RecordingStatus.planted);
    } catch (_) {
      state = state.copyWith(
        status: RecordingStatus.error,
        errorMessage: 'Could not plant this echo — check location permission and try again.',
      );
    }
  }

  void reset() => state = const PlantSignalUiState();
}

// autoDispose (unlike the app-lifetime spatial_scan_providers): this
// ViewModel's job is entirely scoped to one visit to PlantSignalScreen.
// Without it, planting an echo then reopening the screen later would show
// the stale "planted!" confirmation instead of a fresh recording UI.
final plantSignalViewModelProvider = NotifierProvider.autoDispose<
    PlantSignalViewModel, PlantSignalUiState>(
  PlantSignalViewModel.new,
);
