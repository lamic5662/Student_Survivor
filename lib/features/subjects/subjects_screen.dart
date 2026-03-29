import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/features/subjects/subjects_presenter.dart';
import 'package:student_survivor/features/subjects/subjects_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState
    extends PresenterState<SubjectsScreen, SubjectsView, SubjectsPresenter>
    implements SubjectsView {
  @override
  SubjectsPresenter createPresenter() => SubjectsPresenter();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubjectsViewModel>(
      valueListenable: presenter.state,
      builder: (context, model, _) {
        final subjects = model.subjects;
        final totalChapters =
            subjects.fold<int>(0, (sum, subject) => sum + subject.chapters.length);
        final totalQuizzes = subjects.fold<int>(
          0,
          (sum, subject) =>
              sum +
              subject.chapters.fold<int>(
                0,
                (count, chapter) => count + chapter.quizzes.length,
              ),
        );
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subjects'),
                Text(
                  model.semesterName,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.18),
                      AppColors.accent.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.menu_book_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Subjects',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pick a subject to explore notes and quizzes.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoChip(label: '${subjects.length} subjects'),
                              _InfoChip(label: '$totalChapters chapters'),
                              _InfoChip(label: '$totalQuizzes quizzes'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (subjects.isEmpty)
                AppCard(
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          size: 48, color: AppColors.mutedInk),
                      const SizedBox(height: 12),
                      Text(
                        'No subjects available.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select a semester to load subjects.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                )
              else
                ...subjects.asMap().entries.map((entry) {
                  final subject = entry.value;
                  final quizzes = subject.chapters.fold<int>(
                    0,
                    (sum, chapter) => sum + chapter.quizzes.length,
                  );
                  final progress = (0.4 + entry.key * 0.08).clamp(0.1, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SubjectCard(
                      subject: subject,
                      quizzes: quizzes,
                      progress: progress,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectDetailScreen(subject: subject),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final int quizzes;
  final double progress;
  final VoidCallback onOpen;

  const _SubjectCard({
    required this.subject,
    required this.quizzes,
    required this.progress,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: subject.accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: subject.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subject.code,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.mutedInk),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: '${subject.chapters.length} chapters'),
                _InfoChip(label: '$quizzes quizzes'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.outline,
              color: subject.accentColor,
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onOpen,
                child: const Text('Open Subject'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.secondary),
      ),
    );
  }
}
