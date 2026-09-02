import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/stt_state.dart';
import 'remote_ai_service.dart';

/// Records a short voice note and sends it to the Nalam server for Sarvam STT.
class STTService {
  STTService(this._remoteAiService, {AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final RemoteAiService _remoteAiService;
  final AudioRecorder _recorder;
  final StreamController<SttEngineState> _stateController =
      StreamController<SttEngineState>.broadcast();

  SttEngineState _currentState = const SttEngineState(
    status: SttEngineStatus.ready,
    message: 'Tap the microphone to start speaking.',
  );
  String? _recordingPath;

  Stream<SttEngineState> get stateStream => _stateController.stream;
  SttEngineState get currentState => _currentState;

  void _updateState(SttEngineState state) {
    _currentState = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  Future<void> startRecording() async {
    if (_currentState.isRecording || _currentState.isTranscribing) return;

    if (!await _recorder.hasPermission()) {
      const message =
          'Microphone permission is required. Enable it in device settings and try again.';
      _updateState(
        const SttEngineState(
          status: SttEngineStatus.error,
          message: message,
          error: message,
        ),
      );
      throw const SttException(message);
    }

    final tempDirectory = await getTemporaryDirectory();
    _recordingPath =
        '${tempDirectory.path}/nalam_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: _recordingPath!,
      );
      _updateState(
        const SttEngineState(
          status: SttEngineStatus.recording,
          message: 'Listening… Tap again when you are finished.',
        ),
      );
    } catch (error) {
      _setError('Could not start recording: $error');
      rethrow;
    }
  }

  Future<String> stopAndTranscribe({String languageCode = 'unknown'}) async {
    if (!_currentState.isRecording) {
      throw const SttException('No recording is in progress.');
    }

    _updateState(
      const SttEngineState(
        status: SttEngineStatus.transcribing,
        message: 'Converting your speech to text…',
      ),
    );

    String? path;
    try {
      path = await _recorder.stop() ?? _recordingPath;
      if (path == null) {
        throw const SttException('The recording was not saved.');
      }

      final file = File(path);
      if (!await file.exists() || await file.length() <= 44) {
        throw const SttException(
          'No audio was captured. Please speak after tapping the microphone.',
        );
      }

      final transcript = await _remoteAiService.transcribeAudio(
        path,
        languageCode: languageCode,
      );
      _updateState(
        const SttEngineState(
          status: SttEngineStatus.ready,
          message: 'Transcription complete. Tap to record again.',
        ),
      );
      return transcript;
    } catch (error) {
      final message = error is SttException
          ? error.message
          : 'Transcription failed: $error';
      _setError(message);
      throw SttException(message);
    } finally {
      final recordedFile = path == null ? null : File(path);
      if (recordedFile != null && await recordedFile.exists()) {
        try {
          await recordedFile.delete();
        } catch (_) {}
      }
      _recordingPath = null;
    }
  }

  Future<String?> toggleRecording({String languageCode = 'unknown'}) async {
    if (_currentState.isRecording) {
      return stopAndTranscribe(languageCode: languageCode);
    }
    await startRecording();
    return null;
  }

  void _setError(String message) {
    _updateState(
      SttEngineState(
        status: SttEngineStatus.error,
        message: message,
        error: message,
      ),
    );
  }

  Future<void> dispose() async {
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } catch (_) {}
    try {
      await _recorder.dispose();
    } catch (_) {}
    await _stateController.close();
  }
}

class SttException implements Exception {
  const SttException(this.message);
  final String message;

  @override
  String toString() => message;
}
