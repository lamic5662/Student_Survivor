import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/ai_status_chip.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/revision_queue_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class QuickRevisionQuizScreen extends StatefulWidget {
  final List<RevisionItem> items;

  const QuickRevisionQuizScreen({
    super.key,
    required this.items,
  });

  @override
  State<QuickRevisionQuizScreen> createState() =>
      _QuickRevisionQuizScreenState();
}

class _QuickRevisionQuizScreenState extends State<QuickRevisionQuizScreen> {
  late final AiQuizService _aiQuizService;
  late final RevisionQueueService _revisionService;
  late final ActivityLogService _activityLog;

  bool _loading = true;
  String? _error;
  List<QuizQuestionItem> _questions = const [];
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  QuizDifficulty _difficulty = QuizDifficulty.easy;
  Subject? _activeSubject;
  Chapter? _activeChapter;
  Timer? _timer;
  Duration _timeRemaining = const Duration(seconds: 20);
  Duration _timePerQuestion = const Duration(seconds: 20);
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _audioReady = false;
  bool _audioFailed = false;

  static const String _soundTimeout = 'sounds/ui.wav';

  @override
  void initState() {
    super.initState();
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _revisionService = RevisionQueueService(SupabaseConfig.client);
    _activityLog = ActivityLogService(SupabaseConfig.client);
    _loadPrefsAndStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPrefsAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('revision_timer_seconds') ?? 20;
    final sound = prefs.getBool('revision_timer_sound') ?? true;
    final vibration = prefs.getBool('revision_timer_vibration') ?? true;
    _timePerQuestion = Duration(seconds: seconds.clamp(10, 60));
    _soundEnabled = sound;
    _vibrationEnabled = vibration;
    if (mounted) {
      setState(() {
        _timeRemaining = _timePerQuestion;
      });
    }
    await _load();
  }

