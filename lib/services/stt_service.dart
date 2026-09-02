import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../core/constants.dart';
import '../models/stt_state.dart';

class STTService {
  STTService({
    AudioRecorder? recorder,
  })  : _recorder = recorder ?? AudioRecorder() {
    _currentState = const SttEngineState(status: SttEngineStatus.uninitialized);
  }

  final AudioRecorder _recorder;

  final StreamController<SttEngineState> _stateController =
      StreamController<SttEngineState>.broadcast();

  late SttEngineState _currentState;

  Whisper? _whisper;
  String? _recordedWavPath;

  Stream<SttEngineState> get stateStream => _stateController.stream;
  SttEngineState get currentState => _currentState;

  void _updateState(SttEngineState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Resolves the storage directory for whisper model files.
  Future<Directory> getModelDirectory() async {
    String basePath;
    try {
      if (Platform.isAndroid) {
        final supportDir = await getApplicationSupportDirectory();
        basePath = supportDir.path;
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        basePath = appDocDir.path;
      }
    } catch (_) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        basePath = appDocDir.path;
      } catch (_) {
        if (Platform.isAndroid) {
          final candidate = Directory('/data/data/com.example.nalam_ai/app_flutter');
          if (candidate.existsSync()) {
            basePath = candidate.path;
          } else {
            basePath = Directory.systemTemp.path;
          }
        } else if (Platform.isLinux || Platform.isMacOS) {
          final home = Platform.environment['HOME'] ?? '.';
          basePath = '$home/.local/share/nalam_ai';
        } else {
          basePath = Directory.systemTemp.path;
        }
      }
    }

