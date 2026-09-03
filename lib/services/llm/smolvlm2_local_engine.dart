import 'dart:async';

import 'package:llamadart/llamadart.dart';

import '../../models/llm_state.dart';
import 'smolvlm2_engine.dart';

/// On-device inference engine using llamadart (llama.cpp FFI).
/// Loads GGUF model weights directly in-process — no server required.
class SmolVlm2LocalEngine implements BaseLlmEngine {
  SmolVlm2LocalEngine();

  final StreamController<LlmEngineState> _stateController =
      StreamController<LlmEngineState>.broadcast();

  LlmEngineState _currentState = const LlmEngineState(
    status: LlmEngineStatus.uninitialized,
  );

  Completer<String>? _generationCompleter;
  StringBuffer _currentGenerationBuffer = StringBuffer();

  LlamaEngine? _engine;

  @override
  Stream<LlmEngineState> get stateStream => _stateController.stream;

  @override
  LlmEngineState get currentState => _currentState;

  void _updateState(LlmEngineState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required String mmprojPath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.loading,
        message: 'Loading on-device model weights...',
        error: null,
      ),
    );

    try {
      _engine?.dispose();
      _engine = LlamaEngine(LlamaBackend());

      final contextSize = config.nCtx;

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.loading,
          message: 'Loading language model into memory...',
        ),
      );

      await _engine!.loadModel(
        modelPath,
        modelParams: ModelParams(
          contextSize: contextSize,
          gpuLayers: ModelParams.maxGpuLayers,
        ),
      );

      bool visionOk = false;
      try {
        await _engine!.loadMultimodalProjector(mmprojPath);
        visionOk = true;
      } catch (_) {}

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.ready,
          message: visionOk
              ? 'SmolVLM2 Ready (On-Device, Vision Enabled)'
              : 'SmolVLM2 Ready (On-Device, Text Only)',
          isMultimodalReady: visionOk,
          error: null,
        ),
      );
    } catch (e) {
      final errorMessage = e.toString();
      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.error,
          message: 'Failed to load on-device model',
          error:
              'Failed to initialize local inference engine: $errorMessage. '
              'Ensure the model weights have been downloaded to local storage.',
        ),
      );
    }
  }

  @override
  Stream<String> generateStreaming({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) {
    if (_currentState.status != LlmEngineStatus.ready) {
      throw StateError(
        'Cannot generate: engine not ready (status: ${_currentState.status})',
      );
    }

    _currentGenerationBuffer = StringBuffer();
    _generationCompleter = Completer<String>();

    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.generating,
        message: 'Running on-device inference...',
        error: null,
      ),
    );

    final tokenController = StreamController<String>();

    _executeInference(
      prompt: prompt,
      imagePath: imagePath,
      config: config,
      tokenController: tokenController,
    );

    return tokenController.stream;
  }

  Future<void> _executeInference({
    required String prompt,
    String? imagePath,
    required SmolVlmConfig config,
    required StreamController<String> tokenController,
  }) async {
    try {
      final effectivePrompt = prompt.isEmpty
          ? 'Describe and analyze the supplied image.'
          : prompt;

      final List<LlamaContentPart> content = [];

      if (imagePath != null) {
        content.add(LlamaImageContent(path: imagePath));
      }
      content.add(LlamaTextContent(effectivePrompt));

      final message = LlamaChatMessage.withContent(
        role: LlamaChatRole.user,
        content: content,
      );

      final genParams = GenerationParams(
        maxTokens: config.maxTokens,
        temp: config.temperature,
        topP: config.topP,
      );

      await for (final chunk in _engine!.create(
        [message],
        params: genParams,
        enableThinking: false,
        responseFormat: config.responseFormat,
      )) {
        final token = chunk.choices.first.delta.content;
        if (token != null && token.isNotEmpty) {
          _currentGenerationBuffer.write(token);
          if (!tokenController.isClosed) {
            tokenController.add(token);
          }
        }
      }

      final fullOutput = _currentGenerationBuffer.toString().trim();

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.ready,
          message: 'Inference complete',
        ),
      );

      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.complete(fullOutput);
      }
    } catch (e) {
      final errorMessage = e.toString();

      _updateState(
        _currentState.copyWith(
          status: LlmEngineStatus.error,
          error: errorMessage,
          message: 'Inference failed',
        ),
      );

      if (!tokenController.isClosed) {
        tokenController.addError(errorMessage);
      }

      if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
        _generationCompleter!.completeError(errorMessage);
      }
    } finally {
      if (!tokenController.isClosed) {
        await tokenController.close();
      }
    }
  }

  @override
  Future<String> generate({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    generateStreaming(prompt: prompt, imagePath: imagePath, config: config);
    return _generationCompleter!.future;
  }

  @override
  Future<void> stop() async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.ready,
        message: 'Inference stopped',
      ),
    );

    if (_generationCompleter != null && !_generationCompleter!.isCompleted) {
      _generationCompleter!.complete(
        _currentGenerationBuffer.toString().trim(),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _updateState(
      _currentState.copyWith(
        status: LlmEngineStatus.disposed,
        message: 'Engine disposed',
      ),
    );

    _engine?.dispose();
    _engine = null;

    if (!_stateController.isClosed) await _stateController.close();
  }
}
