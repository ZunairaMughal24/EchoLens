import '../entities/echo_node.dart';

/// Source of live ambient-data readings. Implementations may back this with
/// BLE/Wi-Fi scanning, GPS-anchored AR markers, environmental sensors, or a
/// backend API — the presentation layer never knows which.
abstract interface class EchoScanRepository {
  Stream<List<EchoNode>> watchNearbyEchoes();

  /// Just the echoes the user has planted themselves, for management (play
  /// back, delete) — not the ambient/demo nodes [watchNearbyEchoes] also
  /// includes.
  Stream<List<EchoNode>> watchPlantedEchoes();

  /// Permanently removes a planted echo, including its recorded audio.
  Future<void> deleteEcho(String id);
}
