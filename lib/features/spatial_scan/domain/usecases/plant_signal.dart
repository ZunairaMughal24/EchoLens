import '../entities/signal.dart';
import '../repositories/signal_repository.dart';
import 'get_current_user_location.dart';

/// Turns a recorded voice note into a [Signal] anchored to the user's
/// current position, and publishes it. The recording itself is the
/// ViewModel's job (it's an interactive, UI-driven start/stop flow) — this
/// use case only owns the business rule "a planted signal is anchored to
/// wherever the user is standing right now."
class PlantSignal {
  const PlantSignal(this._getCurrentUserLocation, this._signalRepository);

  final GetCurrentUserLocation _getCurrentUserLocation;
  final SignalRepository _signalRepository;

  Future<Signal> call({
    required String label,
    required String audioFilePath,
  }) async {
    final location = await _getCurrentUserLocation();
    final signal = Signal(
      id: 'signal_${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      latitude: location.latitude,
      longitude: location.longitude,
      audioFilePath: audioFilePath,
      recordedAt: DateTime.now(),
    );
    await _signalRepository.plant(signal);
    return signal;
  }
}
