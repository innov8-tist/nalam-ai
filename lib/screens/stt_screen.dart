import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stt_state.dart';
import '../services/stt_service.dart';

class SttScreen extends StatefulWidget {
  const SttScreen({
    this.sttService,
    super.key,
  });

  final STTService? sttService;

  @override
  State<SttScreen> createState() => _SttScreenState();
}

class _SttScreenState extends State<SttScreen> with SingleTickerProviderStateMixin {
  late final STTService _sttService;
  SttEngineState _engineState =
      const SttEngineState(status: SttEngineStatus.uninitialized);

  StreamSubscription<SttEngineState>? _stateSubscription;
  String _transcriptionResult = '';
  String _selectedLanguage = 'auto'; // 'auto', 'en', 'ml'

  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _sttService = widget.sttService ?? STTService();

    _engineState = _sttService.currentState;
    _stateSubscription = _sttService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _engineState = state;
        });

        // Manage record button animation based on state
        if (state.status == SttEngineStatus.recording) {
          _pulseController?.repeat(reverse: true);
        } else {
          _pulseController?.stop();
        }
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    try {
      await _sttService.initialize(autoDownload: true);
    } catch (_) {
      // Error is surfaced via _engineState
    }
  }

  Future<void> _downloadModel() async {
    try {
      await _sttService.downloadModel();
    } catch (_) {
      // Surfaced in UI via state
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_engineState.status == SttEngineStatus.recording) {
        final result = await _sttService.stopRecording(language: _selectedLanguage);
        setState(() {
          _transcriptionResult = result;
        });
      } else {
        await _sttService.startRecording();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_transcriptionResult.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _transcriptionResult));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcription copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _pulseController?.dispose();
    if (widget.sttService == null) {
      _sttService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRecording = _engineState.status == SttEngineStatus.recording;
    final isTranscribing = _engineState.status == SttEngineStatus.transcribing;
    final isReady = _engineState.status == SttEngineStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device Speech to Text'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reinitialize model',
            onPressed: isRecording || isTranscribing ? null : _initializeEngine,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEngineStatusCard(colorScheme),
            const SizedBox(height: 20),
            _buildLanguageSelector(colorScheme, isRecording || isTranscribing),
            const SizedBox(height: 30),
            _buildRecordSection(colorScheme, isReady, isRecording, isTranscribing),
            const SizedBox(height: 30),
            _buildTranscriptionResultSection(colorScheme, isTranscribing),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(ColorScheme colorScheme, bool isDisabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.translate_rounded, color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Target Language',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          DropdownButton<String>(
            value: _selectedLanguage,
            underline: const SizedBox(),
            borderRadius: BorderRadius.circular(12),
            onChanged: isDisabled
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                    }
                  },
            items: const [
              DropdownMenuItem(
                value: 'auto',
                child: Text('Auto-Detect'),
              ),
              DropdownMenuItem(
                value: 'en',
                child: Text('English (en)'),
              ),
              DropdownMenuItem(
                value: 'ml',
                child: Text('Malayalam (ml)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSection(
      ColorScheme colorScheme, bool isReady, bool isRecording, bool isTranscribing) {
    final buttonEnabled = isReady || isRecording;

    return Center(
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController!,
            builder: (context, child) {
              final pulseValue = _pulseController!.value;
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isRecording)
                      BoxShadow(
                        color: colorScheme.error.withValues(alpha: 0.25 * (1 - pulseValue)),
                        blurRadius: 20 + 20 * pulseValue,
                        spreadRadius: 10 + 15 * pulseValue,
                      ),
                  ],
                ),
                child: RawMaterialButton(
                  onPressed: buttonEnabled ? _toggleRecording : null,
                  elevation: isRecording ? 8.0 : 4.0,
                  fillColor: isRecording
                      ? colorScheme.error
                      : buttonEnabled
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: isTranscribing
                      ? SizedBox(
                          width: 45,
                          height: 45,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                          ),
                        )
                      : Icon(
                          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 50,
                          color: buttonEnabled
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            isRecording
                ? 'Recording...'
                : isTranscribing
                    ? 'Processing Transcription...'
                    : buttonEnabled
                        ? 'Tap to Record'
                        : 'STT Model Not Ready',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isRecording
                  ? colorScheme.error
                  : isTranscribing
                      ? colorScheme.primary
                      : colorScheme.onSurface,
            ),
          ),
          if (isRecording) ...[
            const SizedBox(height: 6),
            const Text(
              'Speak clearly into your microphone.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEngineStatusCard(ColorScheme colorScheme) {
    if (_engineState.status == SttEngineStatus.ready) {
      final isApiFallback = _engineState.message?.contains('API Fallback') ?? false;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isApiFallback
              ? colorScheme.tertiaryContainer.withValues(alpha: 0.35)
              : colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isApiFallback
                ? colorScheme.tertiary.withValues(alpha: 0.5)
                : colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isApiFallback ? Icons.cloud_queue_rounded : Icons.check_circle_rounded,
              color: isApiFallback ? colorScheme.tertiary : colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _engineState.message ?? 'Parakeet TDT STT engine ready.',
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

    if (_engineState.status == SttEngineStatus.downloading) {
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
                      'Downloading Parakeet TDT Model ($percentage%)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _engineState.message ?? 'Downloading Parakeet TDT weights...',
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

    if (_engineState.status == SttEngineStatus.checking ||
        _engineState.status == SttEngineStatus.transcribing) {
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
                  _engineState.message ?? 'Connecting to Parakeet TDT STT...',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_engineState.status == SttEngineStatus.error) {
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
                    'STT Engine Status Alert',
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.computer_rounded, color: colorScheme.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Offline Manual Bypass',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'If your emulator/device has no internet or is failing hostname lookup, download the file on your computer and place/push it to this exact path on the device:',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _sttService.getModelPath(),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? 'Loading...';
                        return Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SelectableText(
                                  path,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_all_rounded, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: path));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Path copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Once copied, tap "Retry" or click on Refresh icon to load the model offline instantly!',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                    label: const Text('Download Model (~463MB)'),
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

  Widget _buildTranscriptionResultSection(ColorScheme colorScheme, bool isTranscribing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transcription Result',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (_transcriptionResult.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: 'Copy to clipboard',
                onPressed: _copyToClipboard,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: isTranscribing
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Converting your speech to text...',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                )
              : _transcriptionResult.isNotEmpty
                  ? SelectableText(
                      _transcriptionResult,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Your transcribed text will appear here.',
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
