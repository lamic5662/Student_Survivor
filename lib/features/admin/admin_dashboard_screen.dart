import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/admin/admin_notes_screen.dart';
import 'package:student_survivor/features/admin/admin_questions_screen.dart';
import 'package:student_survivor/features/admin/admin_syllabus_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  final ValueChanged<int>? onNavigate;

  const AdminDashboardScreen({super.key, this.onLogout, this.onNavigate});

  void _openSyllabus(BuildContext context) {
    if (onNavigate != null) {
      onNavigate!(1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminSyllabusScreen(onLogout: onLogout),
      ),
    );
  }

  void _openNotes(BuildContext context) {
    if (onNavigate != null) {
      onNavigate!(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminNotesScreen(onLogout: onLogout),
      ),
    );
  }

  void _openQuestions(BuildContext context) {
    if (onNavigate != null) {
      onNavigate!(3);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminQuestionsScreen(onLogout: onLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppState.profile.value;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          if (onLogout != null)
            IconButton(
              tooltip: 'Logout',
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
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
      ),
    );
  }
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
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
            ],
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
