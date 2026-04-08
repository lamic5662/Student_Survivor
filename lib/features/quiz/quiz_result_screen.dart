import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
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
        _errorMessage = context.tr(
          'Failed to load recommendations: $error',
          'सिफारिस लोड गर्न असफल: $error',
        );
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

  List<String> _coachTips(BuildContext context) {
    final tips = <String>[];
    if (widget.attempt.total == 0) {
      return [
        context.tr(
          'Try a quiz to unlock feedback tips.',
          'फिडब्याक सुझाव खोल्न क्विज प्रयास गर्नुहोस्।',
        ),
      ];
    }
    final ratio = widget.attempt.score / widget.attempt.total;
    final duration = widget.attempt.durationSeconds;
    if (duration != null && duration > 0) {
      final avg = duration / widget.attempt.total;
      if (avg > 75) {
        tips.add(
          context.tr(
            'You took a bit long per question. Practice with a timer.',
            'तपाईंले प्रत्येक प्रश्नमा धेरै समय लिनुभयो। टाइमरसँग अभ्यास गर्नुहोस्।',
          ),
        );
      } else if (avg < 20) {
        tips.add(
          context.tr(
            'Great speed! Slow down if you see mistakes.',
            'उत्तम गति! गल्ती देखिएमा अलि ढिलो गर्नुहोस्।',
          ),
        );
      }
    }
    if (ratio < 0.5) {
      tips.add(
        context.tr(
          'Revise the chapter notes before the next quiz.',
          'अर्को क्विज अघि अध्यायका नोटहरू दोहोर्याउनुहोस्।',
        ),
      );
      tips.add(
        context.tr(
          'Start with Easy difficulty and rebuild confidence.',
          'Easy कठिनाइबाट सुरु गरी आत्मविश्वास बढाउनुहोस्।',
        ),
      );
    } else if (ratio < 0.8) {
      tips.add(
        context.tr(
          'Focus on weak topics and practice 5 MCQs each.',
          'कमजोर विषयमा ध्यान दिनुहोस् र हरेक विषयका ५ MCQ अभ्यास गर्नुहोस्।',
        ),
      );
      tips.add(
        context.tr(
          'Summarize each wrong answer in your own words.',
          'प्रत्येक गलत उत्तर आफ्नो शब्दमा सारांश लेख्नुहोस्।',
        ),
      );
    } else {
      tips.add(
        context.tr(
          'Great work! Try Medium or Hard difficulty next.',
          'उत्कृष्ट! अब Medium वा Hard कठिनाइ प्रयास गर्नुहोस्।',
        ),
      );
      tips.add(
        context.tr(
          'Challenge yourself with a timed quiz.',
          'टाइम्ड क्विजसँग आफूलाई चुनौती दिनुहोस्।',
        ),
      );
    }
    if (widget.attempt.weakTopics.isNotEmpty) {
      tips.add(
        context.tr(
          'Weak topics: ${widget.attempt.weakTopics.first.name}.',
          'कमजोर विषय: ${widget.attempt.weakTopics.first.name}.',
        ),
      );
    }
    return tips;
  }

  void _startPractice() {
    final practiceContext = _practiceContext;
    if (practiceContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Practice quiz not ready yet.', 'अभ्यास क्विज अझै तयार छैन।'),
          ),
        ),
      );
      return;
    }
    final baseQuiz = practiceContext.quiz;
    final recommended = _recommendedDifficulty();
    final practiceQuiz = Quiz(
      id: baseQuiz.id,
      title: context.tr(
        'AI Practice • ${baseQuiz.title}',
        'AI अभ्यास • ${baseQuiz.title}',
      ),
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
      title: Text(context.tr('Quiz Result', 'क्विज नतिजा')),
      backgroundColor: widget.useGameZoneTheme ? AppColors.paper : null,
      foregroundColor: widget.useGameZoneTheme ? AppColors.ink : null,
      elevation: widget.useGameZoneTheme ? 0 : null,
      scrolledUnderElevation: widget.useGameZoneTheme ? 0 : null,
      surfaceTintColor: widget.useGameZoneTheme ? Colors.transparent : null,
      actions: [
        IconButton(
          tooltip: context.tr('Refresh', 'रिफ्रेस'),
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
                  widget.attempt.isPass
                      ? context.l10n.pass
                      : context.l10n.fail,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.attempt.isPass
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Score: ${widget.attempt.score}/${widget.attempt.total}',
                    'स्कोर: ${widget.attempt.score}/${widget.attempt.total}',
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    '+${widget.attempt.xpEarned} XP earned',
                    '+${widget.attempt.xpEarned} XP प्राप्त',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: context.tr('AI Adaptive Learning', 'AI अनुकूली अध्ययन'),
          ),
          const SizedBox(height: 12),
          if (widget.attempt.weakTopics.isEmpty)
            Text(
              context.tr(
                'Great job! No weak topics detected.',
                'उत्तम! कमजोर विषय भेटिएन।',
              ),
            )
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
                      Tag(
                        label:
                            context.tr('Needs revision', 'पुनरावलोकन चाहिन्छ'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          SectionHeader(
            title: context.tr('Recommended Notes', 'सिफारिस नोटहरू'),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!)
          else if (_recommendedNotes.isEmpty)
            Text(
              context.tr('No recommendations yet.', 'अहिलेसम्म सिफारिस छैन।'),
            )
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
                      MathText(
                        text: note.shortAnswer,
                        textStyle: Theme.of(context)
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
          SectionHeader(
            title: context.tr('Important Questions', 'महत्वपूर्ण प्रश्नहरू'),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const SizedBox.shrink()
          else if (_importantQuestions.isEmpty)
            Text(
              context.tr(
                'No important questions added yet.',
                'अहिलेसम्म महत्वपूर्ण प्रश्न थपिएको छैन।',
              ),
            )
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
                        child: MathText(text: question.prompt),
                      ),
                      Tag(
                        label: context.tr(
                          '${question.marks} marks',
                          '${question.marks} अंक',
                        ),
                      ),
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
                  context.tr('Coach Feedback', 'कोच प्रतिक्रिया'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Recommended difficulty: ${_recommendedDifficulty().name.toUpperCase()}',
                    'सिफारिस कठिनाइ: ${_recommendedDifficulty().name.toUpperCase()}',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                ..._coachTips(context).map(
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
          SectionHeader(title: context.tr('Answer Review', 'उत्तर समीक्षा')),
          const SizedBox(height: 12),
          if (widget.reviews.isEmpty)
            Text(
              context.tr(
                'Answer review is not available for this quiz.',
                'यस क्विजका लागि उत्तर समीक्षा उपलब्ध छैन।',
              ),
            )
          else
            Builder(
              builder: (context) {
                final wrong =
                    widget.reviews.where((review) => !review.isCorrect).toList();
                if (wrong.isEmpty) {
                  return Text(
                    context.tr(
                      'All answers were correct. Great job!',
                      'सबै उत्तरहरू सही छन्। राम्रो काम!',
                    ),
                  );
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
                        : context.tr('Not answered', 'जवाफ दिएको छैन');
                    final correctText = (correct >= 0 &&
                            correct < review.options.length)
                        ? review.options[correct]
                        : context.tr('N/A', 'लागू छैन');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MathText(
                              text: review.prompt,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            MathText(
                              text: context.tr(
                                'Your answer: $selectedText',
                                'तपाईंको उत्तर: $selectedText',
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.danger),
                            ),
                            const SizedBox(height: 4),
                            MathText(
                              text: context.tr(
                                'Correct answer: $correctText',
                                'सही उत्तर: $correctText',
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.success),
                            ),
                            if (review.explanation != null &&
                                review.explanation!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              MathText(
                                text: review.explanation!,
                                textStyle: Theme.of(context)
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
          SectionHeader(title: context.tr('More Practice', 'थप अभ्यास')),
          const SizedBox(height: 12),
          if (_isPracticeLoading)
            const Center(child: CircularProgressIndicator())
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('AI Practice Questions', 'AI अभ्यास प्रश्नहरू'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'Practice more questions based on your quiz performance.',
                      'तपाईंको क्विज प्रदर्शनका आधारमा थप प्रश्न अभ्यास गर्नुहोस्।',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Recommended difficulty: ${_recommendedDifficulty().name.toUpperCase()}',
                      'सिफारिस कठिनाइ: ${_recommendedDifficulty().name.toUpperCase()}',
                    ),
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
                      child: Text(
                        context.tr('Start AI Practice', 'AI अभ्यास सुरु गर्नुहोस्'),
                      ),
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
