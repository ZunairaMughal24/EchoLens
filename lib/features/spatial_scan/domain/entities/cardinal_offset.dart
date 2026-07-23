/// A straight-line distance decomposed into north/south and east/west
/// components — "12m north, 4m east" instead of an abstract bearing angle.
/// Meant to read as walking directions on its own, without needing a
/// compass reading at all (unlike the rotating-arrow guide, which does).
class CardinalOffset {
  const CardinalOffset({
    required this.northSouthMeters,
    required this.isNorth,
    required this.eastWestMeters,
    required this.isEast,
  });

  /// Always >= 0 — direction is carried separately by [isNorth].
  final double northSouthMeters;
  final bool isNorth;

  /// Always >= 0 — direction is carried separately by [isEast].
  final double eastWestMeters;
  final bool isEast;
}
