import 'package:flutter/material.dart';
import 'package:examapp/screens/examiner/review_questions_screen.dart';

class ManualExamBuilderScreen extends StatelessWidget {
  const ManualExamBuilderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReviewQuestionsScreen(
      extractedQuestions: [],
      initialExamTitle: 'Untitled Exam',
      isManualMode: true,
    );
  }
}
