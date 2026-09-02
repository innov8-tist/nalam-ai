/// A future structured result from the medical triage engine.
///
/// This model is intentionally small while the prototype's data requirements
/// are still being defined.
class TriageResult {
  const TriageResult({
    required this.summary,
    required this.urgency,
    this.recommendedFacility,
  });

  final String summary;
  final TriageUrgency urgency;
  final String? recommendedFacility;
}

enum TriageUrgency { low, medium, high, emergency }
