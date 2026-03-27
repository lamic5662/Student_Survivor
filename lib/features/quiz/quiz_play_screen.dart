import 'package:flutter/material.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/features/quiz/quiz_result_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizPlayScreen extends StatelessWidget {
  final Quiz quiz;
  final Subject subject;

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final attempt = QuizAttempt(
      quiz: quiz,
      score: 4,
      total: quiz.questionCount,
      xpEarned: 120,
      weakTopics: MockData.weakTopics,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${quiz.duration.inMinutes}:00 min',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Score: 0/${quiz.questionCount}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(
            3,
            (index) => _QuestionCard(index: index + 1),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => QuizResultScreen(attempt: attempt),
                  ),
                );
              },
              child: const Text('Submit Answers'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;

  const _QuestionCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q$index. Which OSI layer handles routing?',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...['Transport', 'Network', 'Session', 'Presentation']
                .map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () {},
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(option),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
