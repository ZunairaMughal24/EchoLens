/// Great-circle distance between two coordinates, in meters. A domain-owned
/// port so business logic (see `EvaluateSignalProximity`) can depend on the
/// capability without importing whatever geo package computes it.
abstract interface class DistanceCalculator {
  double metersBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  );
}
