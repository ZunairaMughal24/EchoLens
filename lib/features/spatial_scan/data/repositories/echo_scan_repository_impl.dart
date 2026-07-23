import '../../domain/entities/echo_node.dart';
import '../../domain/repositories/echo_scan_repository.dart';
import '../datasources/echo_scan_datasource.dart';

class EchoScanRepositoryImpl implements EchoScanRepository {
  const EchoScanRepositoryImpl(this._dataSource);

  final EchoScanDataSource _dataSource;

  @override
  Stream<List<EchoNode>> watchNearbyEchoes() => _dataSource.watch();

  @override
  Stream<List<EchoNode>> watchPlantedEchoes() => _dataSource.watchPlanted();

  @override
  Future<void> deleteEcho(String id) => _dataSource.deleteNode(id);
}
