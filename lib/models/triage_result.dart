/// A future structured result from the medical triage engine.
///
/// This model is intentionally small while the prototype's data requirements
/// are still being defined.
class TriageResult {
  const TriageResult({
    required this.summary,
    required this.urgency,
    this.recommendedFacility,
    this.signals = const [],
    this.possibleCauses = const [],
    this.recommendedCare = const [],
    this.seekHelpNowIf = const [],
  });

  final String summary;
  final TriageUrgency urgency;
  final String? recommendedFacility;
  final List<String> signals;
  final List<String> possibleCauses;
  final List<String> recommendedCare;
  final List<String> seekHelpNowIf;
}

enum TriageUrgency { low, medium, high, emergency }
