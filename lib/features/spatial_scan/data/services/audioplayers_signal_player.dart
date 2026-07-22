import 'package:audioplayers/audioplayers.dart';

import '../../domain/services/audio_player.dart' as domain;

/// Wraps `package:audioplayers` for local-file voice-note playback. The
/// domain layer only ever sees [domain.AudioPlayer].
class AudioPlayersSignalPlayer implements domain.AudioPlayer {
  AudioPlayersSignalPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> play(String filePath) => _player.play(DeviceFileSource(filePath));

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<bool> watchIsPlaying() => _player.onPlayerStateChanged
      .map((state) => state == PlayerState.playing);

  @override
  Future<void> dispose() => _player.dispose();
}
