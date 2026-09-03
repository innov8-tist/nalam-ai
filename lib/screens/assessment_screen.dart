import 'dart:async';

import 'package:flutter/material.dart';

import '../models/llm_state.dart';
import '../models/stt_state.dart';
import '../services/stt_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/image_input_preview.dart';
import 'assessment_questions_screen.dart';
import 'assessment_result_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});
  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen>
    with AutomaticKeepAliveClientMixin {
  String? imagePath;
  final symptoms = TextEditingController();
  STTService? _sttService;
  StreamSubscription<SttEngineState>? _sttSubscription;
  Timer? _recordingTimer;
  SttEngineState _sttState = const SttEngineState(
    status: SttEngineStatus.ready,
    message: 'Tap the microphone to start speaking.',
  );
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sttService == null) {
      _sttService = STTService();
      _sttSubscription = _sttService!.stateStream.listen((state) {
        if (mounted) {
          setState(() => _sttState = state);
        }
      });
      // Initialize Whisper model
      _sttService!.initialize();
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _sttSubscription?.cancel();
    final service = _sttService;
    if (service != null) unawaited(service.dispose());
    symptoms.dispose();
    super.dispose();
  }

  STTService _getSttService(AppController app) {
    final existing = _sttService;
    if (existing != null) return existing;
    final service = STTService();
    _sttSubscription = service.stateStream.listen((state) {
      if (mounted) setState(() => _sttState = state);
    });
    service.initialize();
    _sttService = service;
    return service;
  }

  Future<void> _toggleVoiceInput() async {
    final app = AppScope.of(context);
    final existingService = _sttService;

    print('🎤 [VOICE] Toggle voice input called');
    print('🎤 [VOICE] Existing service: ${existingService != null}');
    print('🎤 [VOICE] Is recording: ${existingService?.currentState.isRecording ?? false}');

    final service = _getSttService(app);

    try {
      if (service.currentState.isRecording) {
        print('🎤 [VOICE] Stopping recording and transcribing...');
        await _finishVoiceInput(service, app);
      } else {
        print('🎤 [VOICE] Starting recording...');
        await service.startRecording();
        print('🎤 [VOICE] Recording started successfully');
        _recordingTimer?.cancel();
        // Sarvam's synchronous endpoint is intended for clips under 30 seconds.
        _recordingTimer = Timer(const Duration(seconds: 29), () {
          if (mounted && service.currentState.isRecording) {
            unawaited(_toggleVoiceInput());
          }
        });
      }
    } catch (error) {
      print('❌ [VOICE] Error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _finishVoiceInput(STTService service, AppController app) async {
    _recordingTimer?.cancel();
    final languageCode = app.languageCode == 'ml' ? 'ml-IN' : 'en-IN';
    final isOnlineNow = await app.refreshConnectivity();
    final transcript = await service.stopAndTranscribe(
      languageCode: languageCode,
      remoteAiService: app.remoteAiService,
      isOnline: isOnlineNow,
    );
    if (!mounted) return;
    setState(() {
      symptoms.text = transcript;
      symptoms.selection = TextSelection.collapsed(offset: transcript.length);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Speech converted to text.')));
  }

  Future<void> _analyze() async {
    final app = AppScope.of(context);
    
    // Start analysis with streaming
    final analysisFuture = app.analyze(symptoms: symptoms.text, imagePath: imagePath);
    
    // Navigate to result screen immediately to show streaming
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AssessmentResultScreen()),
      );
      // When user navigates back, force rebuild to update button state
      if (mounted) setState(() {});
    }
    
    // Wait for analysis to complete
    final ok = await analysisFuture;
    
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.assessmentError ?? 'Assessment failed.')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'How can we help you today?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const Text(
            'Describe your symptoms with text, voice, or image',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _ModelStatus(
            state: app.modelState,
            isOnline: app.isOnline,
            onInitialize: () =>
                app.llmService.initialize(autoDownload: true),
          ),
          const SizedBox(height: 18),
          // Image upload section
          ImageInputPreview(
            selectedImagePath: imagePath,
            onImageSelected: (path) => setState(() => imagePath = path),
            onImageRemoved: () => setState(() => imagePath = null),
            enabled: !app.isAnalyzing,
          ),
          const SizedBox(height: 14),
          // Text input with voice button
          TextField(
            controller: symptoms,
            minLines: 4,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: 'Symptoms description',
              hintText: 'Type or tap the microphone to speak',
              alignLabelWithHint: true,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _sttState.isTranscribing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _sttState.isRecording ? Icons.stop : Icons.mic,
                          color: _sttState.isRecording 
                              ? Colors.red 
                              : AppColors.primary,
                        ),
                        onPressed: _toggleVoiceInput,
                        tooltip: _sttState.isRecording 
                            ? 'Stop recording' 
                            : 'Start voice input',
                      ),
              ),
            ),
          ),
          if (_sttState.isRecording || _sttState.isTranscribing) ...[
            const SizedBox(height: 8),
            Text(
              _sttState.message,
              style: TextStyle(
                fontSize: 12,
                color: _sttState.hasError 
                    ? Colors.red 
                    : AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: app.isOnline
                ? 'Analyze with Server AI'
                : 'Analyze On Device',
            icon: app.isOnline
                ? Icons.cloud_outlined
                : Icons.offline_bolt,
            onPressed: app.isAnalyzing ? null : _analyze,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AssessmentQuestionsScreen(),
                ),
              ),
              child: const Text('Answer follow-up questions'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ModelStatus extends StatelessWidget {
  const _ModelStatus({
    required this.state,
    required this.isOnline,
    required this.onInitialize,
  });
  final LlmEngineState state;
  final bool isOnline;
  final VoidCallback onInitialize;
  @override
  Widget build(BuildContext context) {
    final localReady = state.isReady || state.isGenerating;
    final ready = isOnline || localReady;
    final busy =
        state.status == LlmEngineStatus.loading ||
        state.status == LlmEngineStatus.checking ||
        state.status == LlmEngineStatus.downloading;
    return SectionCard(
      padding: const EdgeInsets.all(12),
      color: ready ? AppColors.mint : null,
      child: Row(
        children: [
          if (busy && !isOnline)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              isOnline
                  ? Icons.cloud_done_outlined
                  : (ready ? Icons.offline_bolt : Icons.info_outline),
              color: ready ? AppColors.primary : AppColors.urgent,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline
                      ? 'Server AI • Higher accuracy'
                      : 'Offline AI • On-device analysis',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  isOnline
                      ? (localReady
                          ? 'Local model is ready as fallback'
                          : (state.message ?? 'Local model not downloaded/loaded'))
                      : (state.message ??
                            (localReady ? 'Model ready' : 'Model not loaded')),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (!localReady && !busy)
            TextButton(
              onPressed: onInitialize,
              child: Text(state.hasError ? 'Download / Retry' : 'Load'),
            ),
        ],
      ),
    );
  }
}
