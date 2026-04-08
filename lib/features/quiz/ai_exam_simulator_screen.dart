import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class AiExamSimulatorScreen extends StatefulWidget {
  const AiExamSimulatorScreen({super.key});

  @override
  State<AiExamSimulatorScreen> createState() => _AiExamSimulatorScreenState();
}

enum _ExamStage { setup, running, written }
enum _ExamAction { reviewWrong, exportPdf, sharePdf, done }

class _AiExamSimulatorScreenState extends State<AiExamSimulatorScreen> {
  late final AiQuizService _aiQuizService;
  late final ActivityLogService _activityLog;
  _ExamStage _stage = _ExamStage.setup;
  bool _loading = false;
  String? _error;
  bool _showTitle = true;
  final ScrollController _scrollController = ScrollController();

  late List<Subject> _subjects;
  Subject? _subject;
  Chapter? _chapter;
  QuizDifficulty _difficulty = QuizDifficulty.medium;
  int _questionCount = 10;
  final Duration _mcqDuration = const Duration(minutes: 20);
  final Duration _writtenDuration = const Duration(hours: 2);
  bool _includeWritten = true;
  int _writtenCount = 9;
  bool _reviewMode = false;

  Timer? _timer;
  Duration _timeRemaining = const Duration(minutes: 20);
  List<QuizQuestionItem> _questions = const [];
  final Map<String, int> _answers = {};
  int _currentIndex = 0;
  double? _bestScore;
  List<WrittenQuestion> _writtenQuestions = const [];
  final Map<int, String> _writtenAnswers = {};
  List<WrittenGrade> _writtenGrades = const [];
  bool _writtenCompleted = false;
  bool _gradingWritten = false;
  String? _writtenError;
  final List<TextEditingController> _writtenControllers = [];
  int _mcqCorrect = 0;
  int _mcqTotal = 0;
  List<QuizQuestionItem> _mcqWrong = const [];
  List<_TopicCount> _mcqWeakTopics = const [];

  @override
  void initState() {
    super.initState();
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _activityLog = ActivityLogService(SupabaseConfig.client);
    _subjects = AppState.profile.value.subjects;
    if (_subjects.isNotEmpty) {
      _subject = _subjects.first;
    }
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _writtenControllers) {
      controller.dispose();
    }
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

  void _resetScroll() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _startExam() async {
    if (_subject == null) {
      setState(() {
        _error = context.tr(
          'Select a subject to start the exam.',
          'परीक्षा सुरु गर्न विषय छान्नुहोस्।',
        );
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _writtenError = null;
      _writtenQuestions = const [];
      _writtenGrades = const [];
      _writtenCompleted = false;
      _writtenAnswers.clear();
      for (final controller in _writtenControllers) {
        controller.dispose();
      }
      _writtenControllers.clear();
    });
    try {
      final questions = await _aiQuizService.generateExamQuestions(
        subject: _subject!,
        chapter: _chapter,
        count: _questionCount,
        baseDifficulty: _difficulty,
        nonce: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      var writtenQuestions = <WrittenQuestion>[];
      if (_includeWritten && _writtenCount > 0) {
        final marksPattern = [
          5,
          5,
          5,
          5,
          5,
          5,
          10,
          10,
          10,
        ];
        writtenQuestions = await _aiQuizService.generateWrittenQuestions(
          subject: _subject!,
          chapter: _chapter,
          count: _writtenCount,
          baseDifficulty: _difficulty,
          marksPattern: marksPattern.take(_writtenCount).toList(),
          nonce: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() {
          _loading = false;
          _error = context.tr(
            'AI exam questions are not available right now.',
            'एआई परीक्षा प्रश्न उपलब्ध छैन।',
          );
        });
        return;
      }
      setState(() {
        _questions = questions;
        _answers.clear();
        _currentIndex = 0;
        _stage = _ExamStage.running;
        _reviewMode = false;
        _timeRemaining = _mcqDuration;
        _writtenQuestions = writtenQuestions;
        if (_includeWritten && writtenQuestions.isEmpty) {
          _writtenError = context.tr(
            'Written section not available right now.',
            'लेख्ने सेक्शन अहिले उपलब्ध छैन।',
          );
        }
        _loading = false;
      });
      _resetScroll();
      if (writtenQuestions.isNotEmpty) {
        for (var i = 0; i < writtenQuestions.length; i += 1) {
          _writtenControllers.add(TextEditingController());
        }
      }
      _activityLog.logActivityUnawaited(
        type: 'exam_simulator_start',
        source: 'ai_exam',
        subjectId: _subject?.id,
        chapterId: _chapter?.id,
        metadata: {
          'count': _questionCount,
          'difficulty': _difficulty.name,
          'duration_min': _mcqDuration.inMinutes,
          'written_min': _writtenDuration.inMinutes,
        },
      );
      _startMcqTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr(
          'Failed to start exam: $error',
          'परीक्षा सुरु गर्न असफल: $error',
        );
      });
    }
  }

