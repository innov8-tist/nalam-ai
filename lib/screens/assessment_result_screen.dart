import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class AssessmentResultScreen extends StatelessWidget {
  const AssessmentResultScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final result = session.triageResult;
    final modelResult = session.modelResult;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Model Response Card - Shows streaming content
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assessment',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (modelResult == null || modelResult.summary.isEmpty)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Generating response...'),
                      ],
                    )
                  else
                    Text(
                      modelResult.summary,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // New Assessment button - only show when response is complete
            if (modelResult != null && modelResult.summary.isNotEmpty)
              PrimaryButton(
                label: 'New Assessment',
                icon: Icons.add,
                onPressed: () {
                  // Reset the session
                  session.reset();
                  // Ensure analyzing state is cleared
                  final app = AppScope.of(context);
                  if (app.isAnalyzing) {
                    // Force reset analyzing state
                    app.isAnalyzing = false;
                    app.notifyListeners();
                  }
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
