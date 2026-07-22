import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/services/audio_recorder.dart' as domain;

/// Wraps `package:record`, saving each take to a fresh file in the app's
/// permanent documents directory. The domain layer only ever sees
/// [domain.AudioRecorder] — nothing above this file knows the `record`
/// package exists.
class RecordAudioRecorder implements domain.AudioRecorder {
  RecordAudioRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    // getApplicationDocumentsDirectory, not getTemporaryDirectory: the OS
    // can (and does) clear the temp dir at any time, including mid-session
    // — a planted echo's voice note needs to actually survive to be worth
    // persisting alongside it.
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/echo_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}
