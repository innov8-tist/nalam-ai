import '../data/demo/demo_data.dart';
import '../models/assessment_models.dart';
import '../models/triage_result.dart';

class FacilityService {
  const FacilityService();
  Facility? getRecommendedFacility(TriageResult result) {
    final required =
        result.urgency == TriageUrgency.emergency ||
            result.urgency == TriageUrgency.high
        ? {'Emergency'}
        : <String>{};
    for (final facility in demoFacilities) {
      if (facility.acceptingPatients &&
          facility.capabilities.containsAll(required)) {
        return facility;
      }
    }
    return null;
  }
}
