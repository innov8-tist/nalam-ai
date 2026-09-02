import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/demo/demo_data.dart';
import '../models/assessment_models.dart';
import '../models/llm_state.dart';
import '../services/facility_service.dart';
import '../services/llm/smolvlm2_engine.dart';
import '../services/llm_service.dart';
import '../services/triage_service.dart';

class AppController extends ChangeNotifier {
  AppController({LLMService? llmService})
    : llmService = llmService ?? LLMService() {
    _modelSubscription = this.llmService.stateStream.listen(
      (_) => notifyListeners(),
    );
  }

  final LLMService llmService;
  final session = AssessmentSession();
  final history = <AssessmentHistoryEntry>[...demoHistory];
  final _triageService = const TriageService();
  final _facilityService = const FacilityService();
  StreamSubscription<LlmEngineState>? _modelSubscription;
  String languageCode = 'en';
  bool hasSeenWelcome = false;
  bool isAnalyzing = false;
  String? assessmentError;

  LlmEngineState get modelState => llmService.currentState;

  Future<void> initialize() async {
    await _loadPreferences();
    try {
      await llmService.initialize(autoDownload: false);
    } catch (_) {}
  }

  void start() {
    hasSeenWelcome = true;
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    languageCode = value;
    notifyListeners();
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/nalam_preferences.json')
          .writeAsString(jsonEncode({'language': value}));
    } catch (_) {}
  }

  Future<void> _loadPreferences() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nalam_preferences.json');
      if (await file.exists()) {
        languageCode =
            (jsonDecode(await file.readAsString())
                    as Map<String, dynamic>)['language']
                as String? ??
            'en';
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> analyze({required String symptoms, String? imagePath}) async {
    if (symptoms.trim().isEmpty && imagePath == null) {
      assessmentError = 'Enter symptoms or select an image.';
      notifyListeners();
      return false;
    }
    if (!modelState.isReady) {
      assessmentError = modelState.hasError
          ? (modelState.error ?? 'Model failed to load.')
          : 'The on-device model is not ready yet.';
      notifyListeners();
      return false;
    }
    isAnalyzing = true;
    assessmentError = null;
    session.originalText = symptoms.trim();
    session.imagePath = imagePath;
    session.modelOutputs.clear();
    notifyListeners();
    try {
      final prompt = _triageService.buildAssessmentPrompt(
        symptoms: symptoms,
        hasImage: imagePath != null,
        answers: session.answers,
      );
      final output = await llmService.generateResponse(
        prompt,
        imagePath: imagePath,
        config: const SmolVlmConfig(
          maxTokens: 700,
          temperature: 0.1,
          responseFormat: TriageService.assessmentResponseFormat,
        ),
      );
      session.modelOutputs.add(output);
      var modelAssessment = ModelAssessment.fromRawOutput(output);
      if (!modelAssessment.isComplete) {
        final repairedOutput = await llmService.generateResponse(
          _triageService.buildRepairPrompt(
            previousOutput: output,
            symptoms: symptoms,
            hasImage: imagePath != null,
            answers: session.answers,
          ),
          imagePath: imagePath,
          config: const SmolVlmConfig(
            maxTokens: 700,
            temperature: 0.1,
            responseFormat: TriageService.assessmentResponseFormat,
          ),
        );
        session.modelOutputs.add(repairedOutput);
        final repairedAssessment = ModelAssessment.fromRawOutput(
          repairedOutput,
        );
        if (repairedAssessment.informationScore >
            modelAssessment.informationScore) {
          modelAssessment = repairedAssessment;
        }
      }
      session.modelResult = modelAssessment;
      session.triageResult = _triageService.assess(
        modelAssessment: session.modelResult!,
        symptoms: symptoms,
        answers: session.answers,
      );
      session.recommendedFacility = _facilityService.getRecommendedFacility(
        session.triageResult!,
      );
      history.insert(
        0,
        AssessmentHistoryEntry(
          timestamp: DateTime.now(),
          symptoms: symptoms.isEmpty ? 'Image assessment' : symptoms,
          severity: session.triageResult!.urgency,
        ),
      );
      return true;
    } catch (e) {
      assessmentError = 'Assessment failed: $e';
      return false;
    } finally {
      isAnalyzing = false;
      notifyListeners();
    }
  }

  void updateAnswers(Map<String, String> answers) {
    session.answers.addAll(answers);
    if (session.modelResult != null) {
      session.triageResult = _triageService.assess(
        modelAssessment: session.modelResult!,
        symptoms: session.originalText,
        answers: session.answers,
      );
      session.recommendedFacility = _facilityService.getRecommendedFacility(
        session.triageResult!,
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _modelSubscription?.cancel();
    llmService.dispose();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
