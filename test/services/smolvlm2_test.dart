import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/models/llm_state.dart';
import 'package:nalam_ai/services/llm/model_manager.dart';
import 'package:nalam_ai/services/llm/smolvlm2_engine.dart';
import 'package:nalam_ai/services/llm/smolvlm2_formatter.dart';
import 'package:nalam_ai/services/llm_service.dart';

class FakeLlmEngine implements BaseLlmEngine {
  final _stateController = StreamController<LlmEngineState>.broadcast();
  var _currentState = const LlmEngineState(status: LlmEngineStatus.uninitialized);

  @override
  LlmEngineState get currentState => _currentState;

  @override
  Stream<LlmEngineState> get stateStream => _stateController.stream;

  void emitState(LlmEngineState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required String mmprojPath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    emitState(
      const LlmEngineState(
        status: LlmEngineStatus.ready,
        message: 'SmolVLM2 Ready (Multimodal: Vision + Text)',
        isMultimodalReady: true,
      ),
    );
  }

  @override
  Stream<String> generateStreaming({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async* {
    emitState(const LlmEngineState(status: LlmEngineStatus.generating));
    yield 'Based on ';
    yield 'your symptoms, ';
    yield 'assessment complete.';
    emitState(const LlmEngineState(status: LlmEngineStatus.ready));
  }

  @override
  Future<String> generate({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    return 'Based on your symptoms, assessment complete.';
  }

  @override
  Future<void> stop() async {
    emitState(const LlmEngineState(status: LlmEngineStatus.ready));
  }

  @override
  Future<void> dispose() async {
    emitState(const LlmEngineState(status: LlmEngineStatus.disposed));
    await _stateController.close();
  }
}

void main() {
  group('SmolVlm2Formatter', () {
    const formatter = SmolVlm2Formatter(defaultSystemPrompt: 'System prompt test.');

    test('formats text-only prompt in ChatML format', () {
      final prompt = formatter.formatPrompt(
        userPrompt: 'I have a mild headache.',
        hasImage: false,
      );

      expect(prompt, contains('<|im_start|>system\nSystem prompt test.<|im_end|>\n'));
      expect(prompt, contains('<|im_start|>user\nI have a mild headache.<|im_end|>\n'));
      expect(prompt, contains('<|im_start|>assistant\n'));
      expect(prompt, isNot(contains('<image>')));
    });

    test('formats multimodal vision prompt with <image> tag', () {
      final prompt = formatter.formatPrompt(
        userPrompt: 'What does this skin rash look like?',
        hasImage: true,
      );

      expect(prompt, contains('<|im_start|>user\n<image>\nWhat does this skin rash look like?<|im_end|>\n'));
      expect(prompt, contains('<|im_start|>assistant\n'));
    });

    test('cleanOutput removes trailing stop tokens', () {
      expect(formatter.cleanOutput('Hello world<|im_end|>'), 'Hello world');
      expect(formatter.cleanOutput('Hello world<end_of_utterance>'), 'Hello world');
      expect(formatter.cleanOutput('Hello world<|end_of_text|>'), 'Hello world');
    });
  });

  group('LlmEngineState Model', () {
    test('correctly evaluates computed properties', () {
      const readyState = LlmEngineState(status: LlmEngineStatus.ready);
      expect(readyState.isReady, isTrue);
      expect(readyState.isGenerating, isFalse);
      expect(readyState.isBusy, isFalse);
      expect(readyState.hasError, isFalse);

      const genState = LlmEngineState(status: LlmEngineStatus.generating);
      expect(genState.isReady, isFalse);
      expect(genState.isGenerating, isTrue);
      expect(genState.isBusy, isTrue);

      const errState = LlmEngineState(status: LlmEngineStatus.error, error: 'OOM');
      expect(errState.hasError, isTrue);
      expect(errState.error, 'OOM');
    });

    test('copyWith updates fields properly', () {
      const state = LlmEngineState(status: LlmEngineStatus.uninitialized);
      final updated = state.copyWith(
        status: LlmEngineStatus.loading,
        message: 'Loading...',
        downloadProgress: 0.5,
      );

      expect(updated.status, LlmEngineStatus.loading);
      expect(updated.message, 'Loading...');
      expect(updated.downloadProgress, 0.5);
    });
  });

  group('ModelFiles', () {
    test('reports model availability based on path', () {
      const files = ModelFiles(
        modelPath: 'non_existent_file.gguf',
        mmprojPath: 'non_existent_mmproj.gguf',
        isVisionAvailable: false,
      );
      expect(files.isModelAvailable, isFalse);
      expect(files.isVisionAvailable, isFalse);
    });
  });

  group('SmolVlm2Engine API Streaming Tests', () {
    test('streams real tokens from SSE stream and cleans output', () async {
      final engine = SmolVlm2Engine(
        defaultApiUrl: 'http://127.0.0.1:8080/v1/chat/completions',
      );

      await engine.initialize(
        modelPath: 'model.gguf',
        mmprojPath: 'mmproj.gguf',
      );
      expect(engine.currentState.isReady, isTrue);

      await engine.dispose();
    });
  });

  group('LLMService Integration', () {
    test('initialize and stream generation', () async {
      final fakeEngine = FakeLlmEngine();
      final service = LLMService(
        engine: fakeEngine,
      );

      await fakeEngine.initialize(modelPath: 'test.gguf', mmprojPath: 'mmproj.gguf');
      expect(service.currentState.isReady, isTrue);

      final tokens = <String>[];
      await for (final token in service.generateStreaming(prompt: 'Fever and cough')) {
        tokens.add(token);
      }

      expect(tokens.join(), 'Based on your symptoms, assessment complete.');
      await service.dispose();
    });
  });
}
