import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/services/api_service.dart';

/// Records lecture audio and transcribes it with Deepgram Whisper (via the backend).
///
/// Unlike [SpeechService], there is no live text: audio is captured as a clip,
/// and each clip is uploaded to `/transcribe` when recording is stopped.
class WhisperRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> start({bool noiseSuppress = true}) async {
    if (!await _recorder.hasPermission()) return false;

    // Web records webm/opus; mobile records AAC in an .m4a container.
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 64000,
        noiseSuppress: noiseSuppress,
        echoCancel: noiseSuppress,
        autoGain: true,
      ),
      path: path,
    );
    _isRecording = true;
    return true;
  }

  /// Stops the current clip and returns its Whisper transcript.
  /// Returns `{"success": true, "transcript": ...}` or `{"success": false, "error": ...}`.
  Future<Map<String, dynamic>> stopAndTranscribe() async {
    final path = await _recorder.stop();
    _isRecording = false;
    if (path == null || path.isEmpty) {
      return {"success": false, "error": "No audio was recorded."};
    }

    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) {
      return {"success": false, "error": "No audio was recorded."};
    }

    final res = await ApiService.transcribeAudio(
      bytes,
      kIsWeb ? 'lecture.webm' : 'lecture.m4a',
    );
    if (res["success"] != true) {
      return {"success": false, "error": res["error"] ?? "Transcription failed"};
    }
    final transcript = (res["data"]?["transcript"] ?? "").toString().trim();
    return {"success": true, "transcript": transcript};
  }

  Future<void> cancel() async {
    if (_isRecording) await _recorder.cancel();
    _isRecording = false;
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
