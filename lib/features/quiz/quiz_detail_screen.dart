import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/quiz/quiz_play_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizDetailScreen extends StatelessWidget {
  final Quiz quiz;
  final Subject subject;

  const QuizDetailScreen({
    super.key,
    required this.quiz,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: subject.accentColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${quiz.questionCount} questions • ${quiz.duration.inMinutes} min',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game mode',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _modeLabel(quiz.type),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 16),
                Text(
                  'Difficulty',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  quiz.difficulty.name.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What you will get',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text('XP points, adaptive feedback, and smart notes.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizPlayScreen(
                      quiz: quiz,
                      subject: subject,
                    ),
                  ),
                );
              },
              child: const Text('Start Quiz'),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(QuizType type) {
    switch (type) {
      case QuizType.mcq:
        return 'MCQ Quickfire';
      case QuizType.time:
        return 'Time Attack';
      case QuizType.level:
        return 'Level Mode';
    }
  }
}
