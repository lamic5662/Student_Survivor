import 'dart:async';

import 'package:flutter/material.dart';
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

  const QuizPlayScreen({
    super.key,
    required this.quiz,
    required this.subject,
    this.chapter,
    this.isAi = false,
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
        _errorMessage = 'Failed to load quiz: $error';
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
              title: const Text('Unanswered Questions'),
              content: Text(
                'You have $_unansweredCount unanswered question(s). Submit anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Go back'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
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
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            attempt: attempt,
            quizId: widget.quiz.id,
            reviews: reviews,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to submit: $error';
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
        const SnackBar(content: Text('Select an answer to continue.')),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: Center(child: Text(_errorMessage!)),
      );
    }
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: Center(
          child: Text(
            _isAiMode
                ? 'AI quiz unavailable. Enable Ollama or add quiz questions.'
                : 'No questions available yet.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLevelMode ? _buildLevelMode(context) : _buildListMode(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final remaining =
        _timeRemaining.isNegative ? Duration.zero : _timeRemaining;
    final timeLabel = _isTimeMode
        ? '${remaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(remaining.inSeconds.remainder(60)).toString().padLeft(2, '0')}'
        : '${widget.quiz.duration.inMinutes}:00 min';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          timeLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          'Answered: ${_answers.length}/${_questions.length}',
          style: Theme.of(context).textTheme.titleSmall,
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
                onSelect: (value) {
                  setState(() {
                    _answers[entry.value.id] = value;
                  });
                },
              ),
            ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Answers'),
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
          'Level ${_currentIndex + 1} of ${_questions.length}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              _QuestionCard(
                index: _currentIndex + 1,
                question: question,
                selectedIndex: _answers[question.id],
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
        SizedBox(
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
                        ? 'Finish'
                        : 'Next',
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

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Q$index. ${question.prompt}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...question.options.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedIndex == entry.key
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1)
                            : null,
                      ),
                      onPressed: () => onSelect(entry.key),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(entry.value),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
