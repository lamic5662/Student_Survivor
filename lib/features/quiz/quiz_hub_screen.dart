import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/quiz/ai_exam_simulator_screen.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  QuizHubPresenter createPresenter() => QuizHubPresenter();

  @override
  void initState() {
    super.initState();
    _ensureIntroController();
    _triggerIntro();
    AppState.gameHubVisits.addListener(_handleGameHubVisit);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    AppState.gameHubVisits.removeListener(_handleGameHubVisit);
    _introTimer?.cancel();
    _introController?.dispose();
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
            child: CircularProgressIndicator(
              color: Color(0xFF4FA3C7),
            ),
          );
        }
        if (model.errorMessage != null) {
          return Center(
            child: Text(
              model.errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
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
                    context.tr(
                      'Select a semester to start playing.',
                      'खेल सुरु गर्न सेमेस्टर छान्नुहोस्।',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryActionButton(
                    label:
                        context.tr('Choose Semester', 'सेमेस्टर छान्नुहोस्'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + kToolbarHeight - 44,
            20,
            28,
          ),
          itemCount: model.subjects.isEmpty
              ? 9
              : 8 + model.subjects.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return RepaintBoundary(
                child: _GameHubHero(
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
              );
            }
            if (index == 1) return const SizedBox(height: 20);
            if (index == 2) {
              return RepaintBoundary(
                child: _GameStatStrip(
                  semesterName: model.semesterName,
                  subjectCount: model.subjects.length,
                ),
              );
            }
            if (index == 3) return const SizedBox(height: 24);
            if (index == 4) {
              return _ExamSimulatorCard(
                onStart: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AiExamSimulatorScreen(),
                    ),
                  );
                },
              );
            }
            if (index == 5) return const SizedBox(height: 24);
            if (index == 6) {
              return Text(
                context.tr('Select a subject', 'विषय छान्नुहोस्'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              );
            }
            if (index == 7) return const SizedBox(height: 12);
            if (model.subjects.isEmpty) {
              return Text(
                context.tr(
                  'No subjects available for this semester yet.',
                  'यस सेमेस्टरका लागि कुनै विषय उपलब्ध छैन।',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              );
            }
            final subject = model.subjects[index - 8];
            return RepaintBoundary(child: _SubjectCard(subject: subject));
          },
        );
      },
    );
    final appBar = AppBar(
      title: AnimatedOpacity(
        opacity: _showTitle ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          context.tr('Game Hub', 'गेम हब'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
    return GameZoneScaffold(
      appBar: appBar,
      body: content,
      overlay: _showIntro ? _buildIntroOverlay(context) : null,
      extendBodyBehindAppBar: true,
      useSafeArea: false,
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
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E2A44)),
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
                    text: context.tr(
                      'Welcome to the Gaming Zone',
                      'गेमिङ जोनमा स्वागत छ',
                    ),
                    controller: _introController,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('Learn with fun', 'आनन्दसँग सिक्नुहोस्'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF4FA3C7),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('Tap to continue', 'जारी राख्न ट्याप गर्नुहोस्'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
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
    final l10n = context.l10n;
    return _GameCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: const Icon(Icons.sports_esports_rounded,
                color: Color(0xFF4FA3C7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Game Zone', 'गेम जोन'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Pick a subject and enter the arena.',
                    'विषय छान्नुहोस् र खेलमा प्रवेश गर्नुहोस्।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroChip(
                        label: semesterName.isEmpty
                            ? context.tr('Semester', 'सेमेस्टर')
                            : semesterName),
                    _HeroChip(label: l10n.subjectsCount(subjects)),
                    _HeroChip(label: l10n.chaptersCount(chapters)),
                    _HeroChip(label: l10n.quizzesCount(quizzes)),
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
        color: const Color(0xFF111B2E),
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

class _GameStatStrip extends StatelessWidget {
  final String semesterName;
  final int subjectCount;

  const _GameStatStrip({
    required this.semesterName,
    required this.subjectCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _GameCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.school_rounded, color: Color(0xFF4FA3C7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              semesterName.isEmpty
                  ? context.tr('Semester not selected', 'सेमेस्टर छानिएको छैन')
                  : semesterName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: Text(
              l10n.subjectsCount(subjectCount),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white70),
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
      child: _GameCard(
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
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E2A44)),
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
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subject.chapters.length} chapters • $quizCount quizzes',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Text(
                  'Play',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF4FA3C7),
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

class _ExamSimulatorCard extends StatelessWidget {
  final VoidCallback onStart;

  const _ExamSimulatorCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF4FA3C7)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('AI Exam Simulator', 'एआई परीक्षा सिमुलेटर'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Timed exam with AI questions.',
                    'एआई प्रश्नसहित समयबद्ध परीक्षा।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FA3C7),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(context.tr('Start', 'सुरु')),
          ),
        ],
      ),
    );
  }
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
            Color(0xFF4FA3C7),
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

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4FA3C7),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FA3C7).withValues(alpha: 0.35),
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
