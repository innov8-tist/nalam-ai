class AssessmentQuestion {
  const AssessmentQuestion({
    required this.id,
    required this.text,
    required this.options,
  });
  final String id;
  final String text;
  final List<String> options;
}

const assessmentQuestions = <AssessmentQuestion>[
  AssessmentQuestion(
    id: 'duration',
    text: 'How long have you had these symptoms?',
    options: ['Today', '2–3 days', '4–7 days', '1+ week'],
  ),
  AssessmentQuestion(
    id: 'breathing',
    text: 'Are you having difficulty breathing?',
    options: ['No', 'Mild', 'Severe'],
  ),
  AssessmentQuestion(
    id: 'progression',
    text: 'How are your symptoms changing?',
    options: ['Improving', 'About the same', 'Getting worse'],
  ),
];
