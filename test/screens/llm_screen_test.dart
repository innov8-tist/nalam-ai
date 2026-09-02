import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/models/llm_state.dart';
import 'package:nalam_ai/screens/llm_screen.dart';
import 'package:nalam_ai/services/llm/model_manager.dart';
import 'package:nalam_ai/services/llm/smolvlm2_engine.dart';
import 'package:nalam_ai/services/llm_service.dart';

class TestLlmEngine implements BaseLlmEngine {
  final _controller = StreamController<LlmEngineState>.broadcast();
  var _state = const LlmEngineState(
    status: LlmEngineStatus.ready,
    message: 'SmolVLM2 Ready',
    isMultimodalReady: true,
  );

  @override
  LlmEngineState get currentState => _state;

  @override
  Stream<LlmEngineState> get stateStream => _controller.stream;

  void setState(LlmEngineState newState) {
    _state = newState;
    _controller.add(newState);
  }

  @override
  Future<void> initialize({
    required String modelPath,
    required String mmprojPath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    setState(
      const LlmEngineState(
        status: LlmEngineStatus.ready,
        message: 'SmolVLM2 Ready',
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
    setState(const LlmEngineState(status: LlmEngineStatus.generating));
    yield 'Triage assessment: ';
    yield 'Mild flu symptoms detected. ';
    yield 'Hydrate and monitor temperature.';
    setState(const LlmEngineState(status: LlmEngineStatus.ready));
  }

  @override
  Future<String> generate({
    required String prompt,
    String? imagePath,
    SmolVlmConfig config = const SmolVlmConfig(),
  }) async {
    return 'Triage assessment: Mild flu symptoms detected.';
  }

  @override
  Future<void> stop() async {
    setState(const LlmEngineState(status: LlmEngineStatus.ready));
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class FakeModelManager extends ModelManager {
  @override
  Future<bool> isModelDownloaded() async => true;

  @override
  Future<ModelFiles> getModelFiles() async => const ModelFiles(
    modelPath: 'test_model.gguf',
    mmprojPath: 'test_mmproj.gguf',
    isVisionAvailable: true,
  );
}

void main() {
  testWidgets(
    'LlmScreen renders all inputs, buttons and responds to submission',
    (tester) async {
      final testEngine = TestLlmEngine();
      final llmService = LLMService(
        engine: testEngine,
        modelManager: FakeModelManager(),
      );

      await tester.pumpWidget(
        MaterialApp(home: LlmScreen(llmService: llmService)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify UI components
      expect(find.text('On-Device LLM'), findsOneWidget);
      expect(find.text('Describe your symptoms...'), findsOneWidget);
      expect(find.text('Attach Image for Vision Analysis'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Model Response'), findsOneWidget);

      // Enter symptoms
      await tester.enterText(
        find.byType(TextField),
        'Severe sore throat and mild headache since yesterday',
      );
      await tester.pump();

      // Submit prompt
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify streamed response text is displayed
      expect(
        find.textContaining('Triage assessment: Mild flu symptoms'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'LlmScreen displays error alert when engine fails or weights missing',
    (tester) async {
      final testEngine = TestLlmEngine();
      final llmService = LLMService(engine: testEngine);

      await tester.pumpWidget(
        MaterialApp(home: LlmScreen(llmService: llmService)),
      );
      await tester.pump();

      testEngine.setState(
        const LlmEngineState(
          status: LlmEngineStatus.error,
          error: 'Model weights not found on device',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Engine Status Alert'), findsOneWidget);
      expect(find.text('Model weights not found on device'), findsOneWidget);
      expect(find.text('Download Model (~436MB)'), findsOneWidget);
    },
  );
}
