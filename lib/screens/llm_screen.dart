import 'dart:async';

import 'package:flutter/material.dart';

import '../models/llm_state.dart';
import '../services/llm_service.dart';
import '../widgets/image_input_preview.dart';

class LlmScreen extends StatefulWidget {
  const LlmScreen({
    this.llmService,
    super.key,
  });

  final LLMService? llmService;

  @override
  State<LlmScreen> createState() => _LlmScreenState();
}

class _LlmScreenState extends State<LlmScreen> {
  late final LLMService _llmService;
  late final TextEditingController _symptomController;

  String? _selectedImagePath;
  String _responseBuffer = '';
  LlmEngineState _engineState =
      const LlmEngineState(status: LlmEngineStatus.uninitialized);

  StreamSubscription<LlmEngineState>? _stateSubscription;
  StreamSubscription<String>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _symptomController = TextEditingController();
    _llmService = widget.llmService ?? LLMService();

    _engineState = _llmService.currentState;
    _stateSubscription = _llmService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _engineState = state;
        });
      }
    });

    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    try {
      await _llmService.initialize(autoDownload: true);
    } catch (_) {
      // Error is surfaced via _engineState
    }
  }

  Future<void> _downloadModel() async {
    try {
      await _llmService.downloadModel();
    } catch (_) {
      // Surfaced in UI via state
    }
  }

  void _submitPrompt() {
    final text = _symptomController.text.trim();
    if (text.isEmpty && _selectedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your symptoms or attach an image.'),
        ),
      );
      return;
    }

    setState(() {
      _responseBuffer = '';
    });

    _tokenSubscription?.cancel();
    _tokenSubscription = _llmService
        .generateStreaming(
      prompt: text.isEmpty
          ? 'Analyze the attached medical image and describe findings.'
          : text,
      imagePath: _selectedImagePath,
    )
        .listen(
      (token) {
        if (mounted) {
          setState(() {
            _responseBuffer += token;
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Inference error: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
    );
  }

  Future<void> _stopGeneration() async {
    await _llmService.stop();
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _stateSubscription?.cancel();
    _symptomController.dispose();
    if (widget.llmService == null) {
      _llmService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGenerating = _engineState.isGenerating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device LLM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reinitialize model',
            onPressed: isGenerating ? null : _initializeEngine,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEngineStatusCard(colorScheme),
            const SizedBox(height: 16),
            TextField(
              controller: _symptomController,
              enabled: !isGenerating,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Describe your symptoms...',
                labelText: 'Symptoms Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh,
              ),
            ),
            const SizedBox(height: 12),
            ImageInputPreview(
              selectedImagePath: _selectedImagePath,
              enabled: !isGenerating,
              onImageSelected: (path) {
                setState(() {
                  _selectedImagePath = path;
                });
              },
              onImageRemoved: () {
                setState(() {
                  _selectedImagePath = null;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isGenerating
                        ? _stopGeneration
                        : _submitPrompt,
                    icon: Icon(
                      isGenerating ? Icons.stop_rounded : Icons.psychology_rounded,
                    ),
                    label: Text(
                      isGenerating ? 'Stop Generation' : 'Submit',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildResponseSection(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineStatusCard(ColorScheme colorScheme) {
    if (_engineState.status == LlmEngineStatus.ready) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _engineState.message ?? 'SmolVLM2 engine ready.',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_engineState.status == LlmEngineStatus.downloading) {
      final progress = _engineState.downloadProgress ?? 0.0;
      final percentage = (progress * 100).toStringAsFixed(0);
      return Card(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Downloading SmolVLM2 Weights ($percentage%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _engineState.message ?? 'Downloading model weights from HuggingFace...',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_engineState.status == LlmEngineStatus.loading ||
        _engineState.status == LlmEngineStatus.checking) {
      return Card(
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _engineState.message ?? 'Connecting to SmolVLM2 model...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_engineState.status == LlmEngineStatus.error) {
      return Card(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colorScheme.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Text(
                    'Engine Status Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _engineState.error ?? _engineState.message ?? 'An unknown error occurred.',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    onPressed: _downloadModel,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download Model (~436MB)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _initializeEngine,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResponseSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Model Response',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_engineState.isGenerating)
              Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Streaming...',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: _responseBuffer.isNotEmpty
              ? SelectableText(
                  _responseBuffer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _engineState.isGenerating
                          ? 'Streaming SmolVLM2 model output...'
                          : 'Inference results will appear here after submission.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
