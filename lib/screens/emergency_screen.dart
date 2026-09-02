import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'recommended_facility_screen.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Emergency')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Spacer(),
            const SectionCard(
              color: Color(0xFFFFE2E0),
              child: Column(
                children: [
                  Icon(Icons.emergency, size: 72, color: AppColors.danger),
                  SizedBox(height: 15),
                  Text(
                    'POSSIBLE EMERGENCY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your symptoms may require immediate medical attention.\n\nDo not wait. Seek emergency care immediately.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Find Emergency Care',
              color: AppColors.danger,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecommendedFacilityScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Call 108 from your phone. Automatic calling is disabled.',
                  ),
                ),
              ),
              icon: const Icon(Icons.phone),
              label: const Text('Call Emergency 108'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const Spacer(),
            const Text(
              'Use this only in a real emergency situation.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
