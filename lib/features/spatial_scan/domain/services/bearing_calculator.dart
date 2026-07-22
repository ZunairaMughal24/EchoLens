/// Initial great-circle bearing from one coordinate to another, in degrees
/// clockwise from true north (0-360). A domain-owned port, mirroring
/// [DistanceCalculator], so business logic depends on the capability rather
/// than importing whatever geo package computes it.
abstract interface class BearingCalculator {
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  );
}
