import 'package:flutter/material.dart';

import '../data/assessment_questions.dart';
import '../state/app_controller.dart';
import '../widgets/app_components.dart';
import 'assessment_result_screen.dart';

class AssessmentQuestionsScreen extends StatefulWidget {
  const AssessmentQuestionsScreen({super.key});
  @override
  State<AssessmentQuestionsScreen> createState() =>
      _AssessmentQuestionsScreenState();
}

class _AssessmentQuestionsScreenState extends State<AssessmentQuestionsScreen> {
  int index = 0;
  final answers = <String, String>{};
  @override
  Widget build(BuildContext context) {
    final q = assessmentQuestions[index];
    final selected = answers[q.id];
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AssessmentProgress(
                current: index + 1,
                total: assessmentQuestions.length,
              ),
              const SizedBox(height: 30),
              Text(
                q.text,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              ...q.options.map(
                (option) => QuestionOption(
                  label: option,
                  selected: selected == option,
                  onTap: () => setState(() => answers[q.id] = option),
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: index == assessmentQuestions.length - 1
                    ? 'View Result'
                    : 'Next',
                onPressed: selected == null
                    ? null
                    : () {
                        if (index < assessmentQuestions.length - 1) {
                          setState(() => index++);
                        } else {
                          AppScope.of(context).updateAnswers(answers);
                          if (AppScope.of(context).session.triageResult !=
                              null) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AssessmentResultScreen(),
                              ),
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
