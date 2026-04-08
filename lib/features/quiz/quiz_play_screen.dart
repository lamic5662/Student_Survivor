import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/quiz/quiz_result_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizPlayScreen extends StatefulWidget {
  final Quiz quiz;
  final Subject subject;
  final Chapter? chapter;
  final bool isAi;
  final bool useGameZoneTheme;

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    required this.subject,
    this.chapter,
    this.isAi = false,
    this.useGameZoneTheme = false,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late final QuizService _quizService;
  late final AiQuizService _aiQuizService;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _attemptId;
  DateTime? _startedAt;
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  int _currentIndex = 0;
  List<QuizQuestionItem> _questions = const [];
  final Map<String, int> _answers = {};
  int _aiSkillDelta = 0;

  @override
  void initState() {
    super.initState();
    _quizService = QuizService(SupabaseConfig.client);
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isTimeMode => widget.quiz.type == QuizType.time;
  bool get _isLevelMode => widget.quiz.type == QuizType.level;
  bool get _isAiMode => widget.isAi;
  bool get _isGameTheme => widget.useGameZoneTheme;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final attemptId = await _quizService.startAttempt(widget.quiz.id);
      final questionCount =
          widget.quiz.questionCount > 0 ? widget.quiz.questionCount : 10;
      final questions = _isAiMode
          ? await _aiQuizService.generateQuestions(
              quizId: widget.quiz.id,
              subject: widget.subject,
              chapter: widget.chapter,
              count: questionCount,
              baseDifficulty: widget.quiz.difficulty,
            )
          : await _quizService.fetchQuestions(widget.quiz.id);
      if (!mounted) return;
      setState(() {
        _attemptId = attemptId;
        _questions = questions;
        _startedAt = DateTime.now();
        _timeRemaining = widget.quiz.duration;
        _isLoading = false;
      });
      if (_isTimeMode) {
        _startTimer();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to load quiz: $error',
          'क्विज लोड गर्न सकिएन: $error',
        );
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isSubmitting) return;
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
      });
      if (_timeRemaining.inSeconds <= 0) {
        _timer?.cancel();
        _submit(force: true);
      }
    });
  }

  int get _unansweredCount =>
      _questions.where((q) => !_answers.containsKey(q.id)).length;

  Future<void> _submit({bool force = false}) async {
    if (_attemptId == null || _questions.isEmpty) {
      return;
    }
    if (_isSubmitting) {
      return;
    }
    if (!force && _unansweredCount > 0) {
        final proceed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  context.tr('Unanswered Questions', 'जवाफ नदिएका प्रश्नहरू'),
                ),
                content: Text(
                  context.tr(
                    'You have $_unansweredCount unanswered question(s). Submit anyway?',
                    'तपाईंले $_unansweredCount प्रश्नको उत्तर दिनुभएको छैन। जे भए पनि बुझाउने?',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(context.tr('Go back', 'फर्कनुहोस्')),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(context.tr('Submit', 'पेश गर्नुहोस्')),
                  ),
                ],
              ),
            ) ??
          false;
      if (!mounted) {
        return;
      }
      if (!proceed) {
        return;
      }
    }
    setState(() {
      _isSubmitting = true;
    });
    _timer?.cancel();

    final answersPayload = <Map<String, dynamic>>[];
    int score = 0;
    for (final question in _questions) {
      final selected = _answers[question.id];
      final isCorrect = selected != null && selected == question.correctIndex;
      if (isCorrect) {
        score += 1;
      }
      if (!_isAiMode) {
        answersPayload.add({
          'quiz_question_id': question.id,
          'selected_index': selected ?? -1,
          'is_correct': isCorrect,
          'response_time_ms': 0,
        });
      }
    }

    final durationSeconds = _startedAt == null
        ? 0
        : DateTime.now().difference(_startedAt!).inSeconds;

    try {
      final reviews = _questions.map((question) {
        final selected = _answers[question.id];
        return QuizAnswerReview(
          prompt: question.prompt,
          options: question.options,
          correctIndex: question.correctIndex,
          selectedIndex: selected,
          explanation: question.explanation,
        );
      }).toList();

      final result = await _quizService.finishAttempt(
        attemptId: _attemptId!,
        score: score,
        durationSeconds: durationSeconds,
        answers: _isAiMode ? const [] : answersPayload,
      );

      final weakTopics = _isAiMode
          ? _localWeakTopics()
          : result.weakTopics
              .map((topic) => WeakTopic(name: topic, reason: 'Needs revision'))
              .toList();

      final attempt = QuizAttempt(
        quiz: widget.quiz,
        score: score,
        total: _questions.length,
        xpEarned: result.xpEarned,
        weakTopics: weakTopics,
        durationSeconds: durationSeconds,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            attempt: attempt,
            quizId: widget.quiz.id,
            reviews: reviews,
            useGameZoneTheme: widget.useGameZoneTheme,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to submit: $error',
          'पेश गर्न असफल: $error',
        );
        _isSubmitting = false;
      });
    }
  }

  List<WeakTopic> _localWeakTopics() {
    final topics = <String>{};
    for (final question in _questions) {
      final selected = _answers[question.id];
      final isCorrect = selected != null && selected == question.correctIndex;
      if (isCorrect) {
        continue;
      }
      final topic = question.topic?.trim();
      if (topic != null && topic.isNotEmpty) {
        topics.add(topic);
      }
    }
    return topics
        .map((topic) => WeakTopic(name: topic, reason: 'Needs revision'))
        .toList();
  }

  void _nextLevel() {
    final current = _questions[_currentIndex];
    final selected = _answers[current.id];
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Select an answer to continue.', 'जारी राख्न उत्तर छान्नुहोस्।'),
          ),
        ),
      );
      return;
    }
    if (_isAiMode) {
      final isCorrect = selected == current.correctIndex;
      _aiSkillDelta += isCorrect ? 1 : -1;
      _applyAdaptiveNextQuestion();
    }
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex += 1;
      });
    } else {
      _submit();
    }
  }

  void _applyAdaptiveNextQuestion() {
    if (!_isAiMode || !_isLevelMode) {
      return;
    }
    final target = _targetDifficulty();
    final nextIndex = _findNextByDifficulty(target);
    if (nextIndex == null || nextIndex == _currentIndex + 1) {
      return;
    }
    final swap = _questions[_currentIndex + 1];
    _questions[_currentIndex + 1] = _questions[nextIndex];
    _questions[nextIndex] = swap;
  }

  String _targetDifficulty() {
    if (_aiSkillDelta >= 2) {
      return 'hard';
    }
    if (_aiSkillDelta <= -2) {
      return 'easy';
    }
    return widget.quiz.difficulty.name;
  }

  int? _findNextByDifficulty(String target) {
    for (var i = _currentIndex + 1; i < _questions.length; i += 1) {
      final diff = _questions[i].difficulty?.toLowerCase();
      if (diff == target) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _wrapScaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: _isGameTheme ? const Color(0xFF38BDF8) : null,
          ),
        ),
        safeArea: true,
      );
    }
    if (_errorMessage != null) {
      return _wrapScaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isGameTheme ? Colors.white70 : null,
                ),
          ),
        ),
        safeArea: false,
      );
    }
    if (_questions.isEmpty) {
      return _wrapScaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Text(
            _isAiMode
                ? context.tr(
                    'AI quiz unavailable. Enable Ollama or add quiz questions.',
                    'AI क्विज उपलब्ध छैन। Ollama सक्षम गर्नुहोस् वा प्रश्न थप्नुहोस्।',
                  )
                : context.tr(
                    'No questions available yet.',
                    'अहिलेसम्म प्रश्नहरू उपलब्ध छैनन्।',
                  ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isGameTheme ? Colors.white70 : null,
                ),
          ),
        ),
        safeArea: false,
      );
    }

    return _wrapScaffold(
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLevelMode ? _buildLevelMode(context) : _buildListMode(context),
      ),
      safeArea: false,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(widget.quiz.title),
      backgroundColor: _isGameTheme ? Colors.transparent : null,
      foregroundColor: _isGameTheme ? Colors.white : null,
      elevation: _isGameTheme ? 0 : null,
      scrolledUnderElevation: _isGameTheme ? 0 : null,
      surfaceTintColor: Colors.transparent,
    );
  }

  Widget _wrapScaffold({
    PreferredSizeWidget? appBar,
    required Widget body,
    required bool safeArea,
  }) {
    if (!widget.useGameZoneTheme) {
      return Scaffold(appBar: appBar, body: body);
    }
    return GameZoneScaffold(
      appBar: appBar,
      body: body,
      useSafeArea: safeArea,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final remaining =
        _timeRemaining.isNegative ? Duration.zero : _timeRemaining;
    final timeLabel = _isTimeMode
        ? '${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(remaining.inSeconds.remainder(60)).toString().padLeft(2, '0')}'
        : context.tr(
            '${widget.quiz.duration.inMinutes}:00 min',
            '${widget.quiz.duration.inMinutes}:00 मिनेट',
          );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          timeLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _isGameTheme ? Colors.white : null,
              ),
        ),
        Text(
          context.tr(
            'Answered: ${_answers.length}/${_questions.length}',
            'जवाफ: ${_answers.length}/${_questions.length}',
          ),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _isGameTheme ? Colors.white70 : null,
              ),
        ),
      ],
    );
  }

  Widget _buildListMode(BuildContext context) {
    return ListView(
      children: [
        _buildHeader(context),
        const SizedBox(height: 20),
        ..._questions.asMap().entries.map(
              (entry) => _QuestionCard(
                index: entry.key + 1,
                question: entry.value,
                selectedIndex: _answers[entry.value.id],
                isGameTheme: _isGameTheme,
                onSelect: (value) {
                  setState(() {
                    _answers[entry.value.id] = value;
                  });
                },
              ),
            ),
        const SizedBox(height: 12),
        _isGameTheme
            ? _PrimaryActionButton(
                label: context.tr('Submit Answers', 'जवाफ पेश गर्नुहोस्'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('Submit Answers', 'जवाफ पेश गर्नुहोस्')),
                ),
              ),
      ],
    );
  }

  Widget _buildLevelMode(BuildContext context) {
    final question = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 20),
        Text(
          context.tr(
            'Level ${_currentIndex + 1} of ${_questions.length}',
            'लेभल ${_currentIndex + 1} / ${_questions.length}',
          ),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _isGameTheme ? Colors.white70 : null,
              ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _QuestionCard(
                index: _currentIndex + 1,
                question: question,
                selectedIndex: _answers[question.id],
                isGameTheme: _isGameTheme,
                onSelect: (value) {
                  setState(() {
                    _answers[question.id] = value;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _isGameTheme
            ? _PrimaryActionButton(
                label: _currentIndex == _questions.length - 1
                    ? context.tr('Finish', 'समाप्त')
                    : context.tr('Next', 'अर्को'),
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _nextLevel,
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _nextLevel,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _currentIndex == _questions.length - 1
                              ? context.tr('Finish', 'समाप्त')
                              : context.tr('Next', 'अर्को'),
                        ),
                ),
              ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuizQuestionItem question;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final bool isGameTheme;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
    this.isGameTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MathText(
          text: 'Q$index. ${question.prompt}',
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isGameTheme ? Colors.white : null,
              ),
        ),
        const SizedBox(height: 12),
        ...question.options.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isGameTheme
                        ? (selectedIndex == entry.key
                            ? const Color(0xFF13243A)
                            : const Color(0xFF0B1220))
                        : (selectedIndex == entry.key
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1)
                            : null),
                    foregroundColor: isGameTheme ? Colors.white : null,
                    side: BorderSide(
                      color: isGameTheme
                          ? (selectedIndex == entry.key
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF1E2A44))
                          : Theme.of(context).dividerColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onPressed: () => onSelect(entry.key),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MathText(
                      text: entry.value,
                      textStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isGameTheme ? Colors.white : null,
                              ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );

    return isGameTheme
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _GameCard(child: content),
          )
        : Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: content,
            ),
          );
  }
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

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
        padding: const EdgeInsets.all(16),
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
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.isLoading,
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }
}
