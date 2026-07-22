/// The payload produced by planting an echo: a short voice note anchored to
/// the real-world position it was recorded at. Deliberately smaller/simpler
/// than [EchoNode] — [EchoNode] is the radar's *display* representation
/// (polar coordinates, category, lock state); [Signal] is just "what the
/// user captured," before it's turned into a node on the pool.
class Signal {
  const Signal({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.audioFilePath,
    required this.recordedAt,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final String audioFilePath;
  final DateTime recordedAt;
}
