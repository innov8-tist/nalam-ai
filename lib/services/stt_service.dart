import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../models/stt_state.dart';
import 'remote_ai_service.dart';

/// Records voice and transcribes using local Whisper model
class STTService {
  STTService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  Whisper? _whisper;
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

  Future<void> initialize() async {
    try {
      print('🎤 [STT] Initializing Whisper...');
      
      // Get app directory for storing models
      final appDir = await getApplicationDocumentsDirectory();
      
      // Initialize Whisper with base model
      // The package will auto-download on first use
      _whisper = Whisper(
        model: WhisperModel.base,
        modelDir: appDir.path,
      );
      
      print('🎤 [STT] Whisper initialized successfully');
      
      _updateState(
        const SttEngineState(
          status: SttEngineStatus.ready,
          message: 'Tap the microphone to start speaking.',
        ),
      );
    } catch (error) {
      print('❌ [STT] Initialization error: $error');
      _updateState(
        SttEngineState(
          status: SttEngineStatus.error,
          message: 'Failed to initialize Whisper',
          error: error.toString(),
        ),
      );
    }
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

  Future<String> stopAndTranscribe({
    String languageCode = 'unknown',
    RemoteAiService? remoteAiService,
    bool isOnline = false,
  }) async {
    if (!_currentState.isRecording) {
      throw const SttException('No recording is in progress.');
    }

    _updateState(
      SttEngineState(
        status: SttEngineStatus.transcribing,
        message: isOnline && remoteAiService != null
            ? 'Transcribing with remote Sarvam STT…'
            : 'Transcribing with local Whisper model…',
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

      if (isOnline && remoteAiService != null) {
        try {
          print('🎤 [STT] Transcribing audio file remotely: $path');
          final transcript = await remoteAiService.transcribeAudio(
            path,
            languageCode: languageCode,
          );
          print('🎤 [STT] Remote transcription result: $transcript');
          _updateState(
            const SttEngineState(
              status: SttEngineStatus.ready,
              message: 'Transcription complete. Tap to record again.',
            ),
          );
          return transcript;
        } catch (error) {
          print('❌ [STT] Remote transcription failed, falling back to local Whisper: $error');
          _updateState(
            const SttEngineState(
              status: SttEngineStatus.transcribing,
              message: 'Remote transcription failed. Falling back to local Whisper…',
            ),
          );
        }
      }

      if (_whisper == null) {
        throw const SttException('Whisper model not initialized');
      }

      print('🎤 [STT] Transcribing audio file locally: $path');
      
      // Create transcribe request
      final request = TranscribeRequest(
        audio: path,
        language: languageCode == 'ml-IN' ? 'ml' : 'en',
        isTranslate: false,
        isNoTimestamps: true,
        threads: 4,
      );
      
      // Transcribe with Whisper
      final response = await _whisper!.transcribe(transcribeRequest: request);
      final transcript = response.text.trim();
      
      print('🎤 [STT] Local transcription result: $transcript');
      
      if (transcript.isEmpty) {
        throw const SttException(
          'No speech was recognized. Please try speaking more clearly.',
        );
      }
      
      _updateState(
        const SttEngineState(
          status: SttEngineStatus.ready,
          message: 'Transcription complete. Tap to record again.',
        ),
      );
      return transcript;
    } catch (error) {
      print('❌ [STT] Transcription error: $error');
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

  Future<String?> toggleRecording({
    String languageCode = 'unknown',
    RemoteAiService? remoteAiService,
    bool isOnline = false,
  }) async {
    if (_currentState.isRecording) {
      return stopAndTranscribe(
        languageCode: languageCode,
        remoteAiService: remoteAiService,
        isOnline: isOnline,
      );
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
