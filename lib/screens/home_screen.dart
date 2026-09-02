import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../services/stt_service.dart';
import '../widgets/feature_button.dart';
import '../widgets/workspace_panel.dart';
import 'llm_screen.dart';
import 'stt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.sttService, super.key});

  final STTService? sttService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _workspaceMessage = AppConstants.workspaceTitle;

  void _selectModule(String module) {
    setState(() {
      _workspaceMessage = '$module module selected';
    });
  }

  void _openLlmScreen() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const LlmScreen(),
      ),
    );
  }

  void _openSttScreen() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SttScreen(sttService: widget.sttService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: WorkspacePanel(message: _workspaceMessage)),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  return SizedBox(
                    height: isWide ? 104 : 196,
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isWide ? 1.8 : 2.4,
                      children: [
                        FeatureButton(
                          label: 'TTS',
                          icon: Icons.volume_up_rounded,
                          onPressed: () => _selectModule('TTS'),
                        ),
                        FeatureButton(
                          label: 'STT',
                          icon: Icons.mic_rounded,
                          onPressed: _openSttScreen,
                        ),
                        FeatureButton(
                          label: 'LLM',
                          icon: Icons.psychology_rounded,
                          onPressed: _openLlmScreen,
                        ),
                        FeatureButton(
                          label: 'MAP',
                          icon: Icons.map_rounded,
                          onPressed: () => _selectModule('Map'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
