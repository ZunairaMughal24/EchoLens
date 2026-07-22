/// Plays back a local audio file. A domain-owned port so upper layers
/// depend on this capability, not on `package:audioplayers` directly.
abstract interface class AudioPlayer {
  Future<void> play(String filePath);

  Future<void> stop();

  /// Emits the current playing/not-playing state, including the moment
  /// playback finishes on its own so listeners can clear any "now playing"
  /// UI without polling.
  Stream<bool> watchIsPlaying();

  Future<void> dispose();
}