  Future<void> _load({QuizDifficulty? difficulty}) async {
    final selectedDifficulty = difficulty ?? _difficulty;
    setState(() {
      _loading = true;
      _error = null;
      _difficulty = selectedDifficulty;
      _answers.clear();
      _currentIndex = 0;
      _timeRemaining = _timePerQuestion;
    });
    try {
      if (widget.items.isEmpty) {
        throw Exception('No revision items');
      }
      final focusItems = widget.items.take(6).toList();
      final subject = _pickSubject(focusItems);
      if (subject == null) {
        throw Exception('No subject');
      }
      final chapter = _pickChapter(focusItems, subject);
      _activeSubject = subject;
      _activeChapter = chapter;
      final questions = await _aiQuizService.generateRevisionQuestions(
        subject: subject,
        chapter: chapter,
        items: focusItems,
        count: min(8, max(5, focusItems.length + 2)),
        baseDifficulty: selectedDifficulty,
        nonce: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
          _loading = false;
          _error = context.tr(
            'AI questions not available right now.',
            'एआई प्रश्न उपलब्ध छैन।',
          );
        });
        return;
      }
      setState(() {
        _questions = questions;
        _loading = false;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.tr(
          'Failed to start quick revision: $error',
          'छिटो पुनरावलोकन सुरु गर्न असफल: $error',
        );
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeRemaining = _timePerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final question = _questions.isNotEmpty ? _questions[_currentIndex] : null;
      if (question != null && _answers.containsKey(question.id)) {
        timer.cancel();
        return;
      }
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        _handleTimeout();
        return;
      }
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
      });
    });
  }

  void _handleTimeout() {
    if (!mounted) return;
    final question = _questions[_currentIndex];
    if (_answers.containsKey(question.id)) return;
    if (_soundEnabled) {
      _playTimeoutSound();
    }
    if (_vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    _activityLog.logActivityUnawaited(
      type: 'revision_timeout',
      source: 'quick_revision',
      metadata: {
        'question_id': question.id,
        'index': _currentIndex,
      },
    );
    _advance(auto: true);
  }

  Future<void> _primeAudio() async {
    if (_audioFailed) return;
    try {
      FlameAudio.audioCache.prefix = 'assets/';
      await FlameAudio.audioCache.load(_soundTimeout);
      _audioReady = true;
    } on MissingPluginException {
      _audioFailed = true;
      _soundEnabled = false;
    } catch (_) {
      _audioFailed = true;
      _soundEnabled = false;
    }
  }

  Future<void> _playTimeoutSound() async {
    if (_audioFailed || !_soundEnabled) return;
    try {
      if (!_audioReady) {
        await _primeAudio();
      }
      await FlameAudio.play(_soundTimeout, volume: 0.6);
    } on MissingPluginException {
      _audioFailed = true;
      _soundEnabled = false;
    } catch (_) {
      _audioFailed = true;
      _soundEnabled = false;
    }
  }

  String _difficultyLabel(BuildContext context, QuizDifficulty value) {
    switch (value) {
      case QuizDifficulty.easy:
        return context.tr('Easy', 'सजिलो');
      case QuizDifficulty.medium:
        return context.tr('Medium', 'मध्यम');
      case QuizDifficulty.hard:
        return context.tr('Hard', 'कठिन');
    }
  }

  Subject? _pickSubject(List<RevisionItem> items) {
    final counts = <String, int>{};
    final map = <String, Subject>{};
    for (final item in items) {
      final subject = item.subject;
      if (subject == null || subject.id.isEmpty) continue;
      counts[subject.id] = (counts[subject.id] ?? 0) + 1;
      map[subject.id] = subject;
    }
    if (counts.isEmpty) {
      return items.first.subject;
    }
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return map[best.key];
  }

  Chapter? _pickChapter(List<RevisionItem> items, Subject subject) {
    final counts = <String, int>{};
    final map = <String, Chapter>{};
    for (final item in items) {
      final chapter = item.chapter;
      if (chapter == null || chapter.id.isEmpty) continue;
      if (subject.chapters.every((c) => c.id != chapter.id)) continue;
      counts[chapter.id] = (counts[chapter.id] ?? 0) + 1;
      map[chapter.id] = chapter;
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return map[best.key];
  }

  void _selectAnswer(int index) {
    final question = _questions[_currentIndex];
    setState(() {
      _answers[question.id] = index;
    });
    _timer?.cancel();
  }

  Future<void> _next() async {
    _advance();
  }

  void _advance({bool auto = false}) {
    if (!mounted) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex += 1);
      _startTimer();
      return;
    }
    _finish();
  }

  Future<void> _finish() async {
    final total = _questions.length;
    var correct = 0;
    final wrongQuestions = <QuizQuestionItem>[];
    for (final question in _questions) {
      final selected = _answers[question.id];
      if (selected != null && selected == question.correctIndex) {
        correct += 1;
      } else {
        wrongQuestions.add(question);
      }
    }
    final weakTopics = _buildWeakTopics(wrongQuestions);
    final bestScore = await _saveBestScore(correct, total);
    if (!mounted) return;
    final retry = await _showSummary(
      correct: correct,
      total: total,
      bestScore: bestScore,
      weakTopics: weakTopics,
      canRetry: wrongQuestions.isNotEmpty,
    );
    if (retry == true && wrongQuestions.isNotEmpty) {
      _activityLog.logActivityUnawaited(
        type: 'revision_quiz_retry',
        source: 'quick_revision',
        metadata: {'remaining': wrongQuestions.length},
      );
      setState(() {
        _questions = wrongQuestions;
        _answers.clear();
        _currentIndex = 0;
      });
      _startTimer();
      return;
    }

    final success = total == 0 ? false : (correct / total) >= 0.6;
    for (final item in widget.items.take(6)) {
      _revisionService.markReviewed(item: item, success: success);
    }
    _activityLog.logActivityUnawaited(
      type: 'revision_quiz_complete',
      source: 'quick_revision',
      points: correct * 2,
      metadata: {'score': correct, 'total': total},
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  List<_TopicCount> _buildWeakTopics(List<QuizQuestionItem> wrongQuestions) {
    final map = <String, int>{};
    for (final question in wrongQuestions) {
      final topic = _deriveTopic(question);
      if (topic.isEmpty) continue;
      map[topic] = (map[topic] ?? 0) + 1;
    }
    final list = map.entries
        .map((entry) => _TopicCount(entry.key, entry.value))
        .toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  String _deriveTopic(QuizQuestionItem question) {
    final topic = question.topic?.trim() ?? '';
    if (topic.isNotEmpty) return topic;
    final words = question.prompt.split(RegExp(r'\s+'));
    if (words.isEmpty) return '';
    return words.take(4).join(' ');
  }

  Future<double?> _saveBestScore(int correct, int total) async {
    final subject = _activeSubject;
    if (subject == null || subject.id.isEmpty) return null;
    final userId = SupabaseConfig.client.auth.currentUser?.id ?? 'local';
    final score = total == 0 ? 0.0 : correct / total;
    final key = '${userId}_best_revision_${subject.id}';
    final prefs = await SharedPreferences.getInstance();
    final currentBest = prefs.getDouble(key) ?? 0.0;
    if (score > currentBest) {
      await prefs.setDouble(key, score);
      await _persistBestScore(subject.id, score);
      return score;
    }
    await _persistBestScore(subject.id, currentBest);
    return currentBest;
  }

  Future<void> _persistBestScore(String subjectId, double score) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;
    await SupabaseConfig.client.from('revision_best_scores').upsert({
      'user_id': user.id,
      'subject_id': subjectId,
      'best_score': score,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,subject_id');
  }

  Future<bool?> _showSummary({
    required int correct,
    required int total,
    required double? bestScore,
    required List<_TopicCount> weakTopics,
    required bool canRetry,
  }) async {
    final focusLabel = _focusLabel();
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Revision summary', 'पुनरावलोकन सारांश'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              _SummaryStat(
                label: context.tr('Score', 'स्कोर'),
                value: context.tr(
                  '$correct / $total',
                  '$correct / $total',
                ),
              ),
              if (focusLabel.isNotEmpty)
                _SummaryStat(
                  label: context.tr('Focus', 'फोकस'),
                  value: focusLabel,
                ),
              if (bestScore != null)
                _SummaryStat(
                  label: context.tr('Best score', 'सर्वोत्तम स्कोर'),
                  value: '${(bestScore * 100).round()}%',
                ),
              const SizedBox(height: 16),
              Text(
                context.tr('Weak topics', 'कमजोर विषयहरू'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              if (weakTopics.isEmpty)
                Text(
                  context.tr('No weak topics detected.', 'कमजोर विषय भेटिएन।'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: weakTopics
                      .map(
                        (topic) => _SummaryChip(
                          label: '${topic.label} (${topic.count})',
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (canRetry)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF1E2A44)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.tr('Retry wrong', 'गलत पुन: प्रयास'),
                        ),
                      ),
                    ),
                  if (canRetry) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(context.tr('Done', 'सकियो')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _focusLabel() {
    final subjectName = _activeSubject?.name ?? '';
    final chapterName = _activeChapter?.title ?? '';
    if (subjectName.isNotEmpty && chapterName.isNotEmpty) {
      return '$subjectName • $chapterName';
    }
    if (subjectName.isNotEmpty) {
      return subjectName;
    }
    if (chapterName.isNotEmpty) {
      return chapterName;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameZoneScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.tr('Quick Revision', 'छिटो पुनरावलोकन'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                )
              : _buildQuiz(context, l10n),
    );
  }

  Widget _buildQuiz(BuildContext context, AppLocalizations l10n) {
    final question = _questions[_currentIndex];
    final selected = _answers[question.id];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        children: [
          const AiStatusChip(compact: true),
          const SizedBox(height: 12),
          _ProgressHeader(
            current: _currentIndex + 1,
            total: _questions.length,
            timeRemaining: _timeRemaining,
            timeLimit: _timePerQuestion,
            timerLabel: context.tr('Timer', 'टाइमर'),
            soundEnabled: _soundEnabled,
            onToggleSound: () async {
              final prefs = await SharedPreferences.getInstance();
              final next = !_soundEnabled;
              await prefs.setBool('revision_timer_sound', next);
              if (!mounted) return;
              setState(() => _soundEnabled = next);
            },
            vibrationEnabled: _vibrationEnabled,
            onToggleVibration: () async {
              final prefs = await SharedPreferences.getInstance();
              final next = !_vibrationEnabled;
              await prefs.setBool('revision_timer_vibration', next);
              if (!mounted) return;
              setState(() => _vibrationEnabled = next);
            },
          ),
          const SizedBox(height: 12),
          _DifficultyRow(
            difficulty: _difficulty,
            labelBuilder: (value) => _difficultyLabel(context, value),
            onChanged: (value) {
              if (value == null || value == _difficulty) return;
              _load(difficulty: value);
            },
            onRegenerate: () => _load(difficulty: _difficulty),
            timePerQuestion: _timePerQuestion,
            onTimerChanged: (seconds) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setInt('revision_timer_seconds', seconds);
              if (!mounted) return;
              setState(() {
                _timePerQuestion = Duration(seconds: seconds);
                _timeRemaining = Duration(seconds: seconds);
              });
              _startTimer();
            },
          ),
          const SizedBox(height: 16),
          _QuestionCard(
            prompt: question.prompt,
            options: question.options,
            selectedIndex: selected,
            correctIndex: question.correctIndex,
            explanation: question.explanation,
            onSelect: _selectAnswer,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _currentIndex < _questions.length - 1
                    ? context.tr('Next question', 'अर्को प्रश्न')
                    : context.tr('Finish', 'समाप्त'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int current;
  final int total;
  final Duration timeRemaining;
  final Duration timeLimit;
  final String timerLabel;
  final bool soundEnabled;
  final VoidCallback onToggleSound;
  final bool vibrationEnabled;
  final VoidCallback onToggleVibration;

  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.timeRemaining,
    required this.timeLimit,
    required this.timerLabel,
    required this.soundEnabled,
    required this.onToggleSound,
    required this.vibrationEnabled,
    required this.onToggleVibration,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : current / total;
    final timeRatio = timeLimit.inSeconds == 0
        ? 0.0
        : timeRemaining.inSeconds / timeLimit.inSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Quick revision', 'छिटो पुनरावलोकन'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Question $current of $total',
                    '$current/$total प्रश्न',
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$timerLabel • ${timeRemaining.inSeconds}s',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onToggleSound,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onToggleVibration,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        vibrationEnabled
                            ? Icons.vibration_rounded
                            : Icons.phone_android_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: LinearProgressIndicator(
                  value: timeRatio.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1E2A44),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF97316),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF1E2A44),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF38BDF8),
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String prompt;
  final List<String> options;
  final int? selectedIndex;
  final int correctIndex;
  final String? explanation;
  final ValueChanged<int> onSelect;

  const _QuestionCard({
    required this.prompt,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.explanation,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            options.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OptionTile(
                label: options[index],
                selected: selectedIndex == index,
                onTap: () => onSelect(index),
              ),
            ),
          ),
          if (selectedIndex != null)
            _ExplanationCard(
              isCorrect: selectedIndex == correctIndex,
              correctAnswer: _safeOption(options, correctIndex),
              explanation: explanation,
            ),
        ],
      ),
    );
  }

  String _safeOption(List<String> options, int index) {
    if (index < 0 || index >= options.length) return '';
    return options[index];
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFF38BDF8) : Colors.white24;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F1B2E) : const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
                color: selected ? accent : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final bool isCorrect;
  final String correctAnswer;
  final String? explanation;

  const _ExplanationCard({
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? AppColors.success : AppColors.danger;
    final label = isCorrect
        ? context.tr('Correct', 'सही')
        : context.tr('Incorrect', 'गलत');
    final explanationText = (explanation ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (correctAnswer.isNotEmpty)
            Text(
              context.tr(
                'Correct answer: $correctAnswer',
                'सही उत्तर: $correctAnswer',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          if (explanationText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              explanationText,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Explanation not available.',
                'व्याख्या उपलब्ध छैन।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final QuizDifficulty difficulty;
  final String Function(QuizDifficulty) labelBuilder;
  final ValueChanged<QuizDifficulty?> onChanged;
  final VoidCallback onRegenerate;
  final Duration timePerQuestion;
  final ValueChanged<int> onTimerChanged;

  const _DifficultyRow({
    required this.difficulty,
    required this.labelBuilder,
    required this.onChanged,
    required this.onRegenerate,
    required this.timePerQuestion,
    required this.onTimerChanged,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = timePerQuestion.inSeconds.clamp(10, 60);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<QuizDifficulty>(
                    value: difficulty,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0B1220),
                    icon: const Icon(Icons.expand_more, color: Colors.white70),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white),
                    onChanged: onChanged,
                    items: QuizDifficulty.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(labelBuilder(value)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onRegenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF1E2A44)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(context.tr('Regenerate', 'फेरि बनाउनुहोस्')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2A44)),
          ),
          child: Row(
            children: [
              Text(
                context.tr('Timer', 'टाइमर'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: seconds.toDouble(),
                  min: 10,
                  max: 60,
                  divisions: 10,
                  activeColor: const Color(0xFF38BDF8),
                  inactiveColor: const Color(0xFF1E2A44),
                  label: '${seconds}s',
                  onChanged: (value) => onTimerChanged(value.round()),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${seconds}s',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;

  const _SummaryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TopicCount {
  final String label;
  final int count;

  const _TopicCount(this.label, this.count);
}
