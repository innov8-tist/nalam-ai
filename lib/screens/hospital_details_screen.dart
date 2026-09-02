import 'package:flutter/material.dart';

import '../models/assessment_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class HospitalDetailsScreen extends StatelessWidget {
  const HospitalDetailsScreen({required this.facility, super.key});
  final Facility facility;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Hospital Details'),
      actions: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_hospital,
              size: 74,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            facility.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 23),
          ),
          Text('${facility.distanceKm} km away'),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.circle, size: 11, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Accepting patients',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Facilities',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: facility.capabilities
                .map(
                  (e) => SectionCard(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            e,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Call Hospital',
            icon: Icons.phone,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calling is disabled in this prototype.'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
