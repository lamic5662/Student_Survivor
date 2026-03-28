import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_study_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late final UserNotesService _userNotesService;
  Map<String, int> _userNoteCounts = const {};

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _loadUserNotes();
  }

  Future<void> _loadUserNotes() async {
    final chapterIds = widget.subject.chapters.map((c) => c.id).toList();
    if (chapterIds.isEmpty) {
      setState(() {
        _userNoteCounts = const {};
      });
      return;
    }
    try {
      final notes = await _userNotesService.fetchForSubject(chapterIds);
      if (!mounted) return;
      final counts = <String, int>{};
      for (final note in notes) {
        final chapterId = note.chapterId;
        if (chapterId == null || chapterId.isEmpty) {
          continue;
        }
        counts[chapterId] = (counts[chapterId] ?? 0) + 1;
      }
      setState(() {
        _userNoteCounts = counts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userNoteCounts = const {};
      });
    }
  }

  int _totalNotesFor(Chapter chapter) {
    final userNotes = _userNoteCounts[chapter.id] ?? 0;
    return chapter.notes.length + userNotes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: widget.subject.accentColor.withValues(alpha: 0.1),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.subject.accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.menu_book, color: widget.subject.accentColor),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.subject.code,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    Text(
                      '${widget.subject.chapters.length} chapters',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if ((widget.subject.syllabusUrl ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton.icon(
                          onPressed: () => _openSyllabus(
                            context,
                            widget.subject.name,
                            widget.subject.syllabusUrl!,
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
          if (widget.subject.pastPapers.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Past Question Papers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...widget.subject.pastPapers.map(
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
                            SubjectStudyScreen(subject: widget.subject),
                      ),
                    );
                  },
                  child: const Text('Open Subject Study'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...widget.subject.chapters.map(
            (chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AppCard(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                        builder: (_) => ChapterDetailScreen(
                          subject: widget.subject,
                          chapter: chapter,
                        ),
                      ),
                    )
                        .then((_) => _loadUserNotes());
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
                        '${_totalNotesFor(chapter)} notes, '
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
                        color: widget.subject.accentColor,
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
