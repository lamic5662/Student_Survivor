import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/core/widgets/tag.dart';
import 'package:student_survivor/features/dashboard/dashboard_presenter.dart';
import 'package:student_survivor/features/dashboard/dashboard_view_model.dart';
import 'package:student_survivor/features/ai/ai_coach_screen.dart';
import 'package:student_survivor/features/notices/bca_notices_screen.dart';
import 'package:student_survivor/features/planner/planner_screen.dart';
import 'package:student_survivor/features/progress/progress_screen.dart';
import 'package:student_survivor/features/search/search_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState
    extends PresenterState<DashboardScreen, DashboardView, DashboardPresenter>
    implements DashboardView {
  @override
  DashboardPresenter createPresenter() => DashboardPresenter();

  @override
  void openPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlannerScreen()),
    );
  }

  @override
  void openProgress() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProgressScreen()),
    );
  }

  @override
  void openCoach() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiCoachScreen()),
    );
  }

  @override
  void openNotices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BcaNoticesScreen()),
    );
  }

  @override
  void openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  @override
  void openSyllabus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SyllabusScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: presenter.onSearch,
          ),
        ],
      ),
      body: ValueListenableBuilder<DashboardViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          if (model.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (model.errorMessage != null) {
            return Center(child: Text(model.errorMessage!));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _HeroCard(model: model),
              const SizedBox(height: 20),
              _CoachCard(onOpen: presenter.onCoach),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _QuickActions(
                onPlanner: presenter.onPlanner,
                onSyllabus: presenter.onSyllabus,
                onProgress: presenter.onProgress,
                onNotices: presenter.onNotices,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Progress Snapshot'),
              const SizedBox(height: 12),
              _SnapshotRow(
                xp: model.xp,
                gamesPlayed: model.gamesPlayed,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Weak Topics'),
              const SizedBox(height: 12),
              _WeakTopics(topics: model.weakTopics),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Recommended Notes'),
              const SizedBox(height: 12),
              if (model.recommendedNotes.isEmpty)
                const Text('No recommendations yet.')
              else
                ...model.recommendedNotes.map(
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
                                .bodyMedium
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                          const SizedBox(height: 12),
                          const Tag(label: 'AI pick'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DashboardViewModel model;

  const _HeroCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Text(
                  model.profile.name
                      .split(' ')
                      .map((part) => part.isNotEmpty ? part[0] : '')
                      .take(2)
                      .join(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    Text(
                      model.profile.name.split(' ').first,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              _HeroChip(label: _percent(model.progress)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'You are ${_percent(model.progress)} through ${model.profile.semester.name}.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: model.progress,
            backgroundColor: Colors.white,
            color: AppColors.accent,
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Tag(label: 'AI Adaptive'),
              if (model.latestAttempt != null)
                Tag(
                  label: model.latestAttempt!.isPass ? 'Pass' : 'Fail',
                  color: model.latestAttempt!.isPass
                      ? AppColors.success
                      : AppColors.danger,
                )
              else
                const Tag(label: 'No attempts'),
              _HeroChip(label: model.profile.semester.name),
            ],
          ),
        ],
      ),
    );
  }

  String _percent(double value) => '${(value * 100).round()}%';
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.mutedInk, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _CoachCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Personal Coach',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Weak topics, daily plan, and 10 questions.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onOpen,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onPlanner;
  final VoidCallback onSyllabus;
  final VoidCallback onProgress;
  final VoidCallback onNotices;

  const _QuickActions({
    required this.onPlanner,
    required this.onSyllabus,
    required this.onProgress,
    required this.onNotices,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.event_note,
                color: AppColors.secondary,
                label: 'Study Planner',
                subtitle: 'Plan your week',
                onTap: onPlanner,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.insights,
                color: AppColors.accent,
                label: 'Progress',
                subtitle: 'Track growth',
                onTap: onProgress,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.list_alt,
                color: AppColors.warning,
                label: 'Syllabus',
                subtitle: 'Official PDFs',
                onTap: onSyllabus,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.campaign_rounded,
                color: AppColors.success,
                label: 'BCA Notices',
                subtitle: 'TU updates',
                onTap: onNotices,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  final int xp;
  final int gamesPlayed;

  const _SnapshotRow({
    required this.xp,
    required this.gamesPlayed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SnapshotCard(
            label: 'XP earned',
            value: xp.toString(),
            icon: Icons.bolt,
            accent: AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SnapshotCard(
            label: 'Games played',
            value: gamesPlayed.toString(),
            icon: Icons.sports_esports,
            accent: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SnapshotCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakTopics extends StatelessWidget {
  final List<WeakTopic> topics;

  const _WeakTopics({required this.topics});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const Text('No weak topics detected yet.');
    }
    return Column(
      children: topics
          .map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber, color: AppColors.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
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
                          const SizedBox(height: 4),
                          Text(
                            topic.reason,
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
              ),
            ),
          )
          .toList(),
    );
  }
}
