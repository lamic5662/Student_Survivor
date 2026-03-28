import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_study_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectDetailScreen extends StatelessWidget {
  final Subject subject;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: subject.accentColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: subject.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.menu_book, color: subject.accentColor),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.code,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    Text(
                      '${subject.chapters.length} chapters',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if ((subject.syllabusUrl ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          onPressed: () => _openSyllabus(
                            context,
                            subject.name,
                            subject.syllabusUrl!,
                          ),
                          icon: const Icon(Icons.description_rounded, size: 18),
                          label: const Text('Open syllabus'),
                        ),
                      ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (subject.pastPapers.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Past Question Papers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...subject.pastPapers.map(
                    (paper) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              paper.year == null
                                  ? paper.title
                                  : '${paper.title} (${paper.year})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _openSyllabus(
                              context,
                              paper.title,
                              paper.fileUrl,
                            ),
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study the Whole Subject',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate AI notes, subject-level questions, and flashcards.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SubjectStudyScreen(subject: subject),
                      ),
                    );
                  },
                  child: const Text('Open Subject Study'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...subject.chapters.map(
            (chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChapterDetailScreen(
                          subject: subject,
                          chapter: chapter,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${chapter.notes.length} notes, '
                        '${chapter.importantQuestions.length} important questions, '
                        '${chapter.quizzes.length} quizzes',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: 0.35,
                        backgroundColor: AppColors.outline,
                        color: subject.accentColor,
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSyllabus(BuildContext context, String title, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid syllabus link.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(title: title, url: uri.toString()),
      ),
    );
  }
}
