/// Captures a short voice note to a local file. A domain-owned port so
/// upper layers depend on this capability, not on `package:record` directly.
abstract interface class AudioRecorder {
  /// Checks (and, per the underlying platform's convention, may prompt for)
  /// microphone permission. Callers must not call [start] unless this
  /// returns true.
  Future<bool> hasPermission();

  Future<void> start();

  /// Stops the in-progress recording and returns the local file path it was
  /// saved to, or null if nothing was recorded.
  Future<String?> stop();

  Future<void> dispose();
}
