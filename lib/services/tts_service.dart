import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/tts_state.dart';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  final StreamController<TtsEngineState> _stateController =
      StreamController<TtsEngineState>.broadcast();
  final Dio _dio = Dio();

  TtsEngineState _currentState =
      const TtsEngineState(status: TtsEngineStatus.uninitialized);

  Stream<TtsEngineState> get stateStream => _stateController.stream;
  TtsEngineState get currentState => _currentState;

  TTSService() {
    _setupTtsCallbacks();
  }

  void _setupTtsCallbacks() {
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'Speech completed',
          modelDownloaded: _currentState.modelDownloaded,
        ),
      );
    });

    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.error,
          error: 'TTS Error: $message',
        ),
      );
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'Speech cancelled',
          modelDownloaded: _currentState.modelDownloaded,
        ),
      );
    });
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _updateState(
        const TtsEngineState(status: TtsEngineStatus.checking),
      );

      // Quick initialization without waiting indefinitely
      await Future.wait([
        _flutterTts.setLanguage('en-US').timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        ),
        _flutterTts.setSpeechRate(0.5).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        ),
        _flutterTts.setPitch(1.0).timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        ),
      ], eagerError: false);

      // Check if models are already downloaded
      final modelExists = await _checkModelsExist();

      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'TTS engine ready',
          modelDownloaded: modelExists,
        ),
      );

      _isInitialized = true;
    } catch (e) {
      // Even if initialization partially fails, mark as ready
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'TTS engine ready (with warnings)',
          modelDownloaded: await _checkModelsExist(),
        ),
      );
      _isInitialized = true;
    }
  }

  Future<bool> _checkModelsExist() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/${AppConstants.piperModelsDir}');
      return modelsDir.existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> downloadModel(String modelType) async {
    try {
      _updateState(
        const TtsEngineState(
          status: TtsEngineStatus.downloading,
          message: 'Preparing download...',
        ),
      );

      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/${AppConstants.piperModelsDir}');

      if (!modelsDir.existsSync()) {
        modelsDir.createSync(recursive: true);
      }

      final (modelUrl, jsonUrl, modelName) = _getModelUrls(modelType);

      // Download model file
      await _downloadFile(modelUrl, '${modelsDir.path}/$modelName.onnx');

      // Download config file
      await _downloadFile(jsonUrl, '${modelsDir.path}/$modelName.onnx.json');

      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'Model downloaded successfully',
          modelDownloaded: true,
        ),
      );
    } catch (e) {
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.error,
          error: 'Download failed: $e',
        ),
      );
      rethrow;
    }
  }

  Future<void> _downloadFile(String url, String savePath) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          final progress = received / total;
          _updateState(
            TtsEngineState(
              status: TtsEngineStatus.downloading,
              downloadProgress: progress,
              message: 'Downloading... ${(progress * 100).toStringAsFixed(0)}%',
            ),
          );
        },
      );
    } catch (e) {
      throw Exception('Failed to download from $url: $e');
    }
  }

  (String modelUrl, String jsonUrl, String modelName) _getModelUrls(
    String modelType,
  ) {
    if (modelType == 'en-US') {
      return (
        AppConstants.piperEnglishModelUrl,
        AppConstants.piperEnglishModelJsonUrl,
        AppConstants.piperEnglishModel,
      );
    } else if (modelType == 'ml-IN') {
      return (
        AppConstants.piperMalayalamModelUrl,
        AppConstants.piperMalayalamModelJsonUrl,
        AppConstants.piperMalayalamModel,
      );
    }
    throw Exception('Unknown model type: $modelType');
  }

  Future<void> speak(String text, {String languageCode = 'en-US'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) {
      throw Exception('Text cannot be empty');
    }

    try {
      _isSpeaking = true;
      _updateState(
        const TtsEngineState(status: TtsEngineStatus.speaking),
      );

      await _flutterTts.setLanguage(languageCode).timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      await _flutterTts.speak(text).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
    } catch (e) {
      _isSpeaking = false;
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.error,
          error: 'Speaking failed: $e',
        ),
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _flutterTts.stop().timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'Stopped',
          modelDownloaded: _currentState.modelDownloaded,
        ),
      );
    } catch (e) {
      _isSpeaking = false;
      _updateState(
        TtsEngineState(
          status: TtsEngineStatus.ready,
          message: 'Stopped',
          modelDownloaded: _currentState.modelDownloaded,
        ),
      );
    }
  }

  Future<void> pause() async {
    await _flutterTts.pause().timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }

  Future<void> setLanguage(String languageCode) async {
    await _flutterTts.setLanguage(languageCode).timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0)).timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0)).timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }

  void _updateState(TtsEngineState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void dispose() {
    _flutterTts.stop();
    _stateController.close();
  }
}
