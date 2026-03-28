import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/quiz/quiz_hub_presenter.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/models/app_models.dart';

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
          if (model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (model.errorMessage != null) {
            return Center(child: Text(model.errorMessage!));
          }
          if (model.semesterName.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select a semester to start playing.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileEditScreen(),
                          ),
                        );
                      },
                      child: const Text('Choose Semester'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                color: AppColors.secondary.withValues(alpha: 0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Play by semester',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      model.semesterName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select a subject',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (model.subjects.isEmpty)
                const Text('No subjects available for this semester yet.')
              else
                ...model.subjects.map((subject) => _SubjectCard(subject: subject)),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final quizCount = subject.chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.quizzes.length,
    );
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
                    subject.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${subject.chapters.length} chapters • $quizCount quizzes',
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
                    builder: (_) => SubjectDetailScreen(subject: subject),
                  ),
                );
              },
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }
}
