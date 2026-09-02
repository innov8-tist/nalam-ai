import 'package:flutter/material.dart';

import '../models/llm_state.dart';
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
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    symptoms.dispose();
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
                _VoicePanel(onUseText: () => setState(() => tab = 1))
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
  const _VoicePanel({required this.onUseText});
  final VoidCallback onUseText;
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, size: 56, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        const Text(
          'Voice input is not connected yet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'The existing speech-to-text service is a placeholder. Use text input for this build.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
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
