import '../entities/signal.dart';

/// Publishes a freshly planted [Signal] into the world so other scans can
/// discover it. The mock implementation folds it straight into the shared
/// echo pool; a real backend would instead write it to a server so other
/// devices could discover it too.
abstract interface class SignalRepository {
  Future<void> plant(Signal signal);
}
