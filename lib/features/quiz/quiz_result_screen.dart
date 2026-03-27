import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/core/widgets/tag.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizAttempt attempt;

  const QuizResultScreen({
    super.key,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final recommendedNotes = MockData.networkingChapters.first.notes;
    final importantQuestions =
        MockData.networkingChapters.first.importantQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Result'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: attempt.isPass
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.danger.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attempt.isPass ? 'Pass' : 'Fail',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: attempt.isPass
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: ${attempt.score}/${attempt.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '+${attempt.xpEarned} XP earned',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'AI Adaptive Learning'),
          const SizedBox(height: 12),
          ...attempt.weakTopics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topic.reason,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    const SizedBox(height: 8),
                    const Tag(label: 'Needs revision'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Recommended Notes'),
          const SizedBox(height: 12),
          ...recommendedNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note.shortAnswer,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Important Questions'),
          const SizedBox(height: 12),
          ...importantQuestions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.help_outline, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(question.prompt),
                    ),
                    Tag(label: '${question.marks} marks'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
