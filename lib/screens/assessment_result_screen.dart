import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/assessment_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'emergency_screen.dart';
import 'recommended_facility_screen.dart';

class AssessmentResultScreen extends StatelessWidget {
  const AssessmentResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final result = session.triageResult;
    final rawOutputs = session.modelOutputs.isNotEmpty
        ? session.modelOutputs
        : session.modelResult == null
        ? const <String>[]
        : <String>[session.modelResult!.rawOutput];
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessment Result')),
        body: const Center(child: Text('No assessment result is available.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SeverityCard(urgency: result.urgency, summary: result.summary),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why this care level?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _BulletList(
                    items: result.signals,
                    emptyMessage: 'The assessment did not provide a case-specific reason.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What it could be',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Possibilities to discuss with a clinician — not a diagnosis',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  _BulletList(
                    items: result.possibleCauses,
                    emptyMessage: 'The model did not provide enough reliable detail to suggest possibilities.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended Care',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...result.recommendedCare.map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.health_and_safety_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(e),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              color: const Color(0xFFFFF8E8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.urgent,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Get help immediately if',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _BulletList(
                    items: result.seekHelpNowIf,
                    emptyMessage:
                        'Seek prompt help for any sudden or severe worsening.',
                  ),
                ],
              ),
            ),
            if (rawOutputs.isNotEmpty) ...[
              const SizedBox(height: 14),
              _RawModelOutputCard(outputs: rawOutputs),
            ],
            const SizedBox(height: 16),
            if (result.urgency.name == 'emergency')
              PrimaryButton(
                label: 'Emergency Guidance',
                color: AppColors.danger,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                ),
              )
            else
              PrimaryButton(
                label: 'Find Care',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecommendedFacilityScreen(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'NalamEdge provides guidance, not a medical diagnosis. Seek professional care when concerned.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawModelOutputCard extends StatelessWidget {
  const _RawModelOutputCard({required this.outputs});

  final List<String> outputs;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Raw model output (debug)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Exact text returned by the on-device model',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        children: [
          for (var index = 0; index < outputs.length; index++)
            _RawOutputAttempt(
              number: index + 1,
              output: outputs[index],
              isRepair: index > 0,
            ),
        ],
      ),
    );
  }
}

class _RawOutputAttempt extends StatelessWidget {
  const _RawOutputAttempt({
    required this.number,
    required this.output,
    required this.isRepair,
  });

  final int number;
  final String output;
  final bool isRepair;

  @override
  Widget build(BuildContext context) {
    final parsed = ModelAssessment.fromRawOutput(output);
    final displayText = output.isEmpty ? '(empty response)' : output;
    final parseLabel = parsed.canSupportCareLevel
        ? 'usable structured result'
        : parsed.isStructured
        ? 'JSON found, but required care-level evidence is missing'
        : 'no valid JSON object found';

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRepair ? 'Attempt $number (repair)' : 'Attempt $number',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Copy output',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: output));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Model output copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 20),
              ),
            ],
          ),
          Text(
            parseLabel,
            style: TextStyle(
              fontSize: 12,
              color: parsed.canSupportCareLevel
                  ? AppColors.primary
                  : AppColors.urgent,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                displayText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.emptyMessage});

  final List<String> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyMessage, style: const TextStyle(color: AppColors.muted));
    }
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
