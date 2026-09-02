import 'package:flutter/material.dart';

import '../models/assessment_models.dart';
import '../models/triage_result.dart';
import '../theme/app_theme.dart';

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.offline_bolt, size: 14, color: AppColors.primary),
        SizedBox(width: 5),
        Text(
          'Offline Mode',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.color,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    iconAlignment: IconAlignment.end,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: color ?? AppColors.primary,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    super.key,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: padding, child: child),
  );
}

({String label, Color color, Color pale, IconData icon}) severityPresentation(
  TriageUrgency urgency,
) => switch (urgency) {
  TriageUrgency.low => (
    label: 'LOW RISK',
    color: AppColors.primary,
    pale: const Color(0xFFE7F6EC),
    icon: Icons.check_circle,
  ),
  TriageUrgency.medium => (
    label: 'MODERATE',
    color: const Color(0xFF9A6700),
    pale: const Color(0xFFFFF5D6),
    icon: Icons.info,
  ),
  TriageUrgency.high => (
    label: 'URGENT CARE',
    color: AppColors.urgent,
    pale: const Color(0xFFFFE8D1),
    icon: Icons.warning_rounded,
  ),
  TriageUrgency.emergency => (
    label: 'POSSIBLE EMERGENCY',
    color: AppColors.danger,
    pale: const Color(0xFFFFE2E0),
    icon: Icons.emergency,
  ),
};

class SeverityCard extends StatelessWidget {
  const SeverityCard({
    required this.urgency,
    required this.summary,
    this.compact = false,
    super.key,
  });
  final TriageUrgency urgency;
  final String summary;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final p = severityPresentation(urgency);
    return SectionCard(
      color: p.pale,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? 'Current Risk' : 'CURRENT RISK',
                  style: TextStyle(
                    color: p.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  p.label,
                  style: TextStyle(
                    color: p.color,
                    fontSize: compact ? 22 : 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(summary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(p.icon, color: p.color, size: compact ? 38 : 54),
        ],
      ),
    );
  }
}

class CapabilityBadge extends StatelessWidget {
  const CapabilityBadge({
    required this.label,
    this.available = true,
    super.key,
  });
  final String label;
  final bool available;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      available ? Icons.check_circle : Icons.remove_circle_outline,
      size: 17,
      color: available ? AppColors.primary : AppColors.muted,
    ),
    label: Text(label),
    backgroundColor: available ? AppColors.mint : Colors.grey.shade100,
    side: BorderSide.none,
  );
}

class FacilityCard extends StatelessWidget {
  const FacilityCard({required this.facility, this.onTap, super.key});
  final Facility facility;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (facility.isRecommended)
              const Text(
                'WE RECOMMEND',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            Text(
              facility.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Text(
              '${facility.distanceKm} km away  •  ~${facility.etaMinutes} min',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 11,
                  color: facility.acceptingPatients
                      ? AppColors.primary
                      : AppColors.danger,
                ),
                const SizedBox(width: 6),
                Text(
                  facility.acceptingPatients
                      ? 'Accepting patients'
                      : 'Not accepting patients',
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: facility.capabilities
                  .take(3)
                  .map((e) => CapabilityBadge(label: e))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class AssessmentProgress extends StatelessWidget {
  const AssessmentProgress({
    required this.current,
    required this.total,
    super.key,
  });
  final int current;
  final int total;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LinearProgressIndicator(
        value: current / total,
        minHeight: 5,
        borderRadius: BorderRadius.circular(5),
        backgroundColor: AppColors.border,
        color: AppColors.primary,
      ),
      const SizedBox(height: 16),
      Text(
        'Question $current of $total',
        style: const TextStyle(color: AppColors.muted),
      ),
    ],
  );
}

class QuestionOption extends StatelessWidget {
  const QuestionOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: selected ? AppColors.mint : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    ),
  );
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({required this.label, super.key});
  final String label;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black45,
    child: Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}
