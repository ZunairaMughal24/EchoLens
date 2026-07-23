import '../repositories/echo_scan_repository.dart';

/// Permanently deletes a planted echo — it should not, in fact, "stay in
/// the space forever." Removes it from the live scan pool, persisted
/// storage, and deletes the recorded audio file itself.
class DeleteEcho {
  const DeleteEcho(this._repository);

  final EchoScanRepository _repository;

  Future<void> call(String id) => _repository.deleteEcho(id);
}
