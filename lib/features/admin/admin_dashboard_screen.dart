import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/admin_service.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_notes_screen.dart';
import 'package:student_survivor/features/admin/admin_questions_screen.dart';
import 'package:student_survivor/features/admin/admin_syllabus_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final ValueChanged<int>? onNavigate;

  const AdminDashboardScreen({super.key, this.onLogout, this.onNavigate});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminService _adminService;
  late final SubjectService _subjectService;
  String? _deletingNoteId;
  String? _deletingQuestionId;
  String? _clearingSyllabusId;
  int _pendingSubmissionCount = 0;
  bool _isPendingCountLoading = false;

  @override
  void initState() {
    super.initState();
    final client = SupabaseConfig.client;
    _adminService = AdminService(client);
    _subjectService = SubjectService(client);
    _loadPendingCount();
  }

  void _openSyllabus(BuildContext context) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminSyllabusScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openNotes(BuildContext context) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminNotesScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openQuestions(BuildContext context) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(3);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminQuestionsScreen(onLogout: widget.onLogout),
      ),
    );
  }

  Future<void> _refreshProfileContent() async {
    final profile = AppState.profile.value;
    if (profile.semester.id.isEmpty) {
      return;
    }
    final subjects = await _subjectService.fetchSubjectsForSemester(
      profile.semester.id,
      includeContent: true,
    );
    AppState.updateProfile(
      UserProfile(
        name: profile.name,
        email: profile.email,
        semester: profile.semester,
        subjects: subjects,
        isAdmin: profile.isAdmin,
      ),
    );
  }

  Future<void> _loadPendingCount() async {
    setState(() {
      _isPendingCountLoading = true;
    });
    try {
      final count = await _adminService.fetchPendingNoteSubmissionCount();
      if (!mounted) return;
      setState(() {
        _pendingSubmissionCount = count;
        _isPendingCountLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPendingCountLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteNote(_DashboardNoteItem item) async {
    if (_deletingNoteId == item.note.id) return;
    final confirmed = await _confirmAction(
      title: 'Delete note?',
      message: 'Delete "${item.note.title}"? This cannot be undone.',
    );
    if (!confirmed) return;
    setState(() {
      _deletingNoteId = item.note.id;
    });
    try {
      await _adminService.deleteNote(item.note.id);
      await _refreshProfileContent();
      _showMessage('Note deleted.');
    } catch (error) {
      _showMessage('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }

  Future<void> _deleteQuestion(_DashboardQuestionItem item) async {
    if (_deletingQuestionId == item.question.id) return;
    final confirmed = await _confirmAction(
      title: 'Delete question?',
      message: 'Delete this question? This cannot be undone.',
    );
    if (!confirmed) return;
    setState(() {
      _deletingQuestionId = item.question.id;
    });
    try {
      await _adminService.deleteQuestion(item.question.id);
      await _refreshProfileContent();
      _showMessage('Question deleted.');
    } catch (error) {
      _showMessage('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingQuestionId = null;
        });
      }
    }
  }

  Future<void> _clearSyllabus(_DashboardSyllabusItem item) async {
    if (_clearingSyllabusId == item.subject.id) return;
    final confirmed = await _confirmAction(
      title: 'Remove syllabus?',
      message:
          'Remove the syllabus for "${item.subject.name}"? This will delete the stored file and unlink it.',
    );
    if (!confirmed) return;
    setState(() {
      _clearingSyllabusId = item.subject.id;
    });
    try {
      await _adminService.deleteSyllabusFile(
        subjectId: item.subject.id,
        syllabusUrl: item.subject.syllabusUrl ?? '',
      );
      await _refreshProfileContent();
      _showMessage('Syllabus removed.');
    } catch (error) {
      _showMessage('Remove failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _clearingSyllabusId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadPendingCount,
            icon: _isPendingCountLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Logout',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: AppState.profile,
        builder: (context, profile, _) {
          final subjects = profile.subjects;
          final subjectCount = subjects.length;
          final chapterCount = subjects.fold<int>(
            0,
            (total, subject) => total + subject.chapters.length,
          );
          final noteCount = subjects.fold<int>(
            0,
            (total, subject) => total + subject.chapters.fold<int>(
                  0,
                  (sum, chapter) => sum + chapter.notes.length,
                ),
          );
          final questionCount = subjects.fold<int>(
            0,
            (total, subject) => total + subject.chapters.fold<int>(
                  0,
                  (sum, chapter) =>
                      sum +
                      chapter.importantQuestions.length +
                      chapter.pastQuestions.length,
                ),
          );
          final syllabusCount =
              subjects.where((s) => (s.syllabusUrl ?? '').isNotEmpty).length;

          final recentNotes = _collectRecentNotes(subjects, limit: 3);
          final recentQuestions = _collectRecentQuestions(subjects, limit: 3);
          final recentSyllabus = _collectRecentSyllabus(subjects, limit: 3);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeroBanner(name: profile.name),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 980;
                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: wide ? 2.4 : 1.85,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatTile(
                            label: 'Subjects',
                            value: subjectCount,
                            icon: Icons.menu_book,
                            color: AppColors.secondary,
                          ),
                          _StatTile(
                            label: 'Chapters',
                            value: chapterCount,
                            icon: Icons.layers,
                            color: AppColors.accent,
                          ),
                          _StatTile(
                            label: 'Notes',
                            value: noteCount,
                            icon: Icons.description,
                            color: AppColors.success,
                          ),
                          _StatTile(
                            label: 'Questions',
                            value: questionCount,
                            icon: Icons.quiz,
                            color: AppColors.warning,
                          ),
                          _StatTile(
                            label: 'Syllabus',
                            value: syllabusCount,
                            icon: Icons.auto_stories,
                            color: AppColors.secondary,
                          ),
                          _StatTile(
                            label: 'Pending Notes',
                            value: _isPendingCountLoading
                                ? 0
                                : _pendingSubmissionCount,
                            icon: Icons.pending_actions,
                            color: AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Quick actions',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: wide ? 2 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: wide ? 2.3 : 1.6,
                        children: [
                          _ActionCard(
                            title: 'Syllabus',
                            description:
                                'Upload PDFs or manage semesters, subjects, and chapters.',
                            icon: Icons.auto_stories,
                            color: AppColors.secondary,
                            actionLabel: 'Open Syllabus',
                            onAction: () => _openSyllabus(context),
                          ),
                          _ActionCard(
                            title: 'Notes',
                            description:
                                'Publish chapter notes or subject-wide notes.',
                            icon: Icons.note_alt,
                            color: AppColors.accent,
                            actionLabel: 'Open Notes',
                            onAction: () => _openNotes(context),
                          ),
                          _ActionCard(
                            title: 'Questions & Quizzes',
                            description:
                                'Publish questions, past papers, and quizzes.',
                            icon: Icons.quiz,
                            color: AppColors.warning,
                            actionLabel: 'Open Questions',
                            onAction: () => _openQuestions(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Recently published',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _RecentSectionCard(
                        title: 'Notes',
                        actionLabel: 'Manage',
                        onAction: () => _openNotes(context),
                        emptyLabel: 'No notes published yet.',
                        items: recentNotes
                            .map(
                              (note) => _RecentItem(
                                title: note.note.title,
                                subtitle:
                                    '${note.subject.name} • ${note.chapter.title}',
                                description: note.note.shortAnswer.isNotEmpty
                                    ? note.note.shortAnswer
                                    : note.note.detailedAnswer,
                                icon: Icons.note_alt_outlined,
                                onTap: () => _openNotes(context),
                                onDelete: () => _deleteNote(note),
                                isDeleting: _deletingNoteId == note.note.id,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _RecentSectionCard(
                        title: 'Questions',
                        actionLabel: 'Manage',
                        onAction: () => _openQuestions(context),
                        emptyLabel: 'No questions published yet.',
                        items: recentQuestions
                            .map(
                              (question) => _RecentItem(
                                title: question.question.prompt,
                                subtitle:
                                    '${question.subject.name} • ${question.chapter.title}',
                                description: question.question.kind,
                                icon: Icons.quiz_outlined,
                                onTap: () => _openQuestions(context),
                                onDelete: () => _deleteQuestion(question),
                                isDeleting:
                                    _deletingQuestionId == question.question.id,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      _RecentSectionCard(
                        title: 'Syllabus',
                        actionLabel: 'Manage',
                        onAction: () => _openSyllabus(context),
                        emptyLabel: 'No syllabus uploaded yet.',
                        items: recentSyllabus
                            .map(
                              (item) => _RecentItem(
                                title: item.subject.name,
                                subtitle: item.subject.code.isEmpty
                                    ? 'Syllabus attached'
                                    : item.subject.code,
                                description: 'Tap to preview',
                                icon: Icons.auto_stories_outlined,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SyllabusWebViewScreen(
                                        title: item.subject.name,
                                        url: item.subject.syllabusUrl!,
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () => _clearSyllabus(item),
                                isDeleting:
                                    _clearingSyllabusId == item.subject.id,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );

                  if (!wide) {
                    return leftColumn;
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardNoteItem {
  final Subject subject;
  final Chapter chapter;
  final Note note;

  const _DashboardNoteItem({
    required this.subject,
    required this.chapter,
    required this.note,
  });
}

class _DashboardQuestionItem {
  final Subject subject;
  final Chapter chapter;
  final Question question;

  const _DashboardQuestionItem({
    required this.subject,
    required this.chapter,
    required this.question,
  });
}

class _DashboardSyllabusItem {
  final Subject subject;

  const _DashboardSyllabusItem({
    required this.subject,
  });
}

List<_DashboardNoteItem> _collectRecentNotes(
  List<Subject> subjects, {
  int limit = 3,
}) {
  final items = <_DashboardNoteItem>[];
  for (final subject in subjects) {
    for (final chapter in subject.chapters) {
      for (final note in chapter.notes) {
        items.add(
          _DashboardNoteItem(
            subject: subject,
            chapter: chapter,
            note: note,
          ),
        );
      }
    }
  }
  if (items.isEmpty) return items;
  return items.reversed.take(limit).toList();
}

List<_DashboardQuestionItem> _collectRecentQuestions(
  List<Subject> subjects, {
  int limit = 3,
}) {
  final items = <_DashboardQuestionItem>[];
  for (final subject in subjects) {
    for (final chapter in subject.chapters) {
      for (final question in [
        ...chapter.importantQuestions,
        ...chapter.pastQuestions,
      ]) {
        items.add(
          _DashboardQuestionItem(
            subject: subject,
            chapter: chapter,
            question: question,
          ),
        );
      }
    }
  }
  if (items.isEmpty) return items;
  return items.reversed.take(limit).toList();
}

List<_DashboardSyllabusItem> _collectRecentSyllabus(
  List<Subject> subjects, {
  int limit = 3,
}) {
  final items = subjects
      .where((subject) => (subject.syllabusUrl ?? '').isNotEmpty)
      .map((subject) => _DashboardSyllabusItem(subject: subject))
      .toList();
  if (items.isEmpty) return items;
  return items.reversed.take(limit).toList();
}

class _HeroBanner extends StatelessWidget {
  final String name;

  const _HeroBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Publish syllabus, notes, and quizzes faster with clean workflows.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(label: 'Fast publishing'),
              _HeroChip(label: 'Admin only'),
              _HeroChip(label: 'Quality checks'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentSectionCard extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final List<_RecentItem> items;
  final String emptyLabel;

  const _RecentSectionCard({
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.items,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.mutedInk),
                              ),
                              if (item.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  item.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (item.onDelete != null) ...[
                          item.isDeleting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Delete',
                                  onPressed: item.onDelete,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                        ],
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.mutedInk,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _RecentItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDeleting;

  const _RecentItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.onTap,
    this.onDelete,
    this.isDeleting = false,
  });
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback onAction;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
