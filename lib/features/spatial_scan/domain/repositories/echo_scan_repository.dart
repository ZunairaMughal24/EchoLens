import '../entities/echo_node.dart';

/// Source of live ambient-data readings. Implementations may back this with
/// BLE/Wi-Fi scanning, GPS-anchored AR markers, environmental sensors, or a
/// backend API — the presentation layer never knows which.
abstract interface class EchoScanRepository {
  Stream<List<EchoNode>> watchNearbyEchoes();
}
