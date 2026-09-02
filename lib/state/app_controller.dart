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
import '../services/remote_ai_service.dart';
import '../services/triage_service.dart';

class AppController extends ChangeNotifier {
  AppController({LLMService? llmService, RemoteAiService? remoteAiService})
    : llmService = llmService ?? LLMService(),
      remoteAiService = remoteAiService ?? RemoteAiService() {
    _modelSubscription = this.llmService.stateStream.listen(
      (_) => notifyListeners(),
    );
  }

  final LLMService llmService;
  final RemoteAiService remoteAiService;
  final session = AssessmentSession();
  final history = <AssessmentHistoryEntry>[...demoHistory];
  final _triageService = const TriageService();
  final _facilityService = const FacilityService();
  StreamSubscription<LlmEngineState>? _modelSubscription;
  Timer? _connectivityTimer;
  bool _isDisposed = false;
  final Map<String, dynamic> _preferences = {};
  String languageCode = 'en';
  bool hasSeenWelcome = false;
  bool isAnalyzing = false;
  String? assessmentError;
  bool isOnline = false;
  bool isCheckingConnection = false;
  bool lastAssessmentUsedServer = false;

  LlmEngineState get modelState => llmService.currentState;
  String get serverUrl => remoteAiService.baseUri.toString();

  Future<void> initialize() async {
    await _loadPreferences();
    if (_isDisposed) return;
    await Future.wait([refreshConnectivity(), _initializeLocalModel()]);
    if (_isDisposed) return;
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => refreshConnectivity(),
    );
  }

  Future<void> _initializeLocalModel() async {
    try {
      await llmService.initialize(autoDownload: false);
    } catch (_) {}
  }

  Future<bool> refreshConnectivity() async {
    if (_isDisposed) return false;
    if (isCheckingConnection) return isOnline;
    isCheckingConnection = true;
    notifyListeners();
    final available = await remoteAiService.isAvailable();
    if (_isDisposed) return false;
    final changed = available != isOnline;
    isOnline = available;
    isCheckingConnection = false;
    if (changed || hasListeners) notifyListeners();
    return available;
  }

  void start() {
    hasSeenWelcome = true;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    languageCode = value;
    notifyListeners();
    _preferences['language'] = value;
    await _savePreferences();
  }

  Future<bool> setRemoteServerUrl(String value) async {
    assessmentError = null;
    try {
      remoteAiService.setBaseUrl(value);
    } on FormatException catch (error) {
      assessmentError = error.message;
      notifyListeners();
      return false;
    }
    _preferences['server_url'] = serverUrl;
    isOnline = false;
    notifyListeners();
    await _savePreferences();
    final available = await refreshConnectivity();
    if (!available) {
      assessmentError = 'Could not reach $serverUrl/health';
      notifyListeners();
    }
    return available;
  }

  Future<void> _loadPreferences() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nalam_preferences.json');
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _preferences.addAll(Map<String, dynamic>.from(decoded));
        }
        languageCode = _preferences['language'] as String? ?? 'en';
        final savedServerUrl = _preferences['server_url'] as String?;
        if (savedServerUrl != null) remoteAiService.setBaseUrl(savedServerUrl);
      }
    } catch (_) {}
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _savePreferences() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/nalam_preferences.json')
          .writeAsString(jsonEncode(_preferences));
    } catch (_) {}
  }

  Future<bool> analyze({required String symptoms, String? imagePath}) async {
    if (symptoms.trim().isEmpty && imagePath == null) {
      assessmentError = 'Enter symptoms or select an image.';
      notifyListeners();
      return false;
    }
    if (!isOnline) await refreshConnectivity();
    if (!isOnline && !modelState.isReady) return _reportNoInferenceAvailable();
    isAnalyzing = true;
    lastAssessmentUsedServer = isOnline;
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
      final output = await _generateWithFallback(prompt, imagePath: imagePath);
      session.modelOutputs.add(output);
      var modelAssessment = ModelAssessment.fromRawOutput(output);
      if (!modelAssessment.isComplete) {
        try {
          final repairedOutput = await _generateWithFallback(
            _triageService.buildRepairPrompt(
              previousOutput: output,
              symptoms: symptoms,
              hasImage: imagePath != null,
              answers: session.answers,
            ),
            imagePath: imagePath,
          );
          session.modelOutputs.add(repairedOutput);
          final repairedAssessment = ModelAssessment.fromRawOutput(
            repairedOutput,
          );
          if (repairedAssessment.informationScore >
              modelAssessment.informationScore) {
            modelAssessment = repairedAssessment;
          }
        } catch (_) {
          // Keep the first usable response if connectivity drops during repair.
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

  bool _reportNoInferenceAvailable() {
    assessmentError = modelState.hasError
        ? 'Server unavailable and the local model is not ready. ${modelState.error ?? ''}'
        : 'Server unavailable and the on-device model is not ready yet.';
    notifyListeners();
    return false;
  }

  Future<String> _generateWithFallback(
    String prompt, {
    String? imagePath,
  }) async {
    if (isOnline) {
      try {
        final output = await remoteAiService.generateResponse(
          prompt,
          imagePath: imagePath,
        );
        lastAssessmentUsedServer = true;
        return output;
      } catch (_) {
        isOnline = false;
        lastAssessmentUsedServer = false;
        notifyListeners();
      }
    }
    if (!modelState.isReady) {
      throw StateError(
        'The server became unavailable and the local model is not ready.',
      );
    }
    return llmService.generateResponse(
      prompt,
      imagePath: imagePath,
      config: const SmolVlmConfig(
        maxTokens: 700,
        temperature: 0.1,
        responseFormat: TriageService.assessmentResponseFormat,
      ),
    );
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
    _isDisposed = true;
    _connectivityTimer?.cancel();
    _modelSubscription?.cancel();
    llmService.dispose();
    remoteAiService.dispose();
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
