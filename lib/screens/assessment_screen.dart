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
  int tab = 0;
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
    _sttService = STTService();
    _sttService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _sttState = state);
      }
    });
    _sttService.initialize();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _sttSubscription?.cancel();
    final service = _sttService;
    if (service != null) unawaited(service.dispose());
    symptoms.dispose();
    _sttService.dispose();
    super.dispose();
  }

  STTService _getSttService(AppController app) {
    final existing = _sttService;
    if (existing != null) return existing;
    final service = STTService(app.remoteAiService);
    _sttSubscription = service.stateStream.listen((state) {
      if (mounted) setState(() => _sttState = state);
    });
    _sttService = service;
    return service;
  }

  Future<void> _toggleVoiceInput() async {
    final app = AppScope.of(context);
    final existingService = _sttService;

    if (existingService == null || !existingService.currentState.isRecording) {
      final online = app.isOnline || await app.refreshConnectivity();
      if (!mounted) return;
      if (!online) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice transcription needs a connection to the Nalam server.',
            ),
          ),
        );
        return;
      }
    }
    final service = _getSttService(app);

    try {
      if (service.currentState.isRecording) {
        await _finishVoiceInput(service, app.languageCode);
      } else {
        await service.startRecording();
        _recordingTimer?.cancel();
        // Sarvam's synchronous endpoint is intended for clips under 30 seconds.
        _recordingTimer = Timer(const Duration(seconds: 29), () {
          if (mounted && service.currentState.isRecording) {
            unawaited(_toggleVoiceInput());
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _finishVoiceInput(STTService service, String language) async {
    _recordingTimer?.cancel();
    final languageCode = language == 'ml' ? 'ml-IN' : 'en-IN';
    final transcript = await service.stopAndTranscribe(
      languageCode: languageCode,
    );
    if (!mounted) return;
    setState(() {
      symptoms.text = transcript;
      symptoms.selection = TextSelection.collapsed(offset: transcript.length);
      tab = 1;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Speech converted to text.')));
  }

  Future<void> _analyze() async {
    final app = AppScope.of(context);
    final ok = await app.analyze(symptoms: symptoms.text, imagePath: imagePath);
    if (!mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AssessmentResultScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(app.assessmentError ?? 'Assessment failed.')),
      );
    }
  }

  Future<void> _handleRecording() async {
    try {
      final transcription = await _sttService.toggleRecording();
      if (transcription != null && transcription.isNotEmpty) {
        setState(() {
          symptoms.text = transcription;
          tab = 1; // Switch to text tab to show result
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'How can we help you today?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Describe your symptoms',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.mic_none),
                    label: Text('Voice'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.notes),
                    label: Text('Text'),
                  ),
                  ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.image_outlined),
                    label: Text('Image'),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (value) =>
                    setState(() => tab = value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 22),
              _ModelStatus(
                state: app.modelState,
                isOnline: app.isOnline,
                onInitialize: () =>
                    app.llmService.initialize(autoDownload: true),
              ),
              const SizedBox(height: 18),
              if (tab == 0)
                _VoicePanel(
                  state: _sttState,
                  onMicrophonePressed: _sttState.isTranscribing
                      ? null
                      : _toggleVoiceInput,
                  onUseText: () => setState(() => tab = 1),
                )
              else ...[
                if (tab == 2) ...[
                  ImageInputPreview(
                    selectedImagePath: imagePath,
                    onImageSelected: (path) => setState(() => imagePath = path),
                    onImageRemoved: () => setState(() => imagePath = null),
                    enabled: !app.isAnalyzing,
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: symptoms,
                  minLines: 4,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Symptoms description',
                    hintText: 'Tell us what you notice, when it began, and whether it is getting worse.',
                    alignLabelWithHint: true,
                  ),
                ),
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
              ],
              const SizedBox(height: 16),
            ],
          ),
          if (app.isAnalyzing)
            Positioned.fill(
              child: LoadingOverlay(
                label: app.lastAssessmentUsedServer
                    ? 'Analyzing with server AI…'
                    : 'Analyzing locally…',
              ),
            ),
        ],
      ),
    );
  }
}

class _VoicePanel extends StatelessWidget {
  const _VoicePanel({
    required this.state,
    required this.onMicrophonePressed,
    required this.onUseText,
  });
  final SttEngineState state;
  final VoidCallback? onMicrophonePressed;
  final VoidCallback onUseText;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      children: [
        Material(
          color: state.isRecording
              ? Theme.of(context).colorScheme.errorContainer
              : AppColors.mint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onMicrophonePressed,
            child: SizedBox(
              width: 112,
              height: 112,
              child: state.isTranscribing
                  ? const Padding(
                      padding: EdgeInsets.all(38),
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(
                      state.isRecording ? Icons.stop_rounded : Icons.mic,
                      size: 56,
                      color: state.isRecording
                          ? Theme.of(context).colorScheme.error
                          : AppColors.primary,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          state.isRecording
              ? 'Recording'
              : state.isTranscribing
              ? 'Transcribing with Sarvam'
              : 'Describe your symptoms',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          state.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: state.hasError
                ? Theme.of(context).colorScheme.error
                : AppColors.muted,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onUseText,
          icon: const Icon(Icons.keyboard),
          label: const Text('Use Text Instead'),
        ),
      ],
    ),
  );
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
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  isOnline
                      ? 'Local model remains available as a fallback'
                      : (state.message ??
                            (localReady ? 'Model ready' : 'Model not loaded')),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (!isOnline && !localReady && !busy)
            TextButton(
              onPressed: onInitialize,
              child: Text(state.hasError ? 'Download / Retry' : 'Load'),
            ),
        ],
      ),
    );
  }
}
