import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/core/widgets/tag.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/quiz/quiz_play_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizAttempt attempt;
  final String quizId;
  final List<QuizAnswerReview> reviews;
  final bool useGameZoneTheme;

  const QuizResultScreen({
    super.key,
    required this.attempt,
    required this.quizId,
    this.reviews = const [],
    this.useGameZoneTheme = false,
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  late final QuizService _quizService;
  bool _isLoading = true;
  bool _isPracticeLoading = true;
  String? _errorMessage;
  List<Note> _recommendedNotes = const [];
  List<Question> _importantQuestions = const [];
  QuizContext? _practiceContext;

  @override
  void initState() {
    super.initState();
    _quizService = QuizService(SupabaseConfig.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final notes = await _quizService.fetchRecommendedNotes();
      final questions =
          await _quizService.fetchImportantQuestionsForQuiz(widget.quizId);
      final quizContext = await _quizService.fetchQuizContext(widget.quizId);
      if (!mounted) return;
      setState(() {
        _recommendedNotes = notes;
        _importantQuestions = questions;
        _practiceContext = quizContext;
        _isLoading = false;
        _isPracticeLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load recommendations: $error';
        _isLoading = false;
        _isPracticeLoading = false;
      });
    }
  }

  QuizDifficulty _recommendedDifficulty() {
    if (widget.attempt.total == 0) {
      return QuizDifficulty.easy;
    }
    final ratio = widget.attempt.score / widget.attempt.total;
    if (ratio >= 0.8) {
      return QuizDifficulty.hard;
    }
    if (ratio >= 0.6) {
      return QuizDifficulty.medium;
    }
    return QuizDifficulty.easy;
  }

  List<String> _coachTips() {
    final tips = <String>[];
    if (widget.attempt.total == 0) {
      return const ['Try a quiz to unlock feedback tips.'];
    }
    final ratio = widget.attempt.score / widget.attempt.total;
    final duration = widget.attempt.durationSeconds;
    if (duration != null && duration > 0) {
      final avg = duration / widget.attempt.total;
      if (avg > 75) {
        tips.add('You took a bit long per question. Practice with a timer.');
      } else if (avg < 20) {
        tips.add('Great speed! Slow down if you see mistakes.');
      }
    }
    if (ratio < 0.5) {
      tips.add('Revise the chapter notes before the next quiz.');
      tips.add('Start with Easy difficulty and rebuild confidence.');
    } else if (ratio < 0.8) {
      tips.add('Focus on weak topics and practice 5 MCQs each.');
      tips.add('Summarize each wrong answer in your own words.');
    } else {
      tips.add('Great work! Try Medium or Hard difficulty next.');
      tips.add('Challenge yourself with a timed quiz.');
    }
    if (widget.attempt.weakTopics.isNotEmpty) {
      tips.add('Weak topics: ${widget.attempt.weakTopics.first.name}.');
    }
    return tips;
  }

  void _startPractice() {
    final practiceContext = _practiceContext;
    if (practiceContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Practice quiz not ready yet.')),
      );
      return;
    }
    final baseQuiz = practiceContext.quiz;
    final recommended = _recommendedDifficulty();
    final practiceQuiz = Quiz(
      id: baseQuiz.id,
      title: 'AI Practice • ${baseQuiz.title}',
      type: baseQuiz.type,
      difficulty: recommended,
      questionCount: baseQuiz.questionCount > 0 ? baseQuiz.questionCount : 10,
      duration: baseQuiz.duration,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          quiz: practiceQuiz,
          subject: practiceContext.subject,
          chapter: practiceContext.chapter,
          isAi: true,
          useGameZoneTheme: widget.useGameZoneTheme,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('Quiz Result'),
      backgroundColor: widget.useGameZoneTheme ? AppColors.paper : null,
      foregroundColor: widget.useGameZoneTheme ? AppColors.ink : null,
      elevation: widget.useGameZoneTheme ? 0 : null,
      scrolledUnderElevation: widget.useGameZoneTheme ? 0 : null,
      surfaceTintColor: widget.useGameZoneTheme ? Colors.transparent : null,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );

    final content = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: widget.useGameZoneTheme
                ? AppColors.surface
                : widget.attempt.isPass
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.danger.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attempt.isPass ? 'Pass' : 'Fail',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.attempt.isPass
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score: ${widget.attempt.score}/${widget.attempt.total}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '+${widget.attempt.xpEarned} XP earned',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'AI Adaptive Learning'),
          const SizedBox(height: 12),
          if (widget.attempt.weakTopics.isEmpty)
            const Text('Great job! No weak topics detected.')
          else
            ...widget.attempt.weakTopics.map(
              (topic) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
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
                      const SizedBox(height: 6),
                      Text(
                        topic.reason,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 8),
                      const Tag(label: 'Needs revision'),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Recommended Notes'),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!)
          else if (_recommendedNotes.isEmpty)
            const Text('No recommendations yet.')
          else
            ..._recommendedNotes.map(
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
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Important Questions'),
          const SizedBox(height: 12),
          if (_isLoading)
            const SizedBox.shrink()
          else if (_importantQuestions.isEmpty)
            const Text('No important questions added yet.')
          else
            ..._importantQuestions.map(
              (question) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline, color: AppColors.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(question.prompt),
                      ),
                      Tag(label: '${question.marks} marks'),
                    ],
                  ),
                ),
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            color: AppColors.secondary.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach Feedback',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recommended difficulty: ${_recommendedDifficulty().name.toUpperCase()}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                ..._coachTips().map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Answer Review'),
          const SizedBox(height: 12),
          if (widget.reviews.isEmpty)
            const Text('Answer review is not available for this quiz.')
          else
            Builder(
              builder: (context) {
                final wrong =
                    widget.reviews.where((review) => !review.isCorrect).toList();
                if (wrong.isEmpty) {
                  return const Text('All answers were correct. Great job!');
                }
                return Column(
                  children: wrong.asMap().entries.map((entry) {
                    final review = entry.value;
                    final selected = review.selectedIndex;
                    final correct = review.correctIndex;
                    final selectedText = (selected != null &&
                            selected >= 0 &&
                            selected < review.options.length)
                        ? review.options[selected]
                        : 'Not answered';
                    final correctText = (correct >= 0 &&
                            correct < review.options.length)
                        ? review.options[correct]
                        : 'N/A';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.prompt,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your answer: $selectedText',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.danger),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Correct answer: $correctText',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.success),
                            ),
                            if (review.explanation != null &&
                                review.explanation!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                review.explanation!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.mutedInk),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'More Practice'),
          const SizedBox(height: 12),
          if (_isPracticeLoading)
            const Center(child: CircularProgressIndicator())
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Practice Questions',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Practice more questions based on your quiz performance.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recommended difficulty: ${_recommendedDifficulty().name.toUpperCase()}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _practiceContext == null ? null : _startPractice,
                      child: const Text('Start AI Practice'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (widget.useGameZoneTheme) {
      return GameZoneScaffold(
        appBar: appBar,
        body: content,
        useSafeArea: false,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
    );
  }
}
