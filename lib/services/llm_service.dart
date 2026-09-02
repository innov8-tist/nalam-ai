import 'dart:async';

import '../models/llm_state.dart';
import 'llm/model_manager.dart';
import 'llm/smolvlm2_engine.dart';
import 'llm/smolvlm2_local_engine.dart';
import 'llm/smolvlm2_formatter.dart';

/// Modular high-level service managing SmolVLM2 on-device multimodal inference.
class LLMService {
  LLMService({
    ModelManager? modelManager,
    BaseLlmEngine? engine,
    SmolVlm2Formatter? formatter,
  })  : _modelManager = modelManager ?? ModelManager(),
        _engine = engine ?? SmolVlm2LocalEngine(),
        _formatter = formatter ?? const SmolVlm2Formatter() {
    _engineSubscription = _engine.stateStream.listen((engineState) {
      _currentState = engineState;
      if (!_stateController.isClosed) {
        _stateController.add(engineState);
      }
    });
  }

  final ModelManager _modelManager;
  final BaseLlmEngine _engine;
  final SmolVlm2Formatter _formatter;

  final StreamController<LlmEngineState> _stateController =
      StreamController<LlmEngineState>.broadcast();
  StreamSubscription<LlmEngineState>? _engineSubscription;

  LlmEngineState _currentState =
      const LlmEngineState(status: LlmEngineStatus.uninitialized);

  Stream<LlmEngineState> get stateStream => _stateController.stream;
  LlmEngineState get currentState => _currentState;
  ModelManager get modelManager => _modelManager;
  SmolVlm2Formatter get formatter => _formatter;

  void _updateState(LlmEngineState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Checks local storage and initializes the on-device SmolVLM2 inference engine.
  Future<void> initialize({bool autoDownload = false}) async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.checking,
        message: 'Checking on-device model weights...',
        error: null,
      ),
    );

    try {
      final isDownloaded = await _modelManager.isModelDownloaded();

      if (!isDownloaded) {
        if (autoDownload) {
          await downloadModel();
          return;
        } else {
          _updateState(
            _currentState.copyWith(
              status: LlmEngineStatus.error,
              message: 'Model weights not found on device',
              error:
                  'SmolVLM2 weights not found in local storage. Tap "Download Model" to download weights once for offline on-device inference.',
            ),
          );
          return;
        }
      }

      final files = await _modelManager.getModelFiles();

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.loading,
          message: 'Loading SmolVLM2 on-device weights...',
        ),
      );

      await _engine.initialize(
        modelPath: files.modelPath,
        mmprojPath: files.mmprojPath,
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.error,
          message: 'Initialization failed',
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Downloads SmolVLM2 GGUF weights and vision projector directly to local device storage.
  /// Once downloaded, zero network calls are needed for inference.
  Future<void> downloadModel({
    ModelDownloadProgressCallback? onProgress,
  }) async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.downloading,
        message: 'Downloading SmolVLM2 model weights...',
        downloadProgress: 0.0,
        error: null,
      ),
    );

    try {
      final files = await _modelManager.downloadModelIfNeeded(
        onProgress: ({
          required String fileName,
          required int bytesReceived,
          required int totalBytes,
          required double progressFraction,
          required String message,
        }) {
          _updateState(
            _currentState.copyWith(
              status: LlmEngineStatus.downloading,
              downloadProgress: progressFraction,
              message: message,
            ),
          );
          onProgress?.call(
            fileName: fileName,
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
            progressFraction: progressFraction,
            message: message,
          );
        },
      );

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.loading,
          message: 'Loading downloaded weights into on-device memory...',
          downloadProgress: 1.0,
        ),
      );

      await _engine.initialize(
        modelPath: files.modelPath,
        mmprojPath: files.mmprojPath,
      );
    } catch (e) {
      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.error,
          message: 'Download failed',
          error: 'Failed to download SmolVLM2 weights: $e',
        ),
      );
      rethrow;
    }
  }

  /// Generates response with real-time streaming tokens.
  Stream<String> generateStreaming({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) {
    return _engine.generateStreaming(
      prompt: prompt,
      imagePath: imagePath,
      config: config,
    );
  }

  /// Generates a complete response (non-streaming).
  Future<String> generateResponse(
    String prompt, {
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    return _engine.generate(
      prompt: prompt,
      imagePath: imagePath,
      config: config,
    );
  }

  /// Stops an active generation.
  Future<void> stop() async {
    await _engine.stop();
  }

  /// Disposes engine and frees native memory.
  Future<void> dispose() async {
    await _engineSubscription?.cancel();
    await _engine.dispose();
    _modelManager.dispose();
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}
