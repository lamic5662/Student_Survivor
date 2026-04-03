import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/dashboard/dashboard_presenter.dart';
import 'package:student_survivor/features/dashboard/dashboard_view_model.dart';
import 'package:student_survivor/features/ai/ai_coach_screen.dart';
import 'package:student_survivor/features/books/free_books_screen.dart';
import 'package:student_survivor/features/programming_world/programming_world_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

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
  void openBooks() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FreeBooksScreen()),
    );
  }

  @override
  void openProgrammingWorld() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProgrammingWorldScreen()),
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
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Dashboard',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: presenter.onSearch,
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _DashboardBackdrop()),
          ValueListenableBuilder<DashboardViewModel>(
            valueListenable: presenter.state,
            builder: (context, model, _) {
              if (model.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              if (model.errorMessage != null) {
                return Center(
                  child: Text(
                    model.errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                );
              }
              return ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  kToolbarHeight + 36,
                  20,
                  28,
                ),
                children: [
                  _HeroCard(model: model),
                  const SizedBox(height: 20),
                  _CoachCard(onOpen: presenter.onCoach),
                  const SizedBox(height: 20),
                  const _GameSectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _QuickActions(
                    onPlanner: presenter.onPlanner,
                    onSyllabus: presenter.onSyllabus,
                    onProgress: presenter.onProgress,
                    onNotices: presenter.onNotices,
                    onBooks: presenter.onBooks,
                    onProgrammingWorld: presenter.onProgrammingWorld,
                  ),
                  const SizedBox(height: 24),
                  const _GameSectionHeader(title: 'Progress Snapshot'),
                  const SizedBox(height: 12),
                  _SnapshotRow(
                    xp: model.xp,
                    gamesPlayed: model.gamesPlayed,
                  ),
                  const SizedBox(height: 24),
                  const _GameSectionHeader(title: 'Weak Topics'),
                  const SizedBox(height: 12),
                  _WeakTopics(topics: model.weakTopics),
                  const SizedBox(height: 24),
                  const _GameSectionHeader(title: 'Recommended Notes'),
                  const SizedBox(height: 12),
                  if (model.recommendedNotes.isEmpty)
                    Text(
                      'No recommendations yet.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    )
                  else
                    ...model.recommendedNotes.map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                note.shortAnswer,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 12),
                              const _GameTag(label: 'AI pick'),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _DashboardGridPainter())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _DashboardGridPainter extends CustomPainter {
  const _DashboardGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashboardGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GameCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}

class _GameSectionHeader extends StatelessWidget {
  final String title;

  const _GameSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF38BDF8),
                Color(0xFF4F46E5),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ),
      ],
    );
  }
}

class _GameTag extends StatelessWidget {
  final String label;
  final Color accent;

  const _GameTag({
    required this.label,
    this.accent = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GameActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final DashboardViewModel model;

  const _HeroCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF38BDF8),
                      Color(0xFF4F46E5),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Center(
                  child: Text(
                    model.profile.name
                        .split(' ')
                        .map((part) => part.isNotEmpty ? part[0] : '')
                        .take(2)
                        .join(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
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
                          ?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      model.profile.name.split(' ').first,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
              _HeroChip(label: _percent(model.progress)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Overall progress: ${_percent(model.progress)} for ${model.profile.semester.name}.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: model.progress,
              backgroundColor: const Color(0xFF1E2A44),
              color: const Color(0xFF38BDF8),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _GameTag(label: 'AI Adaptive'),
              if (model.latestAttempt != null)
                _GameTag(
                  label: model.latestAttempt!.isPass ? 'Pass' : 'Fail',
                  accent: model.latestAttempt!.isPass
                      ? AppColors.success
                      : AppColors.danger,
                )
              else
                const _GameTag(label: 'No attempts'),
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
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _CoachCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8)),
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
                      ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Weak topics, daily plan, and 10 questions.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _GameActionButton(
            label: 'Open',
            onPressed: onOpen,
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
  final VoidCallback onBooks;
  final VoidCallback onProgrammingWorld;

  const _QuickActions({
    required this.onPlanner,
    required this.onSyllabus,
    required this.onProgress,
    required this.onNotices,
    required this.onBooks,
    required this.onProgrammingWorld,
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
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.auto_stories_rounded,
                color: AppColors.secondary,
                label: 'Free Books',
                subtitle: 'Open textbooks',
                onTap: onBooks,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _QuickActionCard(
                icon: Icons.code_rounded,
                color: AppColors.accent,
                label: 'Programming World',
                subtitle: 'Tracks & practice',
                onTap: onProgrammingWorld,
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
    return _GameCard(
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
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E2A44)),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2A44)),
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
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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
      return const Text(
        'No weak topics detected yet.',
        style: TextStyle(color: Colors.white70),
      );
    }
    return Column(
      children: topics
          .map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GameCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E2A44)),
                      ),
                      child:
                          const Icon(Icons.warning_amber, color: AppColors.danger),
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            topic.reason,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white54),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
