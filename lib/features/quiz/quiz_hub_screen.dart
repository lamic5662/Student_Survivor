import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/quiz/quiz_detail_screen.dart';
import 'package:student_survivor/features/quiz/quiz_hub_presenter.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';

class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({super.key});

  @override
  State<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState
    extends PresenterState<QuizHubScreen, QuizHubView, QuizHubPresenter>
    implements QuizHubView {
  @override
  QuizHubPresenter createPresenter() => QuizHubPresenter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Hub'),
      ),
      body: ValueListenableBuilder<QuizHubViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                color: AppColors.secondary.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick your game mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _ModeChip(label: 'MCQ Quiz', icon: Icons.checklist),
                        _ModeChip(label: 'Time Attack', icon: Icons.timer),
                        _ModeChip(label: 'Level Mode', icon: Icons.trending_up),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Available Quizzes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...model.quizzes.map((item) => _QuizCard(item: item)),
            ],
          );
        },
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ModeChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.secondary),
      label: Text(label),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizCardItem item;

  const _QuizCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final quiz = item.quiz;
    final subject = item.subject;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: subject.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.sports_esports, color: subject.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subject.name} • ${quiz.questionCount} questions',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizDetailScreen(
                      quiz: quiz,
                      subject: subject,
                    ),
                  ),
                );
              },
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}
