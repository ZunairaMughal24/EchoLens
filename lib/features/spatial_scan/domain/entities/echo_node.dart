/// What kind of ambient signal an [EchoNode] represents.
/// Presentation maps this to color/iconography — domain stays UI-agnostic.
enum EchoCategory { signal, presence, environment, anomaly }

/// A single detected point of "invisible" data in physical space, positioned
/// in polar coordinates relative to the user (angle/distance) with an
/// additional depth channel for the pseudo-3D parallax effect.
///
/// A subset of nodes are also anchored to a real-world [latitude]/[longitude]
/// and start [isLocked] — these reveal their true [label] only once the
/// user's live GPS position closes to within the unlock radius (see
/// `EvaluateSignalProximity`). Ambient-only nodes simply leave the geo
/// fields null and are never subject to locking.
class EchoNode {
  const EchoNode({
    required this.id,
    required this.label,
    required this.category,
    required this.angleRadians,
    required this.distance,
    required this.depth,
    required this.intensity,
    this.latitude,
    this.longitude,
    this.isLocked = false,
    this.lockedLabel,
    this.distanceMeters,
    this.audioFilePath,
    this.isGuided = true,
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

  /// Real-world anchor point. Null for nodes that aren't geo-locked.
  final double? latitude;
  final double? longitude;

  /// Whether this node's true [label] is still hidden behind [lockedLabel].
  final bool isLocked;

  /// Placeholder shown in place of [label] while [isLocked] is true
  /// (e.g. "FREQ #409").
  final String? lockedLabel;

  /// Live great-circle distance from the user to [latitude]/[longitude], in
  /// meters. Null until a location fix and this node have both been seen.
  final double? distanceMeters;

  /// Local path to a recorded voice note attached to this node, if any
  /// (see `PlantSignal`). Only meaningful once unlocked.
  final String? audioFilePath;

  /// The planter's choice, set at plant time and never recomputed: whether
  /// finders get a live directional guide toward this node while it's
  /// still locked (see `echoGuidanceProvider`), or have to find it by
  /// scanning alone. Meaningless for ambient (non-geo-anchored) nodes.
  final bool isGuided;

  bool get isGeoAnchored => latitude != null && longitude != null;

  bool get hasVoiceNote => audioFilePath != null;

  /// The label to actually render: the encrypted placeholder while locked,
  /// otherwise the real [label].
  String get displayLabel => isLocked ? (lockedLabel ?? label) : label;

  EchoNode copyWith({
    bool? isLocked,
    double? distanceMeters,
    double? distance,
    double? depth,
    double? angleRadians,
  }) {
    return EchoNode(
      id: id,
      label: label,
      category: category,
      angleRadians: angleRadians ?? this.angleRadians,
      distance: distance ?? this.distance,
      depth: depth ?? this.depth,
      intensity: intensity,
      latitude: latitude,
      longitude: longitude,
      isLocked: isLocked ?? this.isLocked,
      lockedLabel: lockedLabel,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      audioFilePath: audioFilePath,
      isGuided: isGuided,
    );
  }
}
