import '../../models/assessment_models.dart';
import '../../models/triage_result.dart';

const demoFacilities = <Facility>[
  Facility(
    id: 'phc-a',
    name: 'Nearby PHC',
    distanceKm: 3.2,
    etaMinutes: 9,
    capabilities: {'Basic care', 'Pharmacy'},
    acceptingPatients: true,
    reason:
        'Closest option for routine in-person assessment and pharmacy support.',
  ),
  Facility(
    id: 'district',
    name: 'District Hospital',
    distanceKm: 14.8,
    etaMinutes: 28,
    capabilities: {
      'Emergency',
      'ICU',
      'Oxygen',
      'Ventilator',
      'Laboratory',
      'Pharmacy',
    },
    acceptingPatients: true,
    icuAvailable: 2,
    icuTotal: 8,
    bedsAvailable: 12,
    bedsTotal: 50,
    isRecommended: true,
    reason: 'Best nearby capability match when urgent or emergency evaluation is recommended.',
  ),
];

final demoHistory = <AssessmentHistoryEntry>[
  AssessmentHistoryEntry(
    timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    symptoms: 'Severe breathing difficulty',
    severity: TriageUrgency.emergency,
  ),
  AssessmentHistoryEntry(
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    symptoms: 'Breathing difficulty',
    severity: TriageUrgency.high,
  ),
  AssessmentHistoryEntry(
    timestamp: DateTime.now().subtract(const Duration(hours: 10)),
    symptoms: 'Fever & cough',
    severity: TriageUrgency.medium,
  ),
];
