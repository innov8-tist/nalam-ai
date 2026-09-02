import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/app.dart';
import 'package:nalam_ai/models/stt_state.dart';
import 'package:nalam_ai/services/stt_service.dart';

class FakeSTTService extends STTService {
  final _controller = StreamController<SttEngineState>.broadcast();
  var _state = const SttEngineState(status: SttEngineStatus.ready, message: 'Fake STT Ready');

  @override
  SttEngineState get currentState => _state;

  @override
  Stream<SttEngineState> get stateStream => _controller.stream;

  @override
  Future<void> initialize({bool autoDownload = false}) async {
    _state = const SttEngineState(status: SttEngineStatus.ready, message: 'Fake STT Ready');
    _controller.add(_state);
  }

  @override
  Future<bool> isModelDownloaded() async => true;

  @override
  Future<String> getModelPath() async => 'fake_path.gguf';

  @override
  void dispose() {
    _controller.close();
  }
}

void main() {
  testWidgets('feature buttons update the workspace and LLM opens LLM screen',
      (tester) async {
    final fakeSttService = FakeSTTService();
    await tester.pumpWidget(NalamApp(sttService: fakeSttService));

    expect(find.text('Medical Triage Workspace'), findsOneWidget);
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('STT'), findsOneWidget);
    expect(find.text('LLM'), findsOneWidget);
    expect(find.text('MAP'), findsOneWidget);

    // Test STT button navigates to SttScreen
    await tester.tap(find.text('STT'));
    await tester.pumpAndSettle();
    expect(find.text('On-Device Speech to Text'), findsOneWidget);

    // Go back to HomeScreen
    final NavigatorState navigator = tester.state(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // Test LLM button navigates to LlmScreen
    await tester.tap(find.text('LLM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('On-Device LLM'), findsOneWidget);
    expect(find.text('Describe your symptoms...'), findsOneWidget);
  });
}
