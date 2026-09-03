import 'package:flutter/material.dart';

import '../data/demo/demo_data.dart';
import '../models/assessment_models.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'hospital_details_screen.dart';
import 'route_screen.dart';

class RecommendedFacilityScreen extends StatelessWidget {
  const RecommendedFacilityScreen({this.embedded = false, super.key});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final recommended =
        AppScope.of(context).session.recommendedFacility ??
        demoFacilities.firstWhere((facility) => facility.isRecommended);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !embedded,
        title: Text(embedded ? 'Care' : 'Recommended Facility'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FacilityCard(
              facility: recommended,
              onTap: () => _details(context, recommended),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why this hospital?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(recommended.reason),
                  const SizedBox(height: 14),
                  const Text(
                    'This hospital has:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 6,
                    children: recommended.capabilities
                        .map((e) => CapabilityBadge(label: e))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hospital Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Demo data',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const Text(
                    'Live status unavailable offline',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Status(
                          label: 'ICU Beds',
                          value:
                              '${recommended.icuAvailable} / ${recommended.icuTotal}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Status(
                          label: 'General Beds',
                          value:
                              '${recommended.bedsAvailable} / ${recommended.bedsTotal}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const CapabilityBadge(label: 'Emergency available'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'View on Map',
              icon: Icons.map_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RouteScreen(facility: recommended),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Other nearby facilities',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 8),
            ...demoFacilities
                .where((f) => f.id != recommended.id)
                .map(
                  (f) => FacilityCard(
                    facility: f,
                    onTap: () => _details(context, f),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _details(BuildContext context, Facility facility) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => HospitalDetailsScreen(facility: facility),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const Text(
          'Available',
          style: TextStyle(fontSize: 11, color: AppColors.primary),
        ),
      ],
    ),
  );
}
