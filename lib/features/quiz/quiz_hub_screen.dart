import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/quiz/quiz_hub_presenter.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizHubScreen extends StatefulWidget {
  const QuizHubScreen({super.key});

  @override
  State<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState
    extends PresenterState<QuizHubScreen, QuizHubView, QuizHubPresenter>
    with SingleTickerProviderStateMixin
    implements QuizHubView {
  bool _showIntro = true;
  Timer? _introTimer;
  AnimationController? _introController;

  @override
  QuizHubPresenter createPresenter() => QuizHubPresenter();

  @override
  void initState() {
    super.initState();
    _ensureIntroController();
    _triggerIntro();
    AppState.gameHubVisits.addListener(_handleGameHubVisit);
  }

  @override
  void dispose() {
    AppState.gameHubVisits.removeListener(_handleGameHubVisit);
    _introTimer?.cancel();
    _introController?.dispose();
    super.dispose();
  }

  void _ensureIntroController() {
    _introController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  void _handleGameHubVisit() {
    if (!mounted) return;
    _triggerIntro();
  }

  void _dismissIntro() {
    if (!_showIntro) return;
    setState(() => _showIntro = false);
  }

  void _triggerIntro() {
    _introTimer?.cancel();
    if (mounted) {
      setState(() => _showIntro = true);
    } else {
      _showIntro = true;
    }
    _ensureIntroController();
    _introController?.forward(from: 0);
    _introTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _dismissIntro();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ValueListenableBuilder<QuizHubViewModel>(
      valueListenable: presenter.state,
      builder: (context, model, _) {
        if (model.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        if (model.errorMessage != null) {
          return Center(
            child: Text(
              model.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }
        if (model.semesterName.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select a semester to start playing.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      );
                    },
                    child: const Text('Choose Semester'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GameHubHero(
              semesterName: model.semesterName,
              subjects: model.subjects.length,
              chapters: model.subjects.fold<int>(
                0,
                (sum, subject) => sum + subject.chapters.length,
              ),
              quizzes: model.subjects.fold<int>(
                0,
                (sum, subject) =>
                    sum +
                    subject.chapters.fold<int>(
                      0,
                      (count, chapter) => count + chapter.quizzes.length,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            _GameStatStrip(
              semesterName: model.semesterName,
              subjectCount: model.subjects.length,
            ),
            const SizedBox(height: 24),
            Text(
              'Select a subject',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (model.subjects.isEmpty)
              Text(
                'No subjects available for this semester yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.mutedInk),
              )
            else
              ...model.subjects.map((subject) => _SubjectCard(subject: subject)),
          ],
        );
      },
    );
    return GameZoneScaffold(
      body: content,
      overlay: _showIntro ? _buildIntroOverlay(context) : null,
    );
  }

  Widget _buildIntroOverlay(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissIntro,
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Transform.scale(
              scale: value,
              child: child,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StaggeredWords(
                    text: 'Welcome to the Gaming Zone',
                    controller: _introController,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn with fun',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to continue',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedInk,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameHubHero extends StatelessWidget {
  final String semesterName;
  final int subjects;
  final int chapters;
  final int quizzes;

  const _GameHubHero({
    required this.semesterName,
    required this.subjects,
    required this.chapters,
    required this.quizzes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.sports_esports_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game Zone',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pick a subject and enter the arena.',
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
                    _HeroChip(label: semesterName.isEmpty ? 'Semester' : semesterName),
                    _HeroChip(label: '$subjects subjects'),
                    _HeroChip(label: '$chapters chapters'),
                    _HeroChip(label: '$quizzes quizzes'),
                  ],
                ),
              ],
            ),
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

class _GameStatStrip extends StatelessWidget {
  final String semesterName;
  final int subjectCount;

  const _GameStatStrip({
    required this.semesterName,
    required this.subjectCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              semesterName.isEmpty ? 'Semester not selected' : semesterName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$subjectCount subjects',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaggeredWords extends StatelessWidget {
  final String text;
  final AnimationController? controller;
  final TextStyle? style;
  final TextAlign textAlign;

  const _StaggeredWords({
    required this.text,
    required this.controller,
    this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = controller;
    if (resolved == null) {
      return Text(
        text,
        textAlign: textAlign,
        style: style,
      );
    }
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    final WrapAlignment alignment;
    if (textAlign == TextAlign.center) {
      alignment = WrapAlignment.center;
    } else if (textAlign == TextAlign.right || textAlign == TextAlign.end) {
      alignment = WrapAlignment.end;
    } else {
      alignment = WrapAlignment.start;
    }

    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < words.length; i++)
          _AnimatedWord(
            word: words[i],
            controller: resolved,
            index: i,
            total: words.length,
            style: style,
          ),
      ],
    );
  }
}

class _AnimatedWord extends StatelessWidget {
  final String word;
  final AnimationController controller;
  final int index;
  final int total;
  final TextStyle? style;

  const _AnimatedWord({
    required this.word,
    required this.controller,
    required this.index,
    required this.total,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / (total + 3)).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: animation.drive(
          Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero),
        ),
        child: Text(word, style: style),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final quizCount = subject.chapters.fold<int>(
      0,
      (sum, chapter) => sum + chapter.quizzes.length,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubjectDetailScreen(
                  subject: subject,
                  useGameZoneTheme: true,
                ),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: subject.accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.sports_esports, color: subject.accentColor),
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
                    const SizedBox(height: 4),
                    Text(
                      '${subject.chapters.length} chapters • $quizCount quizzes',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: subject.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Play',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: subject.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
