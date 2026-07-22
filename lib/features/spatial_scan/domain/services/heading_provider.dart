/// Source of the device's live compass heading, in degrees clockwise from
/// north (0-360) — "which way is the phone currently facing." A domain-owned
/// port so the tap-to-guide feature depends on the capability, not on
/// whatever magnetometer package reads it.
abstract interface class HeadingProvider {
  Stream<double> watchHeading();
}
