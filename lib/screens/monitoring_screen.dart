import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'assessment_screen.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.history.first;
    return Scaffold(
      appBar: AppBar(title: const Text('My Monitoring')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SeverityCard(
              urgency: current.severity,
              summary: 'Last updated ${_ago(current.timestamp)}',
              compact: true,
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Health Timeline',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  ...app.history.map((entry) {
                    final p = severityPresentation(entry.severity);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 15, color: p.color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _ago(entry.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                                Text(
                                  entry.symptoms,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  p.label,
                                  style: TextStyle(
                                    color: p.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Update Symptoms',
              icon: Icons.edit_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssessmentScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime time) {
    final d = DateTime.now().difference(time);
    return d.inMinutes < 60
        ? '${d.inMinutes} min ago'
        : '${d.inHours} hours ago';
  }
}
