/// What kind of ambient signal an [EchoNode] represents.
/// Presentation maps this to color/iconography — domain stays UI-agnostic.
enum EchoCategory { signal, presence, environment, anomaly }

/// A single detected point of "invisible" data in physical space, positioned
/// in polar coordinates relative to the user (angle/distance) with an
/// additional depth channel for the pseudo-3D parallax effect.
class EchoNode {
  const EchoNode({
    required this.id,
    required this.label,
    required this.category,
    required this.angleRadians,
    required this.distance,
    required this.depth,
    required this.intensity,
  });

  final String id;
  final String label;
  final EchoCategory category;

  /// Bearing from the user, in radians.
  final double angleRadians;

  /// Normalized radial position from center, 0.0 (near) – 1.0 (edge of scan).
  final double distance;

  /// Normalized pseudo-depth, 0.0 (far) – 1.0 (near) — drives parallax scale.
  final double depth;

  /// Normalized signal strength/confidence, 0.0 – 1.0.
  final double intensity;
}
