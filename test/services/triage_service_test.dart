import 'package:flutter_test/flutter_test.dart';
import 'package:nalam_ai/models/assessment_models.dart';
import 'package:nalam_ai/models/triage_result.dart';
import 'package:nalam_ai/services/triage_service.dart';

void main() {
  const service = TriageService();
  test('escalates breathing difficulty to urgent care', () {
    final result = service.assess(
      modelAssessment: const ModelAssessment(
        rawOutput: 'The area appears inflamed.',
      ),
      symptoms: 'It is spreading and I have difficulty breathing.',
    );
    expect(result.urgency, TriageUrgency.high);
    expect(
      result.signals.any((reason) => reason.contains('Breathing difficulty')),
      isTrue,
    );
  });
  test('escalates emergency warning signs', () {
    final result = service.assess(
      modelAssessment: const ModelAssessment(
        rawOutput: 'No visual assessment.',
      ),
      symptoms: 'I have chest pain and blue lips.',
    );
    expect(result.urgency, TriageUrgency.emergency);
  });

  test('uses the model explanation that supports a structured urgency', () {
    final assessment = ModelAssessment.fromRawOutput('''
      ```json
      {
        "urgency": "medium",
        "summary": "The rash needs a timely examination, but no current emergency sign was reported.",
        "urgency_reasons": [
          "An expanding painful rash with a blister was reported — this should be checked soon for infection or inflammation."
        ],
        "possible_causes": [
          "Fungal skin infection — itch and a scaly ring may fit, but a photo cannot confirm it.",
          "Contact dermatitis — an itchy blistering rash can fit, although the expanding ring is less typical."
        ],
        "recommended_care": [
          "Arrange an in-person clinical review within 24 hours.",
          "Keep the area clean and avoid popping the blister."
        ],
        "seek_help_now_if": [
          "Redness spreads rapidly with fever, pus, red streaks, or severe pain.",
          "You develop facial swelling, trouble breathing, fainting, or confusion."
        ]
      }
      ```
    ''');

    final result = service.assess(
      modelAssessment: assessment,
      symptoms: 'Painful itchy blister with an expanding red scaly ring.',
    );

    expect(assessment.isComplete, isTrue);
    expect(result.urgency, TriageUrgency.medium);
    expect(result.signals.single, contains('expanding painful rash'));
    expect(result.possibleCauses, hasLength(2));
    expect(result.recommendedCare, isNot(contains(contains('oxygen'))));
    expect(result.seekHelpNowIf.first, contains('fever'));
  });

  test('does not turn spreading alone into unsupported urgent care', () {
    final result = service.assess(
      modelAssessment: const ModelAssessment(rawOutput: 'Incomplete output'),
      symptoms: 'An itchy scaly ring is slowly spreading.',
    );

    expect(result.urgency, TriageUrgency.medium);
    expect(result.signals, contains(contains('incomplete')));
    expect(result.recommendedCare, isNot(contains(contains('oxygen'))));
  });

  test('keeps useful model fields when optional sections are incomplete', () {
    final assessment = ModelAssessment.fromRawOutput('''
      {
        "urgency": "moderate",
        "summary": "The reported rash has no current emergency warning sign, but persistence warrants a clinical review.",
        "urgency_reasons": "A persistent changing rash should be examined if it does not settle.",
        "possible_causes": ["Skin irritation — this may fit the itching, but an examination is needed."],
        "recommended_care": ["Arrange a clinical review if it persists."]
      }
    ''');

    expect(assessment.isComplete, isFalse);
    expect(assessment.canSupportCareLevel, isTrue);

    final result = service.assess(
      modelAssessment: assessment,
      symptoms: 'An itchy rash that has persisted for several days.',
    );

    expect(result.urgency, TriageUrgency.medium);
    expect(result.summary, contains('reported rash'));
    expect(result.signals.single, contains('persistent changing rash'));
    expect(result.possibleCauses.single, contains('Skin irritation'));
    expect(result.seekHelpNowIf, isNotEmpty);
  });

  test('accepts common schema aliases and ignores text after JSON', () {
    final assessment = ModelAssessment.fromRawOutput('''
      Here is the result:
      {
        "risk_level": "low",
        "assessment_summary": "The reported mild symptom has no stated warning sign and can be monitored for now.",
        "reasons": ["No severe or rapidly worsening feature was reported in this case."],
        "possibilities": "Minor irritation — this may fit, although it cannot be confirmed here.",
        "next_steps": "Monitor it and seek routine advice if it persists.",
        "red_flags": "Seek urgent help if breathing becomes difficult."
      }
      Note: {do not treat this as part of the JSON}
    ''');

    expect(assessment.canSupportCareLevel, isTrue);
    expect(assessment.suggestedUrgency, TriageUrgency.low);
    expect(assessment.possibleCauses, hasLength(1));
    expect(assessment.recommendedCare, hasLength(1));
  });

  test('assessment prompt requires case-specific evidence', () {
    final prompt = service.buildAssessmentPrompt(
      symptoms: 'Painful rash',
      hasImage: true,
    );

    expect(prompt, contains('visible or explicitly reported'));
    expect(prompt, contains('urgency_reasons'));
    expect(prompt, contains('possible_causes'));
    expect(prompt, contains('seek_help_now_if'));
  });

  test('rejects a vague urgent reason as an incomplete assessment', () {
    final assessment = ModelAssessment.fromRawOutput('''
      {
        "urgency": "high",
        "summary": "The symptoms need urgent medical care, and you should be examined very soon.",
        "urgency_reasons": ["Symptoms getting worse"],
        "possible_causes": ["Skin infection — uncertain", "Irritation — uncertain"],
        "recommended_care": ["Seek care today", "Monitor symptoms"],
        "seek_help_now_if": ["Breathing trouble", "Fainting"]
      }
    ''');

    expect(assessment.isComplete, isFalse);
    final result = service.assess(
      modelAssessment: assessment,
      symptoms: 'An itchy rash is slowly spreading.',
    );
    expect(result.urgency, TriageUrgency.medium);
    expect(result.signals, contains(contains('incomplete')));
  });
}
