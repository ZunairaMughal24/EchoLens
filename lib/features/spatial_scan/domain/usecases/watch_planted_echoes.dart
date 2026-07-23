import '../entities/echo_node.dart';
import '../repositories/echo_scan_repository.dart';

/// Streams just the echoes the user has planted themselves — backs the "My
/// Echoes" management screen.
class WatchPlantedEchoes {
  const WatchPlantedEchoes(this._repository);

  final EchoScanRepository _repository;

  Stream<List<EchoNode>> call() => _repository.watchPlantedEchoes();
}
