import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class SyllabusScreen extends StatelessWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppState.profile,
      builder: (context, profile, _) {
        final subjects = profile.subjects;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Syllabus'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: subjects.isEmpty
                ? [const Text('Select a semester to view syllabus.')]
                : subjects
                    .map(
                      (subject) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
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
                              const SizedBox(height: 8),
                              Text(
                                _detailForSubject(subject),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.mutedInk),
                              ),
                              const SizedBox(height: 12),
                              _buildSyllabusAction(context, subject),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        );
      },
    );
  }

  String _detailForSubject(Subject subject) {
    if (subject.chapters.isEmpty) {
      return 'Chapters will appear once content is added.';
    }
    final titles = subject.chapters
        .take(4)
        .map((chapter) => chapter.title)
        .toList();
    return titles.isEmpty ? 'Content coming soon.' : titles.join(', ');
  }

  Widget _buildSyllabusAction(BuildContext context, Subject subject) {
    final url = subject.syllabusUrl?.trim() ?? '';
    if (url.isEmpty) {
      return Text(
        'Syllabus PDF not available yet.',
        style:
            Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.mutedInk),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _openSyllabus(context, subject.name, url),
        icon: const Icon(Icons.description_rounded, size: 18),
        label: const Text('Open syllabus'),
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