  void _startMcqTimer() {
    _timer?.cancel();
    _timeRemaining = _mcqDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
      });
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        _finishExam();
      }
    });
  }

  void _startWrittenTimer() {
    _timer?.cancel();
    _timeRemaining = _writtenDuration;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _timeRemaining -= const Duration(seconds: 1);
      });
      if (_timeRemaining.inSeconds <= 0) {
        timer.cancel();
        _submitWrittenAnswers(auto: true);
      }
    });
  }

  void _selectAnswer(int index) {
    final question = _questions[_currentIndex];
    setState(() => _answers[question.id] = index);
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex += 1);
    } else {
      _finishExam();
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex -= 1);
    }
  }

  Future<void> _finishExam() async {
    _timer?.cancel();
    final total = _questions.length;
    var correct = 0;
    final wrong = <QuizQuestionItem>[];
    for (final question in _questions) {
      final selected = _answers[question.id];
      if (selected != null && selected == question.correctIndex) {
        correct += 1;
      } else {
        wrong.add(question);
      }
    }
    final weakTopics = _buildWeakTopics(wrong);
    _mcqCorrect = correct;
    _mcqTotal = total;
    _mcqWrong = wrong;
    _mcqWeakTopics = weakTopics;
    _activityLog.logActivityUnawaited(
      type: 'exam_simulator_complete',
      source: 'ai_exam',
      subjectId: _subject?.id,
      chapterId: _chapter?.id,
      points: correct * 2,
      metadata: {
        'score': correct,
        'total': total,
        'difficulty': _difficulty.name,
      },
    );
    _bestScore = await _saveBestScore(correct, total);
    if (!mounted) return;
    if (_includeWritten &&
        _writtenQuestions.isNotEmpty &&
        !_writtenCompleted) {
      setState(() => _stage = _ExamStage.written);
      _resetScroll();
      _startWrittenTimer();
      return;
    }
    await _showSummaryFlow(
      correct: correct,
      total: total,
      wrong: wrong,
      weakTopics: weakTopics,
    );
  }

  Future<void> _showSummaryFlow({
    required int correct,
    required int total,
    required List<QuizQuestionItem> wrong,
    required List<_TopicCount> weakTopics,
  }) async {
    final action = await _showSummary(
      correct: correct,
      total: total,
      weakTopics: weakTopics,
      wrongQuestions: wrong,
      writtenScore: _writtenScore(),
      writtenMax: _writtenMax(),
    );
    if (!mounted) return;
    if (action == _ExamAction.reviewWrong && wrong.isNotEmpty) {
      setState(() {
        _questions = wrong;
        _answers.clear();
        _currentIndex = 0;
        _reviewMode = true;
        _timeRemaining = Duration.zero;
      });
      _resetScroll();
      return;
    }
    if (action == _ExamAction.exportPdf) {
      await _exportPdf(
        correct: correct,
        total: total,
        weakTopics: weakTopics,
        wrongQuestions: wrong,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    if (action == _ExamAction.sharePdf) {
      await _exportPdf(
        correct: correct,
        total: total,
        weakTopics: weakTopics,
        wrongQuestions: wrong,
        share: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
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

  int _writtenScore() =>
      _writtenGrades.fold(0, (sum, grade) => sum + grade.score);

  int _writtenMax() =>
      _writtenGrades.fold(0, (sum, grade) => sum + grade.maxScore);

  

  Future<_ExamAction?> _showSummary({
    required int correct,
    required int total,
    required List<_TopicCount> weakTopics,
    required List<QuizQuestionItem> wrongQuestions,
    int? writtenScore,
    int? writtenMax,
  }) {
    return showModalBottomSheet<_ExamAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.85;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Exam summary', 'परीक्षा सारांश'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryStat(
                    label: context.tr('Score', 'स्कोर'),
                    value: context.tr('$correct / $total', '$correct / $total'),
                  ),
                  if (writtenMax != null && writtenMax > 0)
                    _SummaryStat(
                      label: context.tr('Written score', 'लेखाइ स्कोर'),
                      value: context.tr(
                        '${writtenScore ?? 0} / $writtenMax',
                        '${writtenScore ?? 0} / $writtenMax',
                      ),
                    ),
                  _SummaryStat(
                    label: context.tr('Difficulty', 'स्तर'),
                    value: _difficultyLabel(context, _difficulty),
                  ),
                  if (_bestScore != null)
                    _SummaryStat(
                      label: context.tr('Best score', 'सर्वोत्तम स्कोर'),
                      value: '${((_bestScore ?? 0) * 100).round()}%',
                    ),
                  const SizedBox(height: 14),
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
                      context.tr(
                        'No weak topics detected.',
                        'कमजोर विषय भेटिएन।',
                      ),
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
                          .take(8)
                          .map(
                            (topic) => _SummaryChip(
                              label: '${topic.label} (${topic.count})',
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('Wrong MCQ answers', 'गलत MCQ उत्तरहरू'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (wrongQuestions.isEmpty)
                    Text(
                      context.tr(
                        'No wrong answers.',
                        'कुनै गलत उत्तर छैन।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    )
                  else
                    Column(
                      children: wrongQuestions.map((question) {
                        final answer = question.correctIndex >= 0 &&
                                question.correctIndex <
                                    question.options.length
                            ? question.options[question.correctIndex]
                            : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _WrittenInfoBlock(
                            title: question.prompt,
                            body: answer.isEmpty
                                ? context.tr(
                                    'Answer not available',
                                    'उत्तर उपलब्ध छैन',
                                  )
                                : answer,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  Column(
                    children: [
                      if (wrongQuestions.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context)
                                .pop(_ExamAction.reviewWrong),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Color(0xFF1E2A44)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              context.tr('Review wrong', 'गलत समीक्षा'),
                            ),
                          ),
                        ),
                      if (wrongQuestions.isNotEmpty) const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_ExamAction.exportPdf),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Color(0xFF1E2A44)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            Platform.isIOS
                                ? context.tr('Save to Files', 'Files मा बचत')
                                : context.tr('Save PDF', 'PDF बचत गर्नुहोस्'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_ExamAction.sharePdf),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Color(0xFF1E2A44)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              Text(context.tr('Share PDF', 'PDF सेयर गर्नुहोस्')),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_ExamAction.done),
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
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return GameZoneScaffold(
      extendBodyBehindAppBar: true,
      useSafeArea: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.tr('AI Exam Simulator', 'एआई परीक्षा सिमुलेटर'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : _stage == _ExamStage.setup
              ? _buildSetup(context)
              : _stage == _ExamStage.running
                  ? _buildExam(context)
                  : _buildWrittenSection(context),
    );
  }

  Widget _buildSetup(BuildContext context) {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        24,
      ),
      children: [
        _ConfigCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Exam setup', 'परीक्षा सेटअप'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              _ConfigDropdown<Subject>(
                label: context.tr('Subject', 'विषय'),
                value: _subject,
                items: _subjects,
                itemLabel: (value) => value.name,
                onChanged: (value) {
                  setState(() {
                    _subject = value;
                    _chapter = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              _ConfigDropdown<Chapter>(
                label: context.tr('Chapter', 'अध्याय'),
                value: _chapter,
                items: _subject?.chapters ?? const [],
                itemLabel: (value) => value.title,
                allowNull: true,
                nullLabel: context.tr('All chapters', 'सबै अध्याय'),
                onChanged: (value) => setState(() => _chapter = value),
              ),
              const SizedBox(height: 12),
              _ConfigDropdown<QuizDifficulty>(
                label: context.tr('Difficulty', 'स्तर'),
                value: _difficulty,
                items: QuizDifficulty.values,
                itemLabel: (value) => _difficultyLabel(context, value),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _difficulty = value);
                },
              ),
              const SizedBox(height: 12),
              _ConfigDropdown<int>(
                label: context.tr('Questions', 'प्रश्नहरू'),
                value: _questionCount,
                items: const [10, 20, 30, 40],
                itemLabel: (value) => '$value',
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _questionCount = value);
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(
                          'MCQ time: 20 min • Written time: 120 min',
                          'MCQ समय: २० मिनेट • लेखाइ समय: १२० मिनेट',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              'Written section',
                              'लेख्ने सेक्शन',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              'AI grades your answers.',
                              'एआईले उत्तर मूल्याङ्कन गर्छ।',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _includeWritten,
                      onChanged: (value) {
                        setState(() => _includeWritten = value);
                      },
                      activeThumbColor: const Color(0xFF38BDF8),
                    ),
                  ],
                ),
              ),
              if (_includeWritten) ...[
                const SizedBox(height: 12),
                _ConfigDropdown<int>(
                  label: context.tr(
                    'Written questions (6x5 + 3x10)',
                    'लेख्ने प्रश्न (६x५ + ३x१०)',
                  ),
                  value: _writtenCount,
                  items: const [9],
                  itemLabel: (value) => '$value',
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _writtenCount = value);
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startExam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(context.tr('Start exam', 'परीक्षा सुरु गर्नुहोस्')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExam(BuildContext context) {
    if (_questions.isEmpty) {
      return Center(
        child: Text(
          context.tr('No questions available.', 'कुनै प्रश्न उपलब्ध छैन।'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }
    final question = _questions[_currentIndex];
    final selected = _answers[question.id];
    final ratio = _mcqDuration.inSeconds == 0
        ? 0.0
        : _timeRemaining.inSeconds / _mcqDuration.inSeconds;
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        28,
      ),
      children: [
        _ExamHeader(
          current: _currentIndex + 1,
          total: _questions.length,
          timeRemaining: _timeRemaining,
          timeRatio: ratio.clamp(0, 1),
        ),
        const SizedBox(height: 16),
        _QuestionCard(
          prompt: question.prompt,
          options: question.options,
          selectedIndex: selected,
          correctIndex: question.correctIndex,
          explanation: question.explanation,
          onSelect: _selectAnswer,
          showExplanation: _reviewMode,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reviewMode ? _previous : _previous,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF1E2A44)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(context.tr('Previous', 'अघिल्लो')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _currentIndex < _questions.length - 1
                      ? context.tr('Next', 'अर्को')
                      : context.tr('Finish', 'समाप्त'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWrittenSection(BuildContext context) {
    if (_writtenQuestions.isEmpty) {
      return Center(
        child: Text(
          context.tr(
            'Written section not available.',
            'लेख्ने सेक्शन उपलब्ध छैन।',
          ),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }
    if (_writtenControllers.length != _writtenQuestions.length) {
      for (final controller in _writtenControllers) {
        controller.dispose();
      }
      _writtenControllers
        ..clear()
        ..addAll(
          List.generate(
            _writtenQuestions.length,
            (index) => TextEditingController(
              text: _writtenAnswers[index] ?? '',
            ),
          ),
        );
    }
    final ratio = _writtenDuration.inSeconds == 0
        ? 0.0
        : _timeRemaining.inSeconds / _writtenDuration.inSeconds;
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        28,
      ),
      children: [
        _WrittenHeader(
          timeRemaining: _timeRemaining,
          timeRatio: ratio.clamp(0, 1),
        ),
        const SizedBox(height: 16),
        _ConfigCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Written Section', 'लेख्ने सेक्शन'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Answer in your own words. AI will grade and show the best format.',
                  'आफ्नै शब्दमा लेख्नुहोस्। एआईले मूल्याङ्कन र उत्तम उत्तर देखाउँछ।',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              if (_writtenError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _writtenError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _writtenQuestions.length; i += 1) ...[
          _WrittenQuestionCard(
            index: i,
            question: _writtenQuestions[i],
            controller: _writtenControllers[i],
            grade: i < _writtenGrades.length ? _writtenGrades[i] : null,
            onChanged: (value) => _writtenAnswers[i] = value,
          ),
          const SizedBox(height: 16),
        ],
        if (!_writtenCompleted)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _gradingWritten ? null : _skipWrittenSection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0xFF1E2A44)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(context.tr('Skip', 'छोड्नुहोस्')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _gradingWritten ? null : () => _submitWrittenAnswers(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _gradingWritten
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(context.tr('Submit for AI grading', 'एआईमा पठाउनुहोस्')),
                ),
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openSummaryFromWritten,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(context.tr('View summary', 'सारांश हेर्नुहोस्')),
            ),
          ),
      ],
    );
  }

  Future<void> _openSummaryFromWritten() async {
    await _showSummaryFlow(
      correct: _mcqCorrect,
      total: _mcqTotal,
      wrong: _mcqWrong,
      weakTopics: _mcqWeakTopics,
    );
  }

  Future<void> _skipWrittenSection() async {
    _timer?.cancel();
    setState(() {
      _writtenCompleted = true;
      _writtenGrades = const [];
    });
    await _openSummaryFromWritten();
  }

  Future<void> _submitWrittenAnswers({bool auto = false}) async {
    if (_gradingWritten) return;
    final answers = _writtenControllers.map((c) => c.text.trim()).toList();
    if (answers.every((value) => value.isEmpty)) {
      if (auto) {
        await _skipWrittenSection();
        return;
      }
      setState(() {
        _writtenError = context.tr(
          'Write at least one answer.',
          'कम्तिमा एउटा उत्तर लेख्नुहोस्।',
        );
      });
      return;
    }
    setState(() {
      _gradingWritten = true;
      _writtenError = null;
    });
    final grades = await _aiQuizService.gradeWrittenAnswers(
      subject: _subject!,
      chapter: _chapter,
      questions: _writtenQuestions,
      answers: answers,
    );
    if (!mounted) return;
    if (grades.isEmpty) {
      setState(() {
        _gradingWritten = false;
        _writtenError = context.tr(
          'AI grading not available right now.',
          'एआई मूल्याङ्कन उपलब्ध छैन।',
        );
      });
      return;
    }
    setState(() {
      _writtenGrades = grades;
      _writtenCompleted = true;
      _gradingWritten = false;
    });
    _timer?.cancel();
    _activityLog.logActivityUnawaited(
      type: 'exam_written_submit',
      source: 'ai_exam',
      subjectId: _subject?.id,
      chapterId: _chapter?.id,
      points: _writtenScore(),
      metadata: {
        'questions': _writtenQuestions.length,
        'score': _writtenScore(),
        'max': _writtenMax(),
      },
    );
    await _openSummaryFromWritten();
  }

  Future<double?> _saveBestScore(int correct, int total) async {
    final subject = _subject;
    if (subject == null || subject.id.isEmpty) return null;
    final userId = SupabaseConfig.client.auth.currentUser?.id ?? 'local';
    final score = total == 0 ? 0.0 : correct / total;
    final key = '${userId}_best_exam_${subject.id}';
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
    await SupabaseConfig.client.from('exam_best_scores').upsert({
      'user_id': user.id,
      'subject_id': subjectId,
      'best_score': score,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,subject_id');
  }

  Future<void> _exportPdf({
    required int correct,
    required int total,
    required List<_TopicCount> weakTopics,
    required List<QuizQuestionItem> wrongQuestions,
    bool share = false,
  }) async {
    final doc = PdfDocument();
    final page = doc.pages.add();
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 12);

    final subjectName = _subject?.name ?? 'Subject';
    final chapterName = _chapter?.title;
    final date = DateTime.now().toLocal().toString().split('.').first;
    var y = 20.0;

    page.graphics.drawString('AI Exam Simulator Report', titleFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 24));
    y += 32;
    page.graphics.drawString('Subject: $subjectName', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    if (chapterName != null && chapterName.isNotEmpty) {
      page.graphics.drawString('Chapter: $chapterName', bodyFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
      y += 18;
    }
    page.graphics.drawString('Difficulty: ${_difficulty.name}', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    page.graphics.drawString(
        'MCQ Duration: ${_mcqDuration.inMinutes} min', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    page.graphics.drawString(
        'Written Duration: ${_writtenDuration.inMinutes} min', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    page.graphics.drawString('Score: $correct / $total', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    page.graphics.drawString('Date: $date', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 26;

    page.graphics.drawString('Weak topics:', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    if (weakTopics.isEmpty) {
      page.graphics.drawString('None', bodyFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
      y += 18;
    } else {
      for (final topic in weakTopics.take(8)) {
        page.graphics.drawString(
          '- ${topic.label} (${topic.count})',
          bodyFont,
          bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18),
        );
        y += 18;
      }
    }

    y += 10;
    page.graphics.drawString('Wrong questions:', bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18));
    y += 18;
    for (final question in wrongQuestions.take(6)) {
      final answer = question.correctIndex >= 0 &&
              question.correctIndex < question.options.length
          ? question.options[question.correctIndex]
          : '';
      page.graphics.drawString(
        'Q: ${question.prompt}',
        bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 36),
        format: PdfStringFormat(wordWrap: PdfWordWrapType.word),
      );
      y += 34;
      page.graphics.drawString(
        'Answer: $answer',
        bodyFont,
        bounds: Rect.fromLTWH(0, y, page.getClientSize().width, 18),
      );
      y += 22;
      if (y > page.getClientSize().height - 80) {
        break;
      }
    }

    final bytes = await doc.save();
    doc.dispose();
    final fileName =
        'exam_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    if (!share && Platform.isIOS) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: context.tr(
          'AI Exam Simulator report',
          'एआई परीक्षा सिमुलेटर प्रतिवेदन',
        ),
      );
      return;
    }
    if (share) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: context.tr(
          'AI Exam Simulator report',
          'एआई परीक्षा सिमुलेटर प्रतिवेदन',
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'PDF saved to ${file.path}',
            'PDF सुरक्षित भयो: ${file.path}',
          ),
        ),
        action: SnackBarAction(
          label: context.tr('Share', 'सेयर'),
          onPressed: () {
            Share.shareXFiles(
              [XFile(file.path)],
              text: context.tr(
                'AI Exam Simulator report',
                'एआई परीक्षा सिमुलेटर प्रतिवेदन',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final Widget child;

  const _ConfigCard({required this.child});

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
      child: child,
    );
  }
}

class _ConfigDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  final String? nullLabel;

  const _ConfigDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2A44)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0B1220),
              icon: const Icon(Icons.expand_more, color: Colors.white70),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white),
              onChanged: onChanged,
              items: [
                if (allowNull)
                  DropdownMenuItem<T>(
                    value: null,
                    child: Text(nullLabel ?? context.tr('All', 'सबै')),
                  ),
                ...items.map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamHeader extends StatelessWidget {
  final int current;
  final int total;
  final Duration timeRemaining;
  final double timeRatio;

  const _ExamHeader({
    required this.current,
    required this.total,
    required this.timeRemaining,
    required this.timeRatio,
  });

  @override
  Widget build(BuildContext context) {
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
                  context.tr('Exam in progress', 'परीक्षा जारी'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
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
              Text(
                context.tr(
                  '${_formatDuration(timeRemaining)} left',
                  '${_formatDuration(timeRemaining)} बाँकी',
                ),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: LinearProgressIndicator(
                  value: timeRatio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1E2A44),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF97316),
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

class _WrittenHeader extends StatelessWidget {
  final Duration timeRemaining;
  final double timeRatio;

  const _WrittenHeader({
    required this.timeRemaining,
    required this.timeRatio,
  });

  @override
  Widget build(BuildContext context) {
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
                  context.tr('Written section', 'लेख्ने सेक्शन'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr(
                    'Answer all questions',
                    'सबै प्रश्नको उत्तर दिनुहोस्',
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
              Text(
                context.tr(
                  '${_formatDuration(timeRemaining)} left',
                  '${_formatDuration(timeRemaining)} बाँकी',
                ),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: LinearProgressIndicator(
                  value: timeRatio,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF1E2A44),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFF97316),
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

class _WrittenQuestionCard extends StatelessWidget {
  final int index;
  final WrittenQuestion question;
  final TextEditingController controller;
  final WrittenGrade? grade;
  final ValueChanged<String> onChanged;

  const _WrittenQuestionCard({
    required this.index,
    required this.question,
    required this.controller,
    required this.grade,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.tr('Q${index + 1}', 'प्र${index + 1}'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Text(
                  context.tr(
                    '${question.marks} marks',
                    '${question.marks} अंक',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            text: question.prompt,
            textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 6,
            minLines: 4,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.tr(
                'Write your answer here...',
                'यहाँ उत्तर लेख्नुहोस्...',
              ),
              hintStyle: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1E2A44)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF1E2A44)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF38BDF8)),
              ),
            ),
          ),
          if (grade != null) ...[
            const SizedBox(height: 14),
            Text(
              context.tr(
                'Score: ${grade!.score}/${grade!.maxScore}',
                'स्कोर: ${grade!.score}/${grade!.maxScore}',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF38BDF8),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            _WrittenInfoBlock(
              title: context.tr('Feedback', 'सुझाव'),
              body: grade!.feedback,
            ),
            const SizedBox(height: 10),
            _WrittenInfoBlock(
              title: context.tr('Best answer', 'सर्वोत्तम उत्तर'),
              body: grade!.modelAnswer,
            ),
            const SizedBox(height: 10),
            _WrittenInfoBlock(
              title: context.tr('Format tips', 'उत्तर लेख्ने तरिका'),
              body: grade!.formatTips,
            ),
          ],
        ],
      ),
    );
  }
}

class _WrittenInfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _WrittenInfoBlock({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          MathText(
            text: body.isEmpty ? context.tr('Not available', 'उपलब्ध छैन') : body,
            textStyle: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white),
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
  final bool showExplanation;

  const _QuestionCard({
    required this.prompt,
    required this.options,
    required this.selectedIndex,
    required this.correctIndex,
    required this.explanation,
    required this.onSelect,
    required this.showExplanation,
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
          MathText(
            text: prompt,
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          if (showExplanation && selectedIndex != null)
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
              child: MathText(
                text: label,
                textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            MathText(
              text: context.tr(
                'Correct answer: $correctAnswer',
                'सही उत्तर: $correctAnswer',
              ),
              textStyle: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          if (explanationText.isNotEmpty) ...[
            const SizedBox(height: 6),
            MathText(
              text: explanationText,
              textStyle: Theme.of(context)
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

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 864000);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}
