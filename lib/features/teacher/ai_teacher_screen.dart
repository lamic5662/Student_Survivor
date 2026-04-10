import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_teacher_service.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class AiTeacherScreen extends StatefulWidget {
  const AiTeacherScreen({super.key});

  @override
  State<AiTeacherScreen> createState() => _AiTeacherScreenState();
}

class _AiTeacherScreenState extends State<AiTeacherScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _teacherQuestionController =
      TextEditingController();
  late final AiTeacherService _teacherService;
  late final FlutterTts _tts;
  AnimationController? _idleController;
  AnimationController? _mouthController;
  bool _showTitle = true;
  Subject? _selectedSubject;
  String _teacherStyle = 'friendly';
  _TeacherStage _stage = _TeacherStage.setup;
  AiTeacherSession? _session;
  AiTeacherEvaluation? _evaluation;
  String? _reteachText;
  AiTeacherHomework? _homework;
  String? _homeworkError;
  String? _errorMessage;
  String? _teacherAnswer;
  bool _loadingAsk = false;
  bool _loadingLesson = false;
  bool _loadingEvaluation = false;
  bool _loadingReteach = false;
  bool _loadingHomework = false;
  bool _loadingHistory = false;
  String? _historyError;
  List<TeacherSessionSummary> _history = const [];
  int _currentQuestion = 0;
  int? _selectedOption;
  final List<int> _scores = [];
  bool _ttsReady = false;
  bool _isSpeaking = false;
  String? _ttsInfo;
  bool _autoSpeakLesson = true;
  bool _autoSpeakQuestion = false;
  double _ttsRate = 0.35;
  bool _sessionLogged = false;
  String? _adaptiveText;
  bool _loadingAdaptive = false;
  _AdaptiveMode _adaptiveMode = _AdaptiveMode.none;
  List<String> _speechSegments = const [];
  int _speechIndex = 0;
  int _speechToken = 0;
  bool _ignoreTtsCancel = false;
  Timer? _ignoreCancelReset;

  final List<_TeacherStyle> _styles = const [
    _TeacherStyle('friendly', 'Friendly teacher', 'मित्रवत शिक्षक'),
    _TeacherStyle('exam', 'Exam-focused', 'परीक्षा केन्द्रित'),
    _TeacherStyle('motivating', 'Motivating', 'प्रेरणादायी'),
    _TeacherStyle('strict', 'Strict teacher', 'कडा शिक्षक'),
    _TeacherStyle('nepaliMix', 'Nepali-English mix', 'नेपाली-अङ्ग्रेजी मिश्रित'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _ensureAvatarControllers();
    _teacherService = AiTeacherService(SupabaseConfig.client);
    _tts = FlutterTts();
    _initTts();
    if (AppState.profile.value.subjects.isNotEmpty) {
      _selectedSubject = AppState.profile.value.subjects.first;
    }
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _topicController.dispose();
    _answerController.dispose();
    _teacherQuestionController.dispose();
    _tts.stop();
    _idleController?.dispose();
    _mouthController?.dispose();
    _ignoreCancelReset?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final sessions = await _teacherService.fetchSessions(limit: 12);
      if (!mounted) return;
      setState(() {
        _history = sessions;
        _loadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString();
        _loadingHistory = false;
      });
    }
  }

  Future<void> _resumeSession(TeacherSessionSummary summary) async {
    setState(() {
      _loadingLesson = true;
      _errorMessage = null;
    });
    try {
      final detail =
          await _teacherService.fetchSessionDetail(summary.id);
      if (!mounted) return;
      if (detail == null) {
        setState(() {
          _loadingLesson = false;
          _errorMessage = context.tr(
            'Unable to load that lesson.',
            'यो पाठ लोड गर्न सकिएन।',
          );
        });
        return;
      }
      Subject? subject;
      if (AppState.profile.value.subjects.isNotEmpty) {
        subject = AppState.profile.value.subjects.firstWhere(
          (s) => s.id == detail.summary.subjectId,
          orElse: () => AppState.profile.value.subjects.first,
        );
      }
      setState(() {
        _selectedSubject = subject;
        _topicController.text = detail.summary.topic;
        _teacherStyle = detail.summary.style;
        _session = AiTeacherSession(
          id: detail.summary.id,
          lesson: detail.lesson,
          questions: detail.questions,
        );
        _currentQuestion = 0;
        _selectedOption = null;
        _evaluation = null;
        _reteachText = null;
        _homework = detail.homework;
        _homeworkError = null;
        _teacherAnswer = null;
        _loadingAsk = false;
        _scores.clear();
        _sessionLogged = false;
        _adaptiveText = null;
        _adaptiveMode = _AdaptiveMode.none;
        _loadingAdaptive = false;
        _loadingLesson = false;
        _stage = _TeacherStage.lesson;
      });
      if (_autoSpeakLesson && _ttsReady) {
        await _toggleSpeak(_buildLessonSpeech(detail.lesson));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLesson = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _deleteSession(TeacherSessionSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete lesson?', 'पाठ हटाउने?')),
        content: Text(
          context.tr(
            'This will remove the saved lesson and its answers.',
            'यसले सुरक्षित पाठ र उत्तरहरू हटाउँछ।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'रद्द गर्नुहोस्')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete', 'हटाउनुहोस्')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _teacherService.deleteSession(summary.id);
    _loadHistory();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _setupGroup({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2A44)),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _setupToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        _setupIcon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF4FA3C7),
        ),
      ],
    );
  }

  Widget _setupIcon(IconData icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Icon(
        icon,
        size: 16,
        color: const Color(0xFF4FA3C7),
      ),
    );
  }

  Future<void> _startLesson() async {
    final topic = _topicController.text.trim();
    if (_selectedSubject == null || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Select a subject and enter a topic first.',
              'पहिला विषय छान्नुहोस् र टपिक लेख्नुहोस्।',
            ),
          ),
        ),
      );
      return;
    }
    await _stopSpeaking();
    setState(() {
      _loadingLesson = true;
      _errorMessage = null;
      _stage = _TeacherStage.lesson;
    });
    try {
      final session = await _teacherService.generateLesson(
        subject: _selectedSubject!.name,
        subjectId: _selectedSubject!.id,
        topic: topic,
        level: AppState.profile.value.semester.name,
        style: _teacherStyle,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _currentQuestion = 0;
        _selectedOption = null;
        _evaluation = null;
        _reteachText = null;
        _homework = null;
        _homeworkError = null;
        _teacherAnswer = null;
        _loadingAsk = false;
        _scores.clear();
        _sessionLogged = false;
        _adaptiveText = null;
        _adaptiveMode = _AdaptiveMode.none;
        _loadingAdaptive = false;
        _loadingLesson = false;
        _stage = _TeacherStage.lesson;
      });
      if (_autoSpeakLesson && _ttsReady) {
        await _toggleSpeak(_buildLessonSpeech(session.lesson));
      }
      _loadHistory();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingLesson = false;
        _errorMessage = error.toString();
        _stage = _TeacherStage.setup;
      });
    }
  }

  void _startQuestions() {
    _stopSpeaking();
    setState(() {
      _stage = _TeacherStage.questions;
      _evaluation = null;
      _reteachText = null;
      _selectedOption = null;
      _answerController.clear();
    });
    if (_autoSpeakQuestion) {
      final question = _activeQuestion;
      if (question != null) {
        _toggleSpeak(_buildQuestionSpeech(question));
      }
    }
  }

  AiTeacherQuestion? get _activeQuestion {
    final session = _session;
    if (session == null) return null;
    if (_currentQuestion < 0 || _currentQuestion >= session.questions.length) {
      return null;
    }
    return session.questions[_currentQuestion];
  }

  Future<void> _checkAnswer() async {
    final question = _activeQuestion;
    if (question == null) return;
    setState(() {
      _loadingEvaluation = true;
      _evaluation = null;
      _reteachText = null;
      _homeworkError = null;
      _errorMessage = null;
    });

    if (question.type == 'mcq') {
      final selected = _selectedOption;
      if (selected == null) {
        _showSnack(
          context.tr(
            'Pick one option first.',
            'पहिला एक विकल्प छान्नुहोस्।',
          ),
        );
        setState(() => _loadingEvaluation = false);
        return;
      }
      final correct = question.answerIndex ?? -1;
      final isCorrect = selected == correct;
      final evaluation = AiTeacherEvaluation(
        verdict: isCorrect ? 'correct' : 'wrong',
        score: isCorrect ? 100 : 0,
        feedback: isCorrect
            ? context.tr('Correct answer.', 'सही उत्तर।')
            : context.tr(
                'Incorrect. Review the explanation and try again.',
                'गलत। व्याख्या हेरेर फेरि प्रयास गर्नुहोस्।',
              ),
        improvedAnswer: question.answer,
      );
      setState(() {
        _loadingEvaluation = false;
        _evaluation = evaluation;
        _scores.add(evaluation.score);
        _adaptiveText = null;
        _adaptiveMode = _AdaptiveMode.none;
        _loadingAdaptive = false;
      });
      final selectedLabel =
          (selected >= 0 && selected < question.options.length)
              ? question.options[selected]
              : '';
      unawaited(
        _teacherService.saveAnswer(
          sessionId: _session?.id,
          questionId: question.id,
          answer: selectedLabel,
          score: evaluation.score,
          verdict: evaluation.verdict,
          feedback: evaluation.feedback,
          improvedAnswer: evaluation.improvedAnswer,
        ),
      );
      unawaited(_maybeAdaptToScore(evaluation.score));
      return;
    }

    final answerText = _answerController.text.trim();
    if (answerText.isEmpty) {
      _showSnack(
        context.tr(
          'Write your answer first.',
          'पहिला उत्तर लेख्नुहोस्।',
        ),
      );
      setState(() => _loadingEvaluation = false);
      return;
    }

    try {
      final evaluation = await _teacherService.evaluateAnswer(
        question: question.prompt,
        expectedAnswer: question.answer,
        studentAnswer: answerText,
        style: _teacherStyle,
        level: AppState.profile.value.semester.name,
      );
      if (!mounted) return;
      setState(() {
        _loadingEvaluation = false;
        _evaluation = evaluation;
        _scores.add(evaluation.score);
        _adaptiveText = null;
        _adaptiveMode = _AdaptiveMode.none;
        _loadingAdaptive = false;
      });
      unawaited(
        _teacherService.saveAnswer(
          sessionId: _session?.id,
          questionId: question.id,
          answer: answerText,
          score: evaluation.score,
          verdict: evaluation.verdict,
          feedback: evaluation.feedback,
          improvedAnswer: evaluation.improvedAnswer,
        ),
      );
      unawaited(_maybeAdaptToScore(evaluation.score));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEvaluation = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _nextQuestion() {
    final session = _session;
    if (session == null) return;
    _stopSpeaking();
    if (_currentQuestion + 1 >= session.questions.length) {
      setState(() => _stage = _TeacherStage.summary);
      unawaited(_recordSessionOutcome());
      return;
    }
    setState(() {
      _currentQuestion += 1;
      _evaluation = null;
      _selectedOption = null;
      _answerController.clear();
      _reteachText = null;
      _adaptiveText = null;
      _adaptiveMode = _AdaptiveMode.none;
      _loadingAdaptive = false;
    });
    if (_autoSpeakQuestion) {
      final question = _activeQuestion;
      if (question != null) {
        _toggleSpeak(_buildQuestionSpeech(question));
      }
    }
  }

  Future<void> _reteach() async {
    final session = _session;
    if (session == null) return;
    await _stopSpeaking();
    setState(() {
      _loadingReteach = true;
      _reteachText = null;
      _homeworkError = null;
    });
    try {
      final text = await _teacherService.reteachSimpler(
        subject: _selectedSubject?.name ?? '',
        topic: _topicController.text.trim(),
        style: _teacherStyle,
      );
      if (!mounted) return;
      setState(() {
        _loadingReteach = false;
        _reteachText = text.trim();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingReteach = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _generateHomework() async {
    if (_session == null) return;
    setState(() {
      _loadingHomework = true;
      _homeworkError = null;
    });
    try {
      final homework = await _teacherService.generateHomework(
        subject: _selectedSubject?.name ?? '',
        topic: _topicController.text.trim(),
        style: _teacherStyle,
        level: AppState.profile.value.semester.name,
      );
      if (!mounted) return;
      setState(() {
        _homework = homework;
        _loadingHomework = false;
      });
      await _teacherService.saveHomework(
        sessionId: _session?.id,
        tasks: homework.tasks,
        target: homework.target,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _homeworkError = error.toString();
        _loadingHomework = false;
      });
    }
  }

  Future<void> _askTeacher() async {
    final subject = _selectedSubject;
    final question = _teacherQuestionController.text.trim();
    if (subject == null || question.isEmpty) {
      _showSnack(
        context.tr(
          'Write a question first.',
          'पहिला प्रश्न लेख्नुहोस्।',
        ),
      );
      return;
    }
    setState(() {
      _loadingAsk = true;
      _teacherAnswer = null;
      _errorMessage = null;
    });
    try {
      final answer = await _teacherService.answerQuestion(
        subject: subject.name,
        topic: _topicController.text.trim().isEmpty
            ? subject.name
            : _topicController.text.trim(),
        level: AppState.profile.value.semester.name,
        style: _teacherStyle,
        question: question,
        lessonSummary: _session?.lesson.summary,
        keyPoints: _session?.lesson.mainPoints,
      );
      if (!mounted) return;
      setState(() {
        _teacherAnswer = answer.trim();
        _loadingAsk = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAsk = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _maybeAdaptToScore(int score) async {
    if (!mounted) return;
    if (score >= 85) {
      setState(() {
        _adaptiveMode = _AdaptiveMode.advance;
        _adaptiveText = context.tr(
          'Great job! We will move a bit faster on the next question.',
          'उत्कृष्ट! अब अर्को प्रश्नमा अलि छिटो अघि बढौँ।',
        );
      });
      return;
    }
    if (score >= 60) {
      setState(() => _adaptiveMode = _AdaptiveMode.none);
      return;
    }
    setState(() {
      _adaptiveMode = _AdaptiveMode.support;
      _loadingAdaptive = true;
      _adaptiveText = null;
    });
    try {
      final text = await _teacherService.reteachSimpler(
        subject: _selectedSubject?.name ?? '',
        topic: _topicController.text.trim(),
        style: _teacherStyle,
      );
      if (!mounted) return;
      setState(() {
        _adaptiveText = text.trim();
        _loadingAdaptive = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adaptiveText = context.tr(
          'Take a moment to review the lesson summary before moving on.',
          'अर्को प्रश्न अघि पाठ सारांश फेरि हेर्नुहोस्।',
        );
        _loadingAdaptive = false;
      });
    }
  }

  Future<void> _recordSessionOutcome() async {
    if (_sessionLogged) return;
    _sessionLogged = true;
    final user = SupabaseConfig.client.auth.currentUser;
    final subject = _selectedSubject;
    final topic = _topicController.text.trim();
    if (user == null || subject == null || topic.isEmpty) return;
    final average = _averageScore();

    ActivityLogService(SupabaseConfig.client).logActivityUnawaited(
      type: 'ai_teacher_session',
      source: 'ai_teacher',
      points: average >= 70 ? 5 : 2,
      subjectId: subject.id,
      metadata: <String, dynamic>{
        'topic': topic,
        'average_score': average,
        'question_count': _scores.length,
      },
    );

    if (average >= 70) return;
    final severity = average < 40
        ? 4
        : average < 55
            ? 3
            : 2;
    try {
      final existing = await SupabaseConfig.client
          .from('weak_topics')
          .select('id,severity')
          .eq('user_id', user.id)
          .eq('topic', topic)
          .maybeSingle();
      final currentSeverity = (existing?['severity'] as num?)?.toInt() ?? 0;
      final nextSeverity =
          severity > currentSeverity ? severity : currentSeverity;
      await SupabaseConfig.client.from('weak_topics').upsert(
        {
          'user_id': user.id,
          'topic': topic,
          'reason': 'Needs review (AI Teacher)',
          'severity': nextSeverity,
          'last_seen_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,topic',
      );
    } catch (_) {}
  }

  Future<void> _initTts() async {
    try {
      bool hasEngine = true;
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.isEmpty) {
          hasEngine = false;
        }
        if (engines is List) {
          _ttsInfo = 'Engines: ${engines.length}';
        }
      } catch (_) {}

      if (!hasEngine) {
        if (mounted) {
          setState(() => _ttsReady = false);
        }
        return;
      }

      final languages = await _tts.getLanguages;
      String? language;
      if (languages is List && languages.isNotEmpty) {
        _ttsInfo = '${_ttsInfo ?? ''} Languages: ${languages.length}'.trim();
        if (languages.contains('en-US')) {
          language = 'en-US';
        } else if (languages.contains('en')) {
          language = 'en';
        } else {
          language = languages.first.toString();
        }
      }
      if (language != null && language.isNotEmpty) {
        await _tts.setLanguage(language);
      }
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(_ttsRate);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        // handled by _runSpeechLoop
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        if (_ignoreTtsCancel) {
          _ignoreTtsCancel = false;
          return;
        }
        // handled by _runSpeechLoop
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        if (_ignoreTtsCancel) {
          _ignoreTtsCancel = false;
          return;
        }
        // handled by _runSpeechLoop
      });
      if (mounted) {
        setState(() => _ttsReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _ttsReady = false);
      }
    }
  }

  Future<void> _toggleSpeak(String text) async {
    if (!_ttsReady) {
      final info = _ttsInfo == null ? '' : ' ($_ttsInfo)';
      _showSnack(
        context.tr(
          'Voice not ready. Install a text-to-speech engine$info.',
          'भ्वाइस तयार छैन। टेक्स्ट-टु-स्पीच इन्जिन इन्स्टल गर्नुहोस्$info।',
        ),
      );
      return;
    }
    if (_isSpeaking) {
      await _stopSpeaking();
      return;
    }
    await _startSpeech(text);
  }

  Future<void> _setTtsRate(double value) async {
    setState(() => _ttsRate = value);
    if (_ttsReady) {
      await _tts.setSpeechRate(_ttsRate);
    }
  }

  Future<void> _stopSpeaking() async {
    if (!_isSpeaking) return;
    _speechToken += 1;
    _speechSegments = const [];
    _speechIndex = 0;
    _ignoreTtsCancel = true;
    _resetIgnoreCancelSoon();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
    });
    _stopMouthAnim();
  }

  Future<void> _startSpeech(String text) async {
    _speechToken += 1;
    _speechSegments = _splitSpeech(text);
    _speechIndex = 0;
    if (_speechSegments.isEmpty) {
      _speechSegments = [text.trim()];
    }
    setState(() {
      _isSpeaking = true;
    });
    _startMouthAnim();
    _ignoreTtsCancel = true;
    _resetIgnoreCancelSoon();
    await _tts.stop();
    await _tts.setSpeechRate(_ttsRate);
    unawaited(_runSpeechLoop(_speechToken));
  }

  Future<void> _runSpeechLoop(int token) async {
    while (mounted && token == _speechToken) {
      if (!_isSpeaking) {
        return;
      }
      if (_speechIndex >= _speechSegments.length) {
        setState(() {
          _isSpeaking = false;
        });
        _stopMouthAnim();
        return;
      }
      final segment = _speechSegments[_speechIndex].trim();
      _speechIndex += 1;
      if (segment.isEmpty) {
        continue;
      }
      final start = DateTime.now();
      try {
        await _tts.speak(segment);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
        });
        _stopMouthAnim();
        return;
      }
      final elapsed =
          DateTime.now().difference(start).inMilliseconds;
      if (elapsed < 120) {
        final waitMs = math.max(300, segment.length * 30);
        await Future.delayed(Duration(milliseconds: waitMs));
      } else {
        await Future.delayed(const Duration(milliseconds: 40));
      }
    }
  }

  List<String> _splitSpeech(String text) {
    final cleaned = text.replaceAll('\n', ' ').trim();
    if (cleaned.isEmpty) return const [];
    const maxLen = 140;
    final segments = <String>[];
    var buffer = StringBuffer();
    for (var i = 0; i < cleaned.length; i += 1) {
      buffer.write(cleaned[i]);
      if (buffer.length >= maxLen) {
        final chunk = buffer.toString().trim();
        if (chunk.isNotEmpty) segments.add(chunk);
        buffer = StringBuffer();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) segments.add(rest);
    return segments;
  }

  void _startMouthAnim() {
    _ensureAvatarControllers();
    final controller = _mouthController;
    if (controller == null) return;
    if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  void _stopMouthAnim() {
    final controller = _mouthController;
    if (controller == null) return;
    controller.stop();
    controller.value = 0;
  }

  void _resetIgnoreCancelSoon() {
    _ignoreCancelReset?.cancel();
    _ignoreCancelReset = Timer(const Duration(milliseconds: 200), () {
      _ignoreTtsCancel = false;
    });
  }

  void _ensureAvatarControllers() {
    if (_idleController != null && _mouthController != null) return;
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _mouthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  String _buildLessonSpeech(AiTeacherLesson lesson) {
    final buffer = StringBuffer();
    buffer.writeln(_speechLine(lesson.title));
    if (lesson.objective.isNotEmpty) {
      buffer.writeln(_speechLine('Objective: ${lesson.objective}'));
    }
    if (lesson.introduction.isNotEmpty) {
      buffer.writeln(_speechLine('Introduction: ${lesson.introduction}'));
    }
    if (lesson.mainPoints.isNotEmpty) {
      for (var i = 0; i < lesson.mainPoints.length; i += 1) {
        buffer.writeln(
          _speechLine('Point ${i + 1}: ${lesson.mainPoints[i]}'),
        );
      }
    }
    if (lesson.example.isNotEmpty) {
      buffer.writeln(_speechLine('Example: ${lesson.example}'));
    }
    if (lesson.summary.isNotEmpty) {
      buffer.writeln(_speechLine('Summary: ${lesson.summary}'));
    }
    return buffer.toString().trim();
  }

  String _buildQuestionSpeech(AiTeacherQuestion question) {
    final buffer = StringBuffer();
    buffer.writeln(_speechLine('Question: ${question.prompt}'));
    if (question.type == 'mcq' && question.options.isNotEmpty) {
      for (var i = 0; i < question.options.length; i += 1) {
        final label = String.fromCharCode(65 + i);
        buffer.writeln(
          _speechLine('Option $label: ${question.options[i]}'),
        );
      }
    }
    return buffer.toString().trim();
  }

  String _speechLine(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return '';
    final hasPunct = RegExp(r'[.!?]$').hasMatch(cleaned);
    return hasPunct ? cleaned : '$cleaned.';
  }

  Widget _buildLessonText(
    BuildContext context,
    AiTeacherLesson lesson, {
    Color titleColor = Colors.white,
    Color bodyColor = Colors.white70,
    Color labelColor = const Color(0xFF4FA3C7),
    Color bulletColor = const Color(0xFF4FA3C7),
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          lesson.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (lesson.objective.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LessonLabel(
            title: context.tr('Objective', 'उद्देश्य'),
            color: labelColor,
          ),
          Text(
            lesson.objective,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: bodyColor),
          ),
        ],
        if (lesson.introduction.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LessonLabel(
            title: context.tr('Introduction', 'परिचय'),
            color: labelColor,
          ),
          Text(
            lesson.introduction,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: bodyColor),
          ),
        ],
        if (lesson.mainPoints.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LessonLabel(
            title: context.tr('Main points', 'मुख्य बुँदाहरू'),
            color: labelColor,
          ),
          const SizedBox(height: 6),
          ...lesson.mainPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: bulletColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: bodyColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (lesson.example.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LessonLabel(
            title: context.tr('Example', 'उदाहरण'),
            color: labelColor,
          ),
          Text(
            lesson.example,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: bodyColor),
          ),
        ],
        if (lesson.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          _LessonLabel(
            title: context.tr('Summary', 'सारांश'),
            color: labelColor,
          ),
          Text(
            lesson.summary,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: bodyColor),
          ),
        ],
      ],
    );
  }

  Widget _buildTeacherAvatar() {
    _ensureAvatarControllers();
    final idle = _idleController;
    final mouth = _mouthController;
    if (idle == null || mouth == null) {
      return const SizedBox(width: 112, height: 148);
    }
    return SizedBox(
      width: 112,
      height: 180,
      child: AnimatedBuilder(
        animation: Listenable.merge([idle, mouth]),
        builder: (context, _) {
          final t = idle.value;
          final bob = math.sin(t * math.pi * 2) * 4;
          final blink = math.sin(t * math.pi * 2) > 0.95;
          final eyeHeight = blink ? 2.0 : 6.0;
          final mouthHeight =
              _isSpeaking ? 6 + (mouth.value * 6) : 4.0;
          return Transform.translate(
            offset: Offset(0, bob),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFBD1B7), Color(0xFFF2B999)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 38,
                      left: 24,
                      child: Container(
                        width: 10,
                        height: eyeHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 38,
                      right: 24,
                      child: Container(
                        width: 10,
                        height: eyeHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 56,
                      child: Container(
                        width: 24,
                        height: mouthHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subjects = AppState.profile.value.subjects;
    final session = _session;
    final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );
    return GameZoneScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            l10n.teacher,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + kToolbarHeight - 108,
          20,
          28,
        ),
        children: [
          _TeacherCard(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Center(child: _buildTeacherAvatar()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Classroom AI Teacher', 'कक्षा एआई शिक्षक'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Step-by-step teaching with questions and feedback.',
                          'क्रमबद्ध सिकाइ, प्रश्न र फिडब्याकसहित।',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr(
                          'Choose subject + topic to start your class.',
                          'कक्षा सुरु गर्न विषय र टपिक छान्नुहोस्।',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white60),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TeacherPill(label: context.tr('Teach', 'पढाइ')),
                          _TeacherPill(label: context.tr('Ask', 'सोध्नुहोस्')),
                          _TeacherPill(label: context.tr('Practice', 'अभ्यास')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loadingHistory || _historyError != null || _history.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TeacherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Past lessons', 'अघिल्ला पाठहरू'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingHistory)
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('Loading history…', 'इतिहास लोड हुँदैछ…'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    )
                  else if (_historyError != null)
                    Text(
                      _historyError!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.danger),
                    )
                  else if (_history.isEmpty)
                    Text(
                      context.tr(
                        'No saved lessons yet.',
                        'अहिलेसम्म सुरक्षित पाठ छैन।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    )
                  else
                    Column(
                      children: _history.map((session) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111B2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF1E2A44),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.lessonTitle.isNotEmpty
                                      ? session.lessonTitle
                                      : session.topic,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${session.subjectName} • ${session.topic}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDate(session.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.white54),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _resumeSession(session),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                      ),
                                      child:
                                          Text(context.tr('Resume', 'जारी')),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _deleteSession(session),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                      ),
                                      child:
                                          Text(context.tr('Delete', 'हटाउनुहोस्')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _TeacherCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Lesson setup', 'पाठ सेटअप'),
                  style: labelStyle?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Pick subject, topic, style, and voice settings.',
                    'विषय, टपिक, शैली र भ्वाइस सेटिङ छान्नुहोस्।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 14),
                _setupGroup(
                  title: context.tr('Subject', 'विषय'),
                  child: subjects.isEmpty
                      ? Text(
                          l10n.noSubjectsAvailable,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        )
                      : DropdownButtonFormField<Subject>(
                          initialValue: _selectedSubject,
                          isExpanded: true,
                          items: subjects
                              .map(
                                (subject) => DropdownMenuItem(
                                  value: subject,
                                  child: Text(
                                    subject.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedSubject = value);
                          },
                          dropdownColor: const Color(0xFF0B1220),
                          decoration: const InputDecoration(
                            filled: false,
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF1E2A44)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF4FA3C7)),
                            ),
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                          iconEnabledColor: Colors.white70,
                        ),
                ),
                const SizedBox(height: 12),
                _setupGroup(
                  title: context.tr('Topic', 'टपिक'),
                  child: TextField(
                    controller: _topicController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'e.g., Operating System basics',
                        'उदाहरण: अपरेटिङ सिस्टम आधारभूत',
                      ),
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: false,
                      border: const OutlineInputBorder(),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF1E2A44)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF4FA3C7)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _setupGroup(
                  title: context.tr('Teacher style', 'शिक्षक शैली'),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _styles
                        .map(
                          (style) => ChoiceChip(
                            selected: _teacherStyle == style.id,
                            onSelected: (_) {
                              setState(() => _teacherStyle = style.id);
                            },
                            label: Text(
                              context.l10n.locale.languageCode == 'ne'
                                  ? style.ne
                                  : style.en,
                            ),
                            labelStyle: TextStyle(
                              color: _teacherStyle == style.id
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedColor: const Color(0xFF4FA3C7),
                            backgroundColor: const Color(0xFF0B1220),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: _teacherStyle == style.id
                                    ? const Color(0xFF4FA3C7)
                                    : const Color(0xFF1E2A44),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _setupGroup(
                  title: context.tr('Voice settings', 'भ्वाइस सेटिङ'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _setupToggleRow(
                        icon: Icons.record_voice_over_rounded,
                        label: context.tr(
                          'Auto speak lesson',
                          'पाठ स्वतः बोल्ने',
                        ),
                        value: _autoSpeakLesson,
                        onChanged: (value) {
                          setState(() => _autoSpeakLesson = value);
                          if (!value) {
                            _stopSpeaking();
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      _setupToggleRow(
                        icon: Icons.question_answer_rounded,
                        label: context.tr(
                          'Auto speak questions',
                          'प्रश्न स्वतः बोल्ने',
                        ),
                        value: _autoSpeakQuestion,
                        onChanged: (value) {
                          setState(() => _autoSpeakQuestion = value);
                          if (!value) {
                            _stopSpeaking();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _setupIcon(Icons.speed_rounded),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('Speech speed', 'बोल्ने गति'),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SpeedChip(
                            label: context.tr('Slow', 'ढिलो'),
                            selected: _ttsRate == 0.28,
                            onTap: () => _setTtsRate(0.28),
                          ),
                          _SpeedChip(
                            label: context.tr('Normal', 'सामान्य'),
                            selected: _ttsRate == 0.35,
                            onTap: () => _setTtsRate(0.35),
                          ),
                          _SpeedChip(
                            label: context.tr('Fast', 'छिटो'),
                            selected: _ttsRate == 0.45,
                            onTap: () => _setTtsRate(0.45),
                          ),
                        ],
                      ),
                      if (!_ttsReady)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.tr(
                              'Voice engine not ready. Install text-to-speech.',
                              'भ्वाइस इन्जिन तयार छैन। टेक्स्ट-टु-स्पीच इन्स्टल गर्नुहोस्।',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.orangeAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startLesson,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4FA3C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      context.tr('Start lesson', 'पाठ सुरु गर्नुहोस्'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_loadingLesson) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF4FA3C7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Preparing your lesson…',
                            'पाठ तयार हुँदैछ…',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.orangeAccent),
                  ),
                ],
              ],
            ),
          ),
          if (session != null) ...[
            const SizedBox(height: 16),
            _TeacherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('Lesson', 'पाठ'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _toggleSpeak(
                          _buildLessonSpeech(session.lesson),
                        ),
                        icon: Icon(
                          _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  _buildLessonText(context, session.lesson),
                  const SizedBox(height: 14),
                  if (_stage == _TeacherStage.lesson)
                    FilledButton(
                      onPressed: _startQuestions,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4FA3C7),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(context.tr('Start questions', 'प्रश्न सुरु')),
                    ),
                ],
              ),
            ),
          ],
          if (session != null) ...[
            const SizedBox(height: 16),
            AppCard(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Ask the teacher', 'शिक्षकलाई सोध्नुहोस्'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _teacherQuestionController,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: context.tr(
                        'Type your doubt here…',
                        'यहाँ आफ्नो प्रश्न लेख्नुहोस्…',
                      ),
                      hintStyle: const TextStyle(color: AppColors.mutedInk),
                      filled: true,
                      fillColor: AppColors.paper,
                      border: const OutlineInputBorder(),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.secondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingAsk)
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF4FA3C7)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          context.tr('Thinking…', 'सोच्दैछ…'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                      ],
                    )
                  else
                    FilledButton(
                      onPressed: _askTeacher,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(context.tr('Ask', 'सोध्नुहोस्')),
                    ),
                  if (_teacherAnswer != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _teacherAnswer!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_stage == _TeacherStage.questions && session != null) ...[
            const SizedBox(height: 16),
            _buildQuestionCard(context, session),
          ],
          if (_stage == _TeacherStage.summary && session != null) ...[
            const SizedBox(height: 16),
            _buildSummaryCard(context, session),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, AiTeacherSession session) {
    final question = _activeQuestion;
    if (question == null) {
      return _TeacherCard(
        child: Text(
          context.tr('No questions available.', 'प्रश्न उपलब्ध छैन।'),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      );
    }

    final total = session.questions.length;
    final current = _currentQuestion + 1;
    final isMcq = question.type == 'mcq';
    final evaluation = _evaluation;
    final needsSupport = evaluation != null && evaluation.score < 60;

    return _TeacherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Question $current of $total', 'प्रश्न $current / $total'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question.prompt,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => _toggleSpeak(
                  _buildQuestionSpeech(question),
                ),
                icon: Icon(
                  _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMcq)
            Column(
              children: List.generate(question.options.length, (index) {
                final option = question.options[index];
                final selected = _selectedOption == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedOption = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF111C2F)
                            : const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF4FA3C7)
                              : const Color(0xFF1E2A44),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected
                                ? const Color(0xFF4FA3C7)
                                : Colors.white54,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            )
          else
            TextField(
              controller: _answerController,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: context.tr(
                  'Type your answer…',
                  'तपाईंको उत्तर लेख्नुहोस्…',
                ),
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF0B1220),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1E2A44)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4FA3C7)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_loadingEvaluation)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF4FA3C7)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr('Checking answer…', 'उत्तर जाँच हुँदैछ…'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _checkAnswer,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('Check answer', 'उत्तर जाँच')),
            ),
          if (evaluation != null) ...[
            const SizedBox(height: 12),
            _TeacherCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Result', 'नतिजा'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${context.tr('Score', 'स्कोर')}: ${evaluation.score}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.tr('Verdict', 'निष्कर्ष')}: ${evaluation.verdict}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  if (evaluation.feedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      evaluation.feedback,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                  if (evaluation.improvedAnswer.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Better answer:', 'सुधारिएको उत्तर:'),
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(color: const Color(0xFF4FA3C7)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      evaluation.improvedAnswer,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            if (_adaptiveMode != _AdaptiveMode.none) ...[
              const SizedBox(height: 10),
              _TeacherCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adaptiveMode == _AdaptiveMode.support
                          ? context.tr('Slow down', 'अलि बिस्तार')
                          : context.tr('Fast track', 'छिटो ट्रयाक'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if (_loadingAdaptive)
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF4FA3C7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr(
                              'Adjusting explanation…',
                              'व्याख्या मिलाउँदैछ…',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      )
                    else if (_adaptiveText != null)
                      Text(
                        _adaptiveText!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed:
                  needsSupport && _loadingAdaptive ? null : _nextQuestion,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              child: Text(
                current == total
                    ? context.tr('Finish', 'समाप्त')
                    : needsSupport
                        ? context.tr('Continue after review', 'रिभ्यूपछि अघि')
                        : context.tr('Next question', 'अर्को प्रश्न'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _averageScore() {
    if (_scores.isEmpty) return 0;
    return (_scores.reduce((a, b) => a + b) / _scores.length).round();
  }

  Widget _buildSummaryCard(BuildContext context, AiTeacherSession session) {
    final average = _averageScore();
    return _TeacherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Lesson summary', 'पाठ सारांश'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${context.tr('Average score', 'औसत स्कोर')}: $average',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          if (_loadingReteach)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF4FA3C7)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr('Reteaching…', 'फेरि सिकाइ हुँदैछ…'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _reteach,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              child: Text(context.tr('Reteach topic', 'फेरि सिकाउनुहोस्')),
            ),
          if (_reteachText != null) ...[
            const SizedBox(height: 10),
            Text(
              _reteachText!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _stage = _TeacherStage.setup;
                _session = null;
                _evaluation = null;
                _reteachText = null;
                _homework = null;
                _homeworkError = null;
                _scores.clear();
                _sessionLogged = false;
                _adaptiveText = null;
                _adaptiveMode = _AdaptiveMode.none;
                _loadingAdaptive = false;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF2B3B55)),
            ),
            child: Text(context.tr('Start new lesson', 'नयाँ पाठ सुरु')),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Homework', 'गृहकार्य'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (_loadingHomework)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF4FA3C7)),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  context.tr('Preparing homework…', 'गृहकार्य तयार हुँदैछ…'),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _generateHomework,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _homework == null
                    ? context.tr('Generate homework', 'गृहकार्य बनाउनुहोस्')
                    : context.tr('Regenerate homework', 'फेरि बनाउनुहोस्'),
              ),
            ),
          if (_homeworkError != null) ...[
            const SizedBox(height: 8),
            Text(
              _homeworkError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.orangeAccent),
            ),
          ],
          if (_homework != null) ...[
            const SizedBox(height: 10),
            ..._homework!.tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Color(0xFF4FA3C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_homework!.target.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('Tomorrow’s target:', 'भोलीको लक्ष्य:'),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: const Color(0xFF4FA3C7)),
              ),
              const SizedBox(height: 4),
              Text(
                _homework!.target,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _TeacherCard({
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

class _TeacherPill extends StatelessWidget {
  final String label;

  const _TeacherPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(999),
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

class _TeacherStyle {
  final String id;
  final String en;
  final String ne;

  const _TeacherStyle(this.id, this.en, this.ne);
}

class _LessonLabel extends StatelessWidget {
  final String title;
  final Color color;

  const _LessonLabel({required this.title, this.color = const Color(0xFF4FA3C7)});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      selectedColor: const Color(0xFF4FA3C7),
      backgroundColor: const Color(0xFF0B1220),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? const Color(0xFF4FA3C7) : const Color(0xFF1E2A44),
        ),
      ),
    );
  }
}


enum _TeacherStage { setup, lesson, questions, summary }

enum _AdaptiveMode { none, support, advance }
