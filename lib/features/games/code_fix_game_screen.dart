import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/ai_status_chip.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/supabase_config.dart';

enum CodeDifficulty { easy, medium, hard }

enum CodeFixMode { findError, fixCode, mcq }

const _codeFixLanguages = ['C', 'C++', 'Java', 'Python'];
const _arenaSurface = Color(0xFF0B1220);
const _arenaBorder = Color(0xFF1E2A44);
const _arenaMuted = Color(0xFF94A3B8);
const _arenaAccent = Color(0xFF38BDF8);

class CodeFixQuestion {
  final String id;
  final String language;
  final CodeDifficulty difficulty;
  final CodeFixMode mode;
  final String prompt;
  final String code;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String? correctedCode;

  const CodeFixQuestion({
    required this.id,
    required this.language,
    required this.difficulty,
    required this.mode,
    required this.prompt,
    required this.code,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.correctedCode,
  });
}

class CodeFixGameScreen extends StatefulWidget {
  const CodeFixGameScreen({super.key});

  @override
  State<CodeFixGameScreen> createState() => _CodeFixGameScreenState();
}

class _CodeFixGameScreenState extends State<CodeFixGameScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  String _selectedLanguage = _codeFixLanguages.first;
  CodeDifficulty _selectedDifficulty = CodeDifficulty.easy;
  List<CodeFixQuestion> _deck = const [];
  int _index = 0;
  int _score = 0;
  int _streak = 0;
  int _answeredCount = 0;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  Timer? _timer;
  bool _isAiGenerating = false;
  bool _answered = false;
  int? _selectedIndex;
  int _lastPoints = 0;
  String? _statusMessage;
  late final ActivityLogService _activityLogService;
  late final AiRouterService _aiRouter;

  @override
  void initState() {
    super.initState();
    _activityLogService = ActivityLogService(SupabaseConfig.client);
    _aiRouter = AiRouterService(SupabaseConfig.client);
    _scrollController.addListener(_handleScroll);
    _rebuildDeck();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  void _rebuildDeck() {
    _timer?.cancel();
    setState(() {
      _deck = const [];
      _index = 0;
      _score = 0;
      _streak = 0;
      _answeredCount = 0;
      _answered = false;
      _selectedIndex = null;
      _lastPoints = 0;
      _statusMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateAiQuestion();
    });
  }

  Future<void> _generateAiQuestion() async {
    if (_isAiGenerating) return;
    final mode = SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (!_isSupportedAi(mode)) {
      _showMessage('AI unavailable. Enable Ollama/LM Studio/Backend.');
      return;
    }
    setState(() {
      _isAiGenerating = true;
    });
    try {
      final prompt = _buildAiPrompt();
      CodeFixQuestion? question;
      String? lastRaw;
      for (var attempt = 0; attempt < 2; attempt += 1) {
        final raw = await _sendChat(
          mode: mode,
          systemPrompt: prompt.system,
          userPrompt: prompt.user,
        );
        lastRaw = raw;
        question = _parseAiQuestion(raw);
        if (question != null) {
          break;
        }
      }
      if (question == null) {
        if (lastRaw != null) {
          debugPrint('AI CodeFix raw response:\n$lastRaw');
        }
        throw Exception('AI response format invalid or wrong language.');
      }
      final resolvedQuestion = question;
      setState(() {
        if (_deck.isEmpty) {
          _deck = [resolvedQuestion];
          _index = 0;
          _answered = false;
          _selectedIndex = null;
          _lastPoints = 0;
          _statusMessage = null;
        } else {
          final insertIndex = (_index + 1).clamp(0, _deck.length);
          _deck = [..._deck]..insert(insertIndex, resolvedQuestion);
        }
      });
      if (_deck.length == 1) {
        _startTimer();
        _showMessage('AI question added!');
      } else {
        _showMessage('AI question added. Tap Next to play it.');
      }
    } catch (error) {
      _showMessage('AI question failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAiGenerating = false;
        });
      }
    }
  }

  ({String system, String user}) _buildAiPrompt() {
    final diff = _difficultyLabel(_selectedDifficulty).toLowerCase();
    final system =
        'You are an expert programming tutor. Return ONLY valid JSON.\n'
        'Schema: {"prompt":"...","code":"...","options":["A","B","C","D"],'
        '"correct_index":0,"explanation":"...","corrected_code":"...","mode":"find_error|fix_code|mcq"}\n'
        'Rules: options must be full answers, correct_index is 0-based, '
        'code should be short and include the bug, corrected_code should fix it. '
        'No markdown, no code fences, no extra text.';
    final user =
        'Generate 1 programming question.\n'
        'Language: $_selectedLanguage\n'
        'Difficulty: $diff\n'
        'Mode: pick one of find_error, fix_code, mcq.\n'
        'Return language field that must equal $_selectedLanguage.\n'
        'Return the JSON object only.';
    return (system: system, user: user);
  }

  CodeFixQuestion? _parseAiQuestion(String raw) {
    final map = _decodeAiJson(raw);
    if (map == null) {
      return _parseAiText(raw);
    }

    final prompt =
        _stringFromKeys(map, ['prompt', 'question', 'task']).trim();
    final code =
        _stringFromKeys(map, ['code', 'snippet', 'buggy_code', 'buggyCode'])
            .trim();
    final explanation =
        _stringFromKeys(map, ['explanation', 'reason', 'why']).trim();
    final corrected = _stringFromKeys(
      map,
      ['corrected_code', 'correctedCode', 'fixed_code', 'fixedCode', 'solution'],
    ).trim();

    final options = _ensureFourOptions(_parseOptions(map));
    if (options.length < 4) {
      return null;
    }

    var correctIndex = _intFromKeys(
          map,
          ['correct_index', 'correctIndex', 'answer_index', 'answerIndex'],
        ) ??
        _indexFromLabel(map['correct_option']?.toString());
    correctIndex ??= 0;
    if (correctIndex < 0 || correctIndex >= options.length) {
      correctIndex = 0;
    }

    final mode = _parseMode(map['mode']?.toString());
    final language =
        _stringFromKeys(map, ['language', 'lang']).trim().toLowerCase();
    final selectedLanguage = _selectedLanguage.toLowerCase();
    if (language.isNotEmpty && language != selectedLanguage) {
      return null;
    }
    final detectedLanguage = _detectLanguageFromCode(code);
    if (detectedLanguage.isNotEmpty &&
        detectedLanguage != selectedLanguage) {
      return null;
    }
    return CodeFixQuestion(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      language: _selectedLanguage,
      difficulty: _selectedDifficulty,
      mode: mode,
      prompt: prompt.isNotEmpty ? prompt : 'Find the error.',
      code: code.isNotEmpty ? code : '/* code not provided */',
      options: options.take(4).toList(),
      correctIndex: correctIndex.clamp(0, 3),
      explanation:
          explanation.isNotEmpty ? explanation : 'Review the corrected code.',
      correctedCode: corrected.isNotEmpty ? corrected : null,
    );
  }

  CodeFixQuestion? _parseAiText(String raw) {
    final cleaned = _stripCodeFences(raw);
    final lines = cleaned.split('\n');

    String prompt = '';
    String answerLabel = '';
    final codeBuf = StringBuffer();
    final explanationBuf = StringBuffer();
    final fixedBuf = StringBuffer();
    final optionLines = <String>[];

    String section = '';
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (section == 'code') {
          codeBuf.writeln('');
        }
        continue;
      }

      String? startsWith(String label) {
        final lower = trimmed.toLowerCase();
        return lower.startsWith(label) ? trimmed.substring(label.length).trim() : null;
      }

      final questionLine =
          startsWith('question:') ?? startsWith('prompt:') ?? startsWith('task:');
      if (questionLine != null) {
        prompt = questionLine;
        section = '';
        continue;
      }

      final codeLine = startsWith('code:') ??
          startsWith('snippet:') ??
          startsWith('buggy code:') ??
          startsWith('buggy_code:');
      if (codeLine != null) {
        section = 'code';
        if (codeLine.isNotEmpty) {
          codeBuf.writeln(codeLine);
        }
        continue;
      }

      final optionsLine = startsWith('options:') ?? startsWith('choices:');
      if (optionsLine != null) {
        section = 'options';
        if (optionsLine.isNotEmpty) {
          optionLines.add(optionsLine);
        }
        continue;
      }

      final answerLine = startsWith('answer:') ??
          startsWith('correct:') ??
          startsWith('correct option:');
      if (answerLine != null) {
        answerLabel = answerLine;
        section = '';
        continue;
      }

      final explanationLine = startsWith('explanation:') ??
          startsWith('reason:') ??
          startsWith('why:');
      if (explanationLine != null) {
        section = 'explanation';
        if (explanationLine.isNotEmpty) {
          explanationBuf.writeln(explanationLine);
        }
        continue;
      }

      final fixedLine = startsWith('corrected code:') ??
          startsWith('fixed code:') ??
          startsWith('solution:');
      if (fixedLine != null) {
        section = 'fixed';
        if (fixedLine.isNotEmpty) {
          fixedBuf.writeln(fixedLine);
        }
        continue;
      }

      if (section == 'code') {
        codeBuf.writeln(line);
        continue;
      }
      if (section == 'options') {
        optionLines.add(line);
        continue;
      }
      if (section == 'explanation') {
        explanationBuf.writeln(line);
        continue;
      }
      if (section == 'fixed') {
        fixedBuf.writeln(line);
        continue;
      }

      if (prompt.isEmpty) {
        prompt = trimmed;
      }
    }

    var code = codeBuf.toString().trim();
    var options = _ensureFourOptions(_parseOptionLines(optionLines));

    if (code.isEmpty) {
      code = _extractCodeBetweenSections(cleaned, options);
    }

    final detectedLanguage = _detectLanguageFromCode(code);
    final selectedLanguage = _selectedLanguage.toLowerCase();
    if (detectedLanguage.isNotEmpty &&
        detectedLanguage != selectedLanguage) {
      return null;
    }

    if (options.length < 4) {
      return null;
    }

    var correctIndex = _indexFromLabel(answerLabel);
    correctIndex ??= _indexFromOptionText(answerLabel, options);
    correctIndex ??= 0;

    return CodeFixQuestion(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      language: _selectedLanguage,
      difficulty: _selectedDifficulty,
      mode: CodeFixMode.findError,
      prompt: prompt.isNotEmpty ? prompt : 'Find the error.',
      code: code.isNotEmpty ? code : '/* code not provided */',
      options: options.take(4).toList(),
      correctIndex: correctIndex.clamp(0, 3),
      explanation: explanationBuf.toString().trim().isNotEmpty
          ? explanationBuf.toString().trim()
          : 'Review the corrected code.',
      correctedCode: fixedBuf.toString().trim().isNotEmpty
          ? fixedBuf.toString().trim()
          : null,
    );
  }

  CodeFixMode _parseMode(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'fix_code':
        return CodeFixMode.fixCode;
      case 'mcq':
        return CodeFixMode.mcq;
      default:
        return CodeFixMode.findError;
    }
  }

  Map<String, dynamic>? _decodeAiJson(String raw) {
    final cleaned = _stripCodeFences(raw);
    dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } catch (_) {
      final extracted = _extractJsonBlock(cleaned);
      if (extracted == null) return null;
      try {
        decoded = jsonDecode(extracted);
      } catch (_) {
        return null;
      }
    }

    if (decoded is List) {
      if (decoded.isEmpty) return null;
      final first = decoded.first;
      if (first is Map<String, dynamic>) return first;
      return null;
    }

    if (decoded is Map<String, dynamic>) {
      final questions = decoded['questions'];
      if (questions is List && questions.isNotEmpty) {
        final first = questions.first;
        if (first is Map<String, dynamic>) return first;
      }
      final question = decoded['question'];
      if (question is Map<String, dynamic>) return question;
      return decoded;
    }

    return null;
  }

  String _stripCodeFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      text = text.replaceFirst(RegExp(r'```$'), '');
    }
    return text.trim();
  }

  String? _extractJsonBlock(String raw) {
    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
    if (objectMatch != null) {
      return objectMatch.group(0);
    }
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(raw);
    return arrayMatch?.group(0);
  }

  String _detectLanguageFromCode(String code) {
    final text = code.toLowerCase();
    if (text.trim().isEmpty) return '';

    int python = 0;
    int c = 0;
    int cpp = 0;
    int java = 0;

    if (text.contains('def ') || text.contains('print(')) python += 2;
    if (text.contains('none') || text.contains('elif ') || text.contains('import ')) {
      python += 1;
    }
    if (RegExp(r':\s*(\n|$)').hasMatch(text)) python += 1;

    if (text.contains('#include')) {
      c += 2;
      cpp += 2;
    }
    if (text.contains('printf') || text.contains('scanf')) c += 2;
    if (text.contains('cout') || text.contains('cin') || text.contains('std::')) {
      cpp += 2;
    }

    if (text.contains('system.out')) java += 2;
    if (text.contains('public class') || text.contains('static void main')) {
      java += 2;
    }
    if (text.contains('new ') || text.contains('arraylist')) java += 1;

    final scores = <String, int>{
      'python': python,
      'c': c,
      'c++': cpp,
      'java': java,
    };
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value == 0) {
      return '';
    }
    final top = sorted.first;
    final second = sorted.length > 1 ? sorted[1].value : 0;
    if (top.value == second) {
      return '';
    }
    return top.key;
  }

  String _stringFromKeys(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString();
        if (text.trim().isNotEmpty) return text;
      }
    }
    return '';
  }

  int? _intFromKeys(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  int? _indexFromLabel(String? label) {
    if (label == null) return null;
    final normalized = label.trim().toLowerCase();
    if (normalized.startsWith('a')) return 0;
    if (normalized.startsWith('b')) return 1;
    if (normalized.startsWith('c')) return 2;
    if (normalized.startsWith('d')) return 3;
    return null;
  }

  List<String> _parseOptions(Map<String, dynamic> map) {
    final rawOptions = map['options'] ?? map['choices'] ?? map['answers'];
    if (rawOptions is List) {
      final list = rawOptions
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (list.length >= 4) return list;
    }
    if (rawOptions is String) {
      final split = rawOptions
          .split(RegExp(r'[\n;]+'))
          .map((e) => e.replaceAll(RegExp(r'^[A-Da-d][\).:\s]+'), ''))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (split.length >= 4) return split;
    }
    return const [];
  }

  List<String> _ensureFourOptions(List<String> options) {
    final filled = [...options];
    const fallbackOptions = [
      'None of the above',
      'All of the above',
      'No error',
      'Correct as is',
    ];
    var index = 0;
    while (filled.length < 4 && index < fallbackOptions.length) {
      if (!filled.contains(fallbackOptions[index])) {
        filled.add(fallbackOptions[index]);
      }
      index += 1;
    }
    return filled;
  }

  List<String> _parseOptionLines(List<String> lines) {
    final cleaned = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final stripped =
          trimmed.replaceAll(RegExp(r'^[A-Da-d][\).:\-\s]+'), '').trim();
      final strippedNum =
          stripped.replaceAll(RegExp(r'^[1-4][\).:\-\s]+'), '').trim();
      cleaned.add(strippedNum.isNotEmpty ? strippedNum : stripped);
    }
    return cleaned.where((e) => e.isNotEmpty).toList();
  }

  int? _indexFromOptionText(String label, List<String> options) {
    if (label.trim().isEmpty) return null;
    final normalized = label.toLowerCase();
    for (var i = 0; i < options.length; i += 1) {
      if (options[i].toLowerCase() == normalized) {
        return i;
      }
    }
    return null;
  }

  String _extractCodeBetweenSections(String raw, List<String> options) {
    final cleaned = _stripCodeFences(raw);
    final lines = cleaned.split('\n');
    final optionLineIndex = lines.indexWhere(
      (line) => RegExp(r'^\s*([A-Da-d]|[1-4])[\).:\-]\s+').hasMatch(line),
    );
    if (optionLineIndex <= 0) return '';
    final codeLines = lines.take(optionLineIndex).toList();
    // Remove prompt line if present.
    if (codeLines.isNotEmpty &&
        codeLines.first.toLowerCase().startsWith('question')) {
      codeLines.removeAt(0);
    }
    return codeLines.join('\n').trim();
  }

  bool _isSupportedAi(String mode) =>
      mode == 'ollama' ||
      _isLmStudio(mode) ||
      mode == 'backend' ||
      mode == 'openrouter' ||
      mode == 'groq' ||
      mode == 'gemini' ||
      mode == 'cloud' ||
      mode == 'auto';

  bool _isLmStudio(String mode) =>
      mode == 'lmstudio' || mode == 'lm-studio' || mode == 'lm_studio';

  Future<String> _sendChat({
    required String mode,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    return _aiRouter.send(
      AiRequest(
        feature: AiFeature.game,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        fastModel: true,
        expectsJson: true,
        metadata: {
          'language': _selectedLanguage,
          'difficulty': _selectedDifficulty.name,
        },
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _totalSeconds = _secondsForDifficulty(_selectedDifficulty);
    _remainingSeconds = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _handleTimeout();
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  int _secondsForDifficulty(CodeDifficulty difficulty) {
    switch (difficulty) {
      case CodeDifficulty.easy:
        return 20;
      case CodeDifficulty.medium:
        return 15;
      case CodeDifficulty.hard:
        return 12;
    }
  }

  CodeFixQuestion? get _currentQuestion {
    if (_deck.isEmpty || _index >= _deck.length) return null;
    return _deck[_index];
  }

  void _handleTimeout() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedIndex = null;
      _statusMessage = 'Time up! 0 points.';
      _lastPoints = 0;
      _streak = 0;
      _answeredCount += 1;
    });
    _activityLogService.logActivityUnawaited(
      type: 'code_fix_answer',
      source: 'code_fix_arena',
      points: 0,
      metadata: {
        'correct': false,
        'reason': 'timeout',
        'language': _selectedLanguage,
        'difficulty': _difficultyLabel(_selectedDifficulty),
      },
    );
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final question = _currentQuestion;
    if (question == null) return;
    final isCorrect = index == question.correctIndex;
    final points = isCorrect ? _calculatePoints() : 0;
    _timer?.cancel();
    setState(() {
      _selectedIndex = index;
      _answered = true;
      _lastPoints = points;
      if (isCorrect) {
        _streak += 1;
        _score += points;
        _statusMessage = 'Correct! +$points points.';
      } else {
        _streak = 0;
        _statusMessage = 'Wrong! 0 points.';
      }
      _answeredCount += 1;
    });
    _activityLogService.logActivityUnawaited(
      type: 'code_fix_answer',
      source: 'code_fix_arena',
      points: points,
      metadata: {
        'correct': isCorrect,
        'language': _selectedLanguage,
        'difficulty': _difficultyLabel(_selectedDifficulty),
        'mode': question.mode.name,
        'streak': _streak,
      },
    );
  }

  int _calculatePoints() {
    const base = 10;
    final streakBonus = min((_streak) * 2, 10);
    var speedBonus = 0;
    final ratio =
        _totalSeconds == 0 ? 0 : _remainingSeconds / _totalSeconds;
    if (ratio >= 0.5) {
      speedBonus = 2;
    } else if (ratio >= 0.25) {
      speedBonus = 1;
    }
    return base + streakBonus + speedBonus;
  }

  void _nextQuestion() {
    if (_isAiGenerating) return;
    if (_deck.isEmpty) {
      _startNewRound(showMessage: false);
      return;
    }
    if (_answeredCount > 0 && _answeredCount % 10 == 0) {
      _startNewRound();
      return;
    }
    if (_index < _deck.length - 1) {
      setState(() {
        _index += 1;
        _answered = false;
        _selectedIndex = null;
        _statusMessage = null;
        _lastPoints = 0;
      });
      _startTimer();
      return;
    }
    _startNewRound();
  }

  void _startNewRound({bool showMessage = true}) {
    _timer?.cancel();
    setState(() {
      _deck = const [];
      _index = 0;
      _answered = false;
      _selectedIndex = null;
      _lastPoints = 0;
      _statusMessage = null;
      _answeredCount = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateAiQuestion();
      if (showMessage) {
        _showMessage('New round started!');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final isFinished = question == null && _deck.isNotEmpty;
    return GameZoneScaffold(
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Code Fix Arena',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      extendBodyBehindAppBar: true,
      useSafeArea: false,
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + kToolbarHeight + 12,
          20,
          28,
        ),
        children: [
          _TopScoreBar(
            score: _score,
            streak: _streak,
            remainingSeconds: _remainingSeconds,
            totalSeconds: _totalSeconds,
          ),
          const SizedBox(height: 12),
          const AiStatusChip(compact: true),
          const SizedBox(height: 16),
          _FilterBar(
            language: _selectedLanguage,
            difficulty: _selectedDifficulty,
            isGenerating: _isAiGenerating,
            onLanguageChanged: (value) {
              setState(() => _selectedLanguage = value);
              _rebuildDeck();
            },
            onDifficultyChanged: (value) {
              setState(() => _selectedDifficulty = value);
              _rebuildDeck();
            },
            onAiGenerate: _generateAiQuestion,
          ),
          const SizedBox(height: 16),
          if (_deck.isEmpty)
            _ArenaCard(
              child: Text(
                _isAiGenerating
                    ? 'Generating your first AI question...'
                    : 'No questions yet. Tap “Ask AI for a question” to start.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: _arenaMuted),
              ),
            )
          else if (isFinished)
            _FinishCard(
              score: _score,
              onRestart: _rebuildDeck,
            )
          else if (question != null) ...[
            _QuestionHeader(
              index: _index + 1,
              total: _deck.length,
              mode: question.mode,
              difficulty: question.difficulty,
              language: question.language,
            ),
            const SizedBox(height: 12),
            Text(
              'Question',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatPrompt(question),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Code',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            _CodeBlock(code: question.code),
            const SizedBox(height: 12),
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];
              final letter = String.fromCharCode(65 + index);
              final isSelected = _selectedIndex == index;
              final isCorrect = question.correctIndex == index;
              final showCorrect = _answered && isCorrect;
              final showWrong = _answered && isSelected && !isCorrect;
              Color? borderColor;
              if (showCorrect) {
                borderColor = AppColors.success;
              } else if (showWrong) {
                borderColor = AppColors.danger;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    side: BorderSide(
                      color: borderColor ?? _arenaBorder,
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _answered ? null : () => _selectAnswer(index),
                  child: Text('$letter. $option'),
                ),
              );
            }),
            if (_answered) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage ??
                    (_lastPoints > 0
                        ? 'Correct! +$_lastPoints points.'
                        : 'Try again.'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _lastPoints > 0
                          ? AppColors.success
                          : AppColors.danger,
                    ),
              ),
              const SizedBox(height: 12),
              _ArenaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Explanation',
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.explanation,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: _arenaMuted),
                    ),
                    if (question.correctedCode != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Correct code',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _CodeBlock(code: question.correctedCode!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _arenaAccent,
                    foregroundColor: const Color(0xFF0B1220),
                  ),
                  child: const Text('Next Question'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TopScoreBar extends StatelessWidget {
  final int score;
  final int streak;
  final int remainingSeconds;
  final int totalSeconds;

  const _TopScoreBar({
    required this.score,
    required this.streak,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        totalSeconds == 0 ? 0.0 : remainingSeconds / totalSeconds;
    return _ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatPill(label: 'Score', value: score.toString()),
              const SizedBox(width: 10),
              _StatPill(label: 'Streak', value: 'x$streak'),
              const Spacer(),
              _StatPill(label: 'Time', value: '${remainingSeconds}s'),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: _arenaBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(_arenaAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _arenaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: _arenaMuted),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String language;
  final CodeDifficulty difficulty;
  final bool isGenerating;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<CodeDifficulty> onDifficultyChanged;
  final VoidCallback onAiGenerate;

  const _FilterBar({
    required this.language,
    required this.difficulty,
    required this.isGenerating,
    required this.onLanguageChanged,
    required this.onDifficultyChanged,
    required this.onAiGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return _ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mode setup',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _codeFixLanguages
                .map(
                  (lang) => ChoiceChip(
                    label: Text(lang),
                    selected: language == lang,
                    onSelected: (_) => onLanguageChanged(lang),
                    selectedColor: _arenaAccent.withValues(alpha: 0.2),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: CodeDifficulty.values
                .map(
                  (level) => ChoiceChip(
                    label: Text(_difficultyLabel(level)),
                    selected: difficulty == level,
                    onSelected: (_) => onDifficultyChanged(level),
                    selectedColor: _arenaAccent.withValues(alpha: 0.2),
                    backgroundColor: const Color(0xFF0F172A),
                    labelStyle: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.white),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isGenerating ? null : onAiGenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _arenaBorder),
              ),
              icon: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                isGenerating ? 'Generating...' : 'Ask AI for a question',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  final int index;
  final int total;
  final CodeFixMode mode;
  final CodeDifficulty difficulty;
  final String language;

  const _QuestionHeader({
    required this.index,
    required this.total,
    required this.mode,
    required this.difficulty,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Question $index / $total',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        const Spacer(),
        _Pill(text: language),
        const SizedBox(width: 6),
        _Pill(text: _difficultyLabel(difficulty)),
        const SizedBox(width: 6),
        _Pill(text: _modeLabel(mode)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _arenaBorder),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SelectableText(
        code,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontFamily: 'monospace',
              height: 1.4,
            ),
      ),
    );
  }
}

class _FinishCard extends StatelessWidget {
  final int score;
  final VoidCallback onRestart;

  const _FinishCard({required this.score, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return _ArenaCard(
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 48, color: _arenaAccent),
          const SizedBox(height: 12),
          Text(
            'Session complete!',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your score: $score',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: _arenaMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _arenaAccent,
                foregroundColor: const Color(0xFF0B1220),
              ),
              child: const Text('Play Again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaCard extends StatelessWidget {
  final Widget child;

  const _ArenaCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _arenaSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _arenaBorder),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

String _difficultyLabel(CodeDifficulty difficulty) {
  switch (difficulty) {
    case CodeDifficulty.easy:
      return 'Easy';
    case CodeDifficulty.medium:
      return 'Medium';
    case CodeDifficulty.hard:
      return 'Hard';
  }
}

String _modeLabel(CodeFixMode mode) {
  switch (mode) {
    case CodeFixMode.findError:
      return 'Find Error';
    case CodeFixMode.fixCode:
      return 'Fix Code';
    case CodeFixMode.mcq:
      return 'MCQ';
  }
}

String _formatPrompt(CodeFixQuestion question) {
  final trimmed = question.prompt.trim();
  if (trimmed.isNotEmpty) {
    return trimmed.endsWith('?') || trimmed.endsWith('.')
        ? trimmed
        : '$trimmed.';
  }
  switch (question.mode) {
    case CodeFixMode.fixCode:
      return 'Fix the code below.';
    case CodeFixMode.mcq:
      return 'Choose the correct answer.';
    case CodeFixMode.findError:
      return 'Find the error in the code below.';
  }
}
