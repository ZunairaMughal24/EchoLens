import '../entities/echo_node.dart';
import '../repositories/echo_scan_repository.dart';

/// Streams the live set of echoes detected around the user.
class WatchNearbyEchoes {
  const WatchNearbyEchoes(this._repository);

  final EchoScanRepository _repository;

  Stream<List<EchoNode>> call() => _repository.watchNearbyEchoes();
}
