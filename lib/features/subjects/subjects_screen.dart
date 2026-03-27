import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/features/subjects/subjects_presenter.dart';
import 'package:student_survivor/features/subjects/subjects_view_model.dart';

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
          body: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubjectDetailScreen(subject: subject),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    subject.accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.menu_book,
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
                                        ?.copyWith(fontWeight: FontWeight.w600),
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
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${subject.chapters.length} chapters',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.5 + (index * 0.1),
                          backgroundColor: AppColors.outline,
                          color: subject.accentColor,
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
