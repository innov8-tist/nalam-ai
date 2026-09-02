import 'package:flutter/material.dart';

import '../models/tts_state.dart';
import '../services/tts_service.dart';

class TtsScreen extends StatefulWidget {
  const TtsScreen({
    this.ttsService,
    super.key,
  });

  final TTSService? ttsService;

  @override
  State<TtsScreen> createState() => _TtsScreenState();
}

class _TtsScreenState extends State<TtsScreen> {
  late final TTSService _ttsService;
  late final TextEditingController _textController;

  String _selectedLanguage = 'en-US';
  bool _isSpeaking = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  TtsEngineState _engineState =
      const TtsEngineState(status: TtsEngineStatus.uninitialized);

  final Map<String, String> _languages = {
    'en-US': 'English',
    'ml-IN': 'Malayalam',
  };

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _ttsService = widget.ttsService ?? TTSService();
    _initializeTts();
  }

  Future<void> _initializeTts() async {
    try {
      // Listen to state changes first
      _ttsService.stateStream.listen((state) {
        if (mounted) {
          setState(() {
            _engineState = state;
            _isSpeaking = state.isSpeaking;
          });
        }
      });

      // Then initialize
      await _ttsService.initialize();
      if (mounted) {
        setState(() {
          _engineState = _ttsService.currentState;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Failed to initialize TTS: $e');
      }
    }
  }

  Future<void> _downloadModel(String modelType) async {
    try {
      setState(() {
        _engineState = const TtsEngineState(
          status: TtsEngineStatus.downloading,
          message: 'Starting download...',
        );
      });

      await _ttsService.downloadModel(modelType);
      setState(() {
        _engineState = _ttsService.currentState;
      });
      _showSnackbar('Model downloaded successfully!');
    } catch (e) {
      if (mounted) {
        _showSnackbar('Download failed: $e');
      }
    }
  }

  Future<void> _speak() async {
    if (_textController.text.isEmpty) {
      _showSnackbar('Please enter text to speak');
      return;
    }

    try {
      setState(() => _isSpeaking = true);
      await _ttsService.speak(
        _textController.text,
        languageCode: _selectedLanguage,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _showSnackbar('Error: $e');
      }
    }
  }

  Future<void> _stop() async {
    try {
      setState(() => _isSpeaking = false);
      await _ttsService.stop();
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error stopping: $e');
      }
    }
  }

  Future<void> _updateSpeechRate(double value) async {
    setState(() => _speechRate = value);
    await _ttsService.setSpeechRate(value);
  }

  Future<void> _updatePitch(double value) async {
    setState(() => _pitch = value);
    await _ttsService.setPitch(value);
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme colorScheme) {
    if (_engineState.status == TtsEngineStatus.ready) {
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
                _engineState.message ?? 'TTS engine ready',
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

    if (_engineState.status == TtsEngineStatus.downloading) {
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
              Text(
                _engineState.message ?? 'Downloading...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percentage%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    if (_engineState.hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_rounded, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _engineState.error ?? 'An error occurred',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Initializing TTS engine...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButtons(ColorScheme colorScheme) {
    if (_engineState.modelDownloaded) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Download Models',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Download high-quality TTS models for natural-sounding voices.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _engineState.isBusy
                    ? null
                    : () => _downloadModel('en-US'),
                icon: Icon(_engineState.isBusy ? Icons.hourglass_top : Icons.download),
                label: const Text('English'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _engineState.isBusy
                    ? null
                    : () => _downloadModel('ml-IN'),
                icon: Icon(_engineState.isBusy ? Icons.hourglass_top : Icons.download),
                label: const Text('Malayalam'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Natural Text-to-Speech'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(colorScheme),
              const SizedBox(height: 24),

              // Download Section
              _buildDownloadButtons(colorScheme),

              // Language Selection
              Text(
                'Language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _languages.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLanguage = value);
                      _ttsService.setLanguage(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Text Input
              Text(
                'Text to Speak',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                enabled: !_isSpeaking && !_engineState.isBusy,
                maxLines: 6,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter text to convert to speech...',
                  labelText: 'Text Input',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                ),
              ),
              const SizedBox(height: 24),

              // Speech Rate Control
              Text(
                'Speech Rate',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _speechRate,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: '${(_speechRate * 100).toStringAsFixed(0)}%',
                      onChanged: _engineState.status == TtsEngineStatus.downloading
                          ? null
                          : _updateSpeechRate,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${(_speechRate * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pitch Control
              Text(
                'Pitch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: _pitch.toStringAsFixed(1),
                      onChanged: _engineState.status == TtsEngineStatus.downloading
                          ? null
                          : _updatePitch,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _pitch.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: _isSpeaking
                            ? colorScheme.error
                            : colorScheme.primary,
                      ),
                      onPressed: _isSpeaking ? _stop : _speak,
                      icon: Icon(
                        _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                      ),
                      label: Text(
                        _isSpeaking ? 'Stop Speaking' : 'Speak',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
