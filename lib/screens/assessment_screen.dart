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
  late final STTService _sttService;
  SttEngineState _sttState = const SttEngineState(
    status: SttEngineStatus.uninitialized,
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
    symptoms.dispose();
    _sttService.dispose();
    super.dispose();
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
                  sttState: _sttState,
                  onRecord: _handleRecording,
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
    required this.sttState,
    required this.onRecord,
    required this.onUseText,
  });
  final SttEngineState sttState;
  final VoidCallback onRecord;
  final VoidCallback onUseText;

  @override
  Widget build(BuildContext context) {
    final isRecording = sttState.status == SttEngineStatus.recording;
    final isTranscribing = sttState.status == SttEngineStatus.transcribing;
    final isReady = sttState.status == SttEngineStatus.ready;
    final hasError = sttState.status == SttEngineStatus.error;

    return SectionCard(
      child: Column(
        children: [
          InkWell(
            onTap: isReady || isRecording ? onRecord : null,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: isRecording
                    ? AppColors.urgent.withOpacity(0.2)
                    : AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isRecording)
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.urgent.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    size: 56,
                    color: isRecording ? AppColors.urgent : AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isRecording
                ? 'Recording... Tap to stop'
                : isTranscribing
                    ? 'Transcribing...'
                    : isReady
                        ? 'Tap to record your symptoms'
                        : hasError
                            ? 'Speech-to-text error'
                            : 'Initializing...',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            sttState.message ?? 'Loading speech recognition...',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (hasError) ...[
            const SizedBox(height: 14),
            Text(
              sttState.error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.urgent, fontSize: 12),
            ),
          ],
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
