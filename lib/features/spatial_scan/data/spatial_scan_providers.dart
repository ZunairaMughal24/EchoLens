import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repositories/echo_scan_repository.dart';
import '../domain/repositories/location_repository.dart';
import '../domain/repositories/signal_repository.dart';
import '../domain/services/audio_player.dart';
import '../domain/services/audio_recorder.dart';
import '../domain/services/distance_calculator.dart';
import '../domain/usecases/evaluate_signal_proximity.dart';
import '../domain/usecases/get_current_user_location.dart';
import '../domain/usecases/plant_signal.dart';
import '../domain/usecases/watch_nearby_echoes.dart';
import '../domain/usecases/watch_user_location.dart';
import 'datasources/echo_scan_datasource.dart';
import 'datasources/location_datasource.dart';
import 'repositories/echo_scan_repository_impl.dart';
import 'repositories/location_repository_impl.dart';
import 'repositories/signal_repository_impl.dart';
import 'services/audioplayers_signal_player.dart';
import 'services/geolocator_distance_calculator.dart';
import 'services/record_audio_recorder.dart';

// Composition root for the spatial_scan feature. Every provider here is
// app-lifetime (not autoDispose) so the scanning screen and the planting
// flow always share the same underlying instances — that sharing is load
// bearing: SignalRepositoryImpl injects planted nodes straight into the
// same EchoScanDataSource the radar is watching.

final echoScanDataSourceProvider = Provider<EchoScanDataSource>(
  (ref) => MockEchoScanDataSource(),
);

final echoScanRepositoryProvider = Provider<EchoScanRepository>(
  (ref) => EchoScanRepositoryImpl(ref.watch(echoScanDataSourceProvider)),
);

final watchNearbyEchoesProvider = Provider(
  (ref) => WatchNearbyEchoes(ref.watch(echoScanRepositoryProvider)),
);

final locationDataSourceProvider = Provider<LocationDataSource>(
  (ref) => const GeolocatorLocationDataSource(),
);

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepositoryImpl(ref.watch(locationDataSourceProvider)),
);

final watchUserLocationProvider = Provider(
  (ref) => WatchUserLocation(ref.watch(locationRepositoryProvider)),
);

final getCurrentUserLocationProvider = Provider(
  (ref) => GetCurrentUserLocation(ref.watch(locationRepositoryProvider)),
);

final distanceCalculatorProvider = Provider<DistanceCalculator>(
  (ref) => const GeolocatorDistanceCalculator(),
);

final evaluateSignalProximityProvider = Provider(
  (ref) => EvaluateSignalProximity(ref.watch(distanceCalculatorProvider)),
);

final audioRecorderProvider = Provider<AudioRecorder>(
  (ref) => RecordAudioRecorder(),
);

final audioPlayerProvider = Provider<AudioPlayer>(
  (ref) => AudioPlayersSignalPlayer(),
);

final signalRepositoryProvider = Provider<SignalRepository>(
  (ref) => SignalRepositoryImpl(ref.watch(echoScanDataSourceProvider)),
);

final plantSignalProvider = Provider(
  (ref) => PlantSignal(
    ref.watch(getCurrentUserLocationProvider),
    ref.watch(signalRepositoryProvider),
  ),
);
