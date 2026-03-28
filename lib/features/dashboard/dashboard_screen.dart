import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/core/widgets/stat_tile.dart';
import 'package:student_survivor/core/widgets/tag.dart';
import 'package:student_survivor/features/dashboard/dashboard_presenter.dart';
import 'package:student_survivor/features/dashboard/dashboard_view_model.dart';
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
              const SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 12),
              _QuickActions(
                onPlanner: presenter.onPlanner,
                onSyllabus: presenter.onSyllabus,
                onProgress: presenter.onProgress,
              ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Progress Snapshot'),
              const SizedBox(height: 12),
              Column(
                children: [
                  StatTile(
                    label: 'XP earned',
                    value: model.xp.toString(),
                    icon: Icons.bolt,
                    accent: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  StatTile(
                    label: 'Games played',
                    value: model.gamesPlayed.toString(),
                    icon: Icons.sports_esports,
                    accent: AppColors.secondary,
                  ),
                ],
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hey ${model.profile.name.split(' ').first},',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are ${_percent(model.progress)} through ${model.profile.semester.name}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: model.progress,
            backgroundColor: Colors.white24,
            color: AppColors.accent,
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Tag(label: 'AI Adaptive'),
              const SizedBox(width: 8),
              if (model.latestAttempt != null)
                Tag(
                  label: model.latestAttempt!.isPass ? 'Pass' : 'Fail',
                  color: model.latestAttempt!.isPass
                      ? AppColors.success
                      : AppColors.danger,
                )
              else
                const Tag(label: 'No attempts'),
            ],
          ),
        ],
      ),
    );
  }

  String _percent(double value) => '${(value * 100).round()}%';
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onPlanner;
  final VoidCallback onSyllabus;
  final VoidCallback onProgress;

  const _QuickActions({
    required this.onPlanner,
    required this.onSyllabus,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: onPlanner,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_note, color: AppColors.secondary),
                  const SizedBox(height: 12),
                  Text(
                    'Study Planner',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: onProgress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.insights, color: AppColors.accent),
                  const SizedBox(height: 12),
                  Text(
                    'Progress',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: onSyllabus,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.list_alt, color: AppColors.warning),
                  const SizedBox(height: 12),
                  Text(
                    'Syllabus',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
