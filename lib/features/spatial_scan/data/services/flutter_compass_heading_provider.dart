import 'package:flutter_compass/flutter_compass.dart';

import '../../domain/services/heading_provider.dart';

/// Wraps `package:flutter_compass`'s device magnetometer stream. Needs no
/// extra platform permission beyond what location already requires (Android
/// reads the magnetometer directly; iOS ties heading updates to location
/// services). Some devices report no compass hardware at all, in which case
/// [FlutterCompass.events] is null — [watchHeading] degrades to an empty
/// stream rather than throwing, so the guide UI just falls back to
/// distance-only guidance instead of crashing.
class FlutterCompassHeadingProvider implements HeadingProvider {
  const FlutterCompassHeadingProvider();

  @override
  Stream<double> watchHeading() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();
    return events
        .where((event) => event.heading != null)
        .map((event) => (event.heading! + 360) % 360);
  }
}