    final modelDir = Directory('$basePath/${AppConstants.whisperModelDir}');
    if (!modelDir.existsSync()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<String> getModelPath() async {
    final dir = await getModelDirectory();
    return '${dir.path}/${AppConstants.whisperModelFileName}';
  }

  Future<bool> isModelDownloaded() async {
    final path = await getModelPath();
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 100 * 1024 * 1024) {
      return true;
    }

    // Check fallback documents directory if user previously downloaded there
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final altFile = File(
          '${docDir.path}/${AppConstants.whisperModelDir}/${AppConstants.whisperModelFileName}');
      if (altFile.existsSync() && altFile.lengthSync() > 100 * 1024 * 1024) {
        final targetDir = await getModelDirectory();
        await altFile.copy('${targetDir.path}/${AppConstants.whisperModelFileName}');
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getGgufArchitecture(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final randomAccessFile = await file.open(mode: FileMode.read);
    try {
      final headerBytes = await randomAccessFile.read(16 * 1024);
      if (headerBytes.length < 24) return null;

      // Check GGUF magic "GGUF" (0x46554747 in little endian or 'G''G''U''F')
      if (headerBytes[0] != 0x47 || headerBytes[1] != 0x47 ||
          headerBytes[2] != 0x55 || headerBytes[3] != 0x46) {
        return 'non-gguf'; // Might be legacy GGML .bin file
      }

      // Simple robust scanner for "general.architecture" key
      final keyBytes = 'general.architecture'.codeUnits;
      int keyIdx = -1;
      for (int i = 0; i <= headerBytes.length - keyBytes.length; i++) {
        bool found = true;
        for (int j = 0; j < keyBytes.length; j++) {
          if (headerBytes[i + j] != keyBytes[j]) {
            found = false;
            break;
          }
        }
        if (found) {
          keyIdx = i;
          break;
        }
      }

      if (keyIdx != -1) {
        int typeIdx = keyIdx + keyBytes.length;
        if (typeIdx + 4 < headerBytes.length) {
          final type = headerBytes[typeIdx] |
                       (headerBytes[typeIdx + 1] << 8) |
                       (headerBytes[typeIdx + 2] << 16) |
                       (headerBytes[typeIdx + 3] << 24);

          if (type == 8) { // GGUF_TYPE_STRING is 8
            int valStrLenIdx = typeIdx + 4;
            if (valStrLenIdx + 8 < headerBytes.length) {
              int valLen = 0;
              for (int i = 0; i < 8; i++) {
                valLen |= (headerBytes[valStrLenIdx + i] << (8 * i));
              }
              int valStart = valStrLenIdx + 8;
              if (valStart + valLen <= headerBytes.length) {
                final valBytes = headerBytes.sublist(valStart, valStart + valLen);
                return String.fromCharCodes(valBytes);
              }
            }
          }
        }
      }
    } catch (_) {
      // ignore
    } finally {
      await randomAccessFile.close();
    }
    return null;
  }

  Future<void> _ensureModelLinked(Directory dir) async {
    final actualPath = '${dir.path}/${AppConstants.whisperModelFileName}';
    final actualFile = File(actualPath);

    if (actualFile.existsSync()) {
      // Validate model architecture before copying/linking or using it
      final arch = await getGgufArchitecture(actualPath);
      if (arch != null && arch != 'non-gguf' && arch != 'whisper') {
        throw Exception(
          'Incompatible model architecture: "$arch". On-device STT requires a "whisper" model.',
        );
      }

      // For legacy GGML .bin files, link to expected name
      final expectedPath = '${dir.path}/ggml-tiny.bin';
      final expectedFile = File(expectedPath);
      if (!expectedFile.existsSync() || expectedFile.lengthSync() != actualFile.lengthSync()) {
        if (expectedFile.existsSync()) {
          try {
            await expectedFile.delete();
          } catch (_) {}
        }
        try {
          await actualFile.copy(expectedPath);
        } catch (_) {}
      }
    }
  }

  /// Initializes the STT Engine
  Future<void> initialize({bool autoDownload = false}) async {
    _updateState(
      _currentState.copyWith(
        status: SttEngineStatus.checking,
        message: 'Checking on-device STT weights...',
        error: null,
      ),
    );

    try {
      final isDownloaded = await isModelDownloaded();

      if (!isDownloaded) {
        if (autoDownload) {
          await downloadModel();
          return;
        } else {
          _updateState(
            _currentState.copyWith(
              status: SttEngineStatus.error,
              message: 'STT model weights not found on device',
              error:
          'Whisper Tiny model not found in storage. Tap "Download Model" to download the model once for offline edge transcription.',
            ),
          );
          return;
        }
      }

      final dir = await getModelDirectory();
      await _ensureModelLinked(dir);
      _whisper = Whisper(
        model: WhisperModel.tiny,
        modelDir: dir.path,
      );

      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.ready,
          message: 'Whisper Tiny STT Ready (On-Device)',
        ),
      );
    } catch (e) {
      if (e.toString().contains('Incompatible model architecture')) {
        _updateState(
          _currentState.copyWith(
            status: SttEngineStatus.ready,
            message: 'STT Ready (API Fallback Mode - Incompatible GGUF)',
          ),
        );
        return;
      }
      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.error,
          message: 'STT Initialization failed',
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Downloads the Whisper small model with multi-mirror support & automatic retry
  Future<void> downloadModel() async {
    _updateState(
      _currentState.copyWith(
        status: SttEngineStatus.downloading,
        message: 'Connecting to model repository...',
        downloadProgress: 0.0,
        error: null,
      ),
    );

    try {
      final dir = await getModelDirectory();
      final destinationPath = '${dir.path}/${AppConstants.whisperModelFileName}';

      final urls = [
        AppConstants.whisperModelDownloadUrl,
        AppConstants.whisperModelMirrorDownloadUrl,
      ];

      Object? lastError;
      bool succeeded = false;

      for (final url in urls) {
        for (var attempt = 1; attempt <= 2; attempt++) {
          try {
            _updateState(
              _currentState.copyWith(
                status: SttEngineStatus.downloading,
                message: 'Connecting to download server...',
              ),
            );

            await _downloadFile(
              url: url,
              destinationPath: destinationPath,
              fileName: AppConstants.whisperModelFileName,
              onProgress: (progressFraction, message) {
                _updateState(
                  _currentState.copyWith(
                    status: SttEngineStatus.downloading,
                    downloadProgress: progressFraction,
                    message: message,
                  ),
                );
              },
            );
            succeeded = true;
            break;
          } catch (e) {
            lastError = e;
            if (kDebugMode) {
              debugPrint('Download attempt failed for $url: $e');
            }
            await Future<void>.delayed(const Duration(milliseconds: 800));
          }
        }
        if (succeeded) break;
      }

      if (!succeeded) {
        throw lastError ?? Exception('Failed to connect to model servers.');
      }

      await _ensureModelLinked(dir);
      _whisper = Whisper(
        model: WhisperModel.tiny,
        modelDir: dir.path,
      );

      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.ready,
          message: 'Whisper Tiny STT Ready (On-Device)',
          downloadProgress: 1.0,
        ),
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Incompatible model architecture')) {
        _updateState(
          _currentState.copyWith(
            status: SttEngineStatus.ready,
            message: 'STT Ready (API Fallback Mode - Incompatible GGUF)',
            downloadProgress: 1.0,
          ),
        );
        return;
      }
      if (errorMessage.contains('SocketException') ||
          errorMessage.contains('Failed host lookup') ||
          errorMessage.contains('errno = 7')) {
        errorMessage =
            'Network error connecting to download server. Please ensure device has an active internet connection and restart app.';
      }
      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.error,
          message: 'STT Download failed',
          error: errorMessage,
        ),
      );
      rethrow;
    }
  }

  Future<void> _downloadFile({
    required String url,
    required String destinationPath,
    required String fileName,
    required void Function(double progress, String message) onProgress,
  }) async {
    final tempPath = '$destinationPath.tmp';
    final tempFile = File(tempPath);

    int resumeOffset = 0;
    if (tempFile.existsSync()) {
      resumeOffset = tempFile.lengthSync();
    }

    final client = http.Client();
    IOSink? sink;

    try {
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = true;
      request.maxRedirects = 10;
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

      if (resumeOffset > 0) {
        request.headers['Range'] = 'bytes=$resumeOffset-';
      }

      final response = await client.send(request);

      var receivedBytes = 0;
      if (response.statusCode == 206 && resumeOffset > 0) {
        sink = tempFile.openWrite(mode: FileMode.append);
        receivedBytes = resumeOffset;
      } else if (response.statusCode == 200) {
        if (resumeOffset > 0 && tempFile.existsSync()) {
          tempFile.deleteSync();
        }
        sink = tempFile.openWrite();
      } else if (response.statusCode == 416 && resumeOffset > 0) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        client.close();
        return await _downloadFile(
          url: url,
          destinationPath: destinationPath,
          fileName: fileName,
          onProgress: onProgress,
        );
      } else {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final contentLength = response.contentLength ?? 0;
      final totalBytes = response.statusCode == 206
          ? resumeOffset + contentLength
          : (contentLength > 0 ? contentLength : -1);

      var lastProgressUpdate = DateTime.now();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastProgressUpdate).inMilliseconds >= 100 ||
            (totalBytes > 0 && receivedBytes >= totalBytes)) {
          lastProgressUpdate = now;
          final fraction =
              totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
          final receivedMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = totalBytes > 0
              ? '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : 'calculating...';

          onProgress(
            fraction,
            'Downloading $fileName: $receivedMb MB / $totalMb (${(fraction * 100).toStringAsFixed(0)}%)',
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (File(destinationPath).existsSync()) {
        await File(destinationPath).delete();
      }
      await tempFile.rename(destinationPath);
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }

  /// Toggles recording on and off. Returns the transcription if recording was stopped.
  Future<String?> toggleRecording({String language = 'auto'}) async {
    if (_currentState.status == SttEngineStatus.recording) {
      return await stopRecording(language: language);
    } else if (_currentState.status == SttEngineStatus.ready) {
      await startRecording();
    }
    return null;
  }

  /// Starts audio recording
  Future<void> startRecording() async {
    if (_currentState.status != SttEngineStatus.ready) {
      throw StateError('STT Engine is not ready.');
    }

    if (!await _recorder.hasPermission()) {
      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.error,
          message: 'Microphone permission denied',
          error: 'Please grant microphone permissions in settings to use speech-to-text.',
        ),
      );
      throw Exception('Microphone permission denied');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordedWavPath = '${tempDir.path}/whisper_recording.wav';

      final file = File(_recordedWavPath!);
      if (file.existsSync()) {
        await file.delete();
      }

      // Configure recorder for 16kHz, mono, 16-bit PCM WAV as Whisper expects
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _recorder.start(recordConfig, path: _recordedWavPath!);

      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.recording,
          message: 'Recording audio... Tap button again to stop.',
        ),
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.error,
          message: 'Failed to start recording',
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Stops recording and transcribes the audio
  Future<String> stopRecording({String language = 'auto'}) async {
    if (_currentState.status != SttEngineStatus.recording) {
      throw StateError('Not currently recording.');
    }

    _updateState(
      _currentState.copyWith(
        status: SttEngineStatus.transcribing,
        message: 'Stopping recorder...',
      ),
    );

    try {
      final path = await _recorder.stop();
      if (path == null || _recordedWavPath == null) {
        throw Exception('Failed to save recorded audio.');
      }

      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.transcribing,
          message: 'Transcribing audio... Please wait.',
        ),
      );

      if (_whisper == null) {
        _updateState(
          _currentState.copyWith(
            status: SttEngineStatus.transcribing,
            message: 'Transcribing via API server...',
          ),
        );
        try {
          final text = await _transcribeViaApi(_recordedWavPath!, language);
          _updateState(
            _currentState.copyWith(
              status: SttEngineStatus.ready,
              message: 'STT Ready (API Fallback)',
            ),
          );
          return text;
        } catch (apiError) {
          throw Exception(
            'STT local engine is not initialized (incompatible model). '
            'Attempted API transcription fallback at ${Platform.isAndroid ? AppConstants.sttAndroidEmulatorApiUrl : AppConstants.sttDefaultApiUrl} but failed: $apiError'
          );
        }
      }

      final response = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: _recordedWavPath!,
          language: language,
        ),
      );

      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.ready,
          message: 'Whisper Tiny STT Ready (On-Device)',
        ),
      );

      return response.text;
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: SttEngineStatus.error,
          message: 'Transcription failed',
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<String> _transcribeViaApi(String filePath, String language) async {
    final uri = Uri.parse(Platform.isAndroid
        ? AppConstants.sttAndroidEmulatorApiUrl
        : AppConstants.sttDefaultApiUrl);

    final request = http.MultipartRequest('POST', uri)
      ..fields['model'] = AppConstants.whisperModelFileName
      ..fields['language'] = language
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      return jsonMap['text'] as String? ?? '';
    } else {
      throw HttpException('Server returned status code ${response.statusCode}: ${response.body}');
    }
  }

  /// Legacy method required by existing interface/triage implementation.
  Future<String> listen() async {
    await initialize(autoDownload: true);
    await startRecording();
    throw UnimplementedError('Please use toggleRecording and stream currentState instead.');
  }

  void dispose() {
    _recorder.dispose();
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
