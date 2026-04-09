import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/ai_status_chip.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/models/app_models.dart';

enum SubjectNotesSection { myNotes, officialNotes }

class SubjectStudyScreen extends StatefulWidget {
  final Subject subject;
  final bool useGameZoneTheme;
  final int initialTabIndex;
  final SubjectNotesSection? initialNotesSection;

  const SubjectStudyScreen({
    super.key,
    required this.subject,
    this.useGameZoneTheme = false,
    this.initialTabIndex = 0,
    this.initialNotesSection,
  });

  @override
  State<SubjectStudyScreen> createState() => _SubjectStudyScreenState();
}

class _SubjectStudyScreenState extends State<SubjectStudyScreen>
    with SingleTickerProviderStateMixin {
  late final AiQuizService _aiQuizService;
  late final Chapter _subjectChapter;
  final _random = Random();
  bool _showTitle = true;
  bool _showTabs = true;
  TabController? _tabController;

  List<QuizQuestionItem> _questions = const [];
  bool _isGeneratingQuiz = false;
  String? _quizError;
  final Set<String> _seenQuestionPrompts = {};
  final List<int> _pageMarkers = [];
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _subjectChapter = _buildSubjectChapter(widget.subject);
    _ensureTabController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController
      ?..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  void _ensureTabController() {
    if (_tabController != null) return;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    )..addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if ((_tabController?.index ?? 0) == 1 && (!_showTitle || !_showTabs)) {
      setState(() {
        _showTitle = true;
        _showTabs = true;
      });
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if ((_tabController?.index ?? 0) == 1) {
      if (!_showTitle || !_showTabs) {
        setState(() {
          _showTitle = true;
          _showTabs = true;
        });
      }
      return false;
    }
    final shouldShow = notification.metrics.pixels < 24;
    if (shouldShow != _showTitle || shouldShow != _showTabs) {
      setState(() {
        _showTitle = shouldShow;
        _showTabs = shouldShow;
      });
    }
    return false;
  }

  Chapter _buildSubjectChapter(Subject subject) {
    final notes = <Note>[];
    final important = <Question>[];
    final past = <Question>[];
    final subtopics = <ChapterTopic>[];
    final seenTopics = <String>{};
    for (final chapter in subject.chapters) {
      notes.addAll(chapter.notes);
      important.addAll(chapter.importantQuestions);
      past.addAll(chapter.pastQuestions);
      for (final topic in chapter.subtopics) {
        final title = topic.title.trim();
        if (title.isEmpty) continue;
        final key = title.toLowerCase();
        if (seenTopics.contains(key)) continue;
        seenTopics.add(key);
        subtopics.add(topic);
      }
    }
    return Chapter(
      id: 'subject_${subject.id}',
      title: '${subject.name} Overview',
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: const [],
      subtopics: subtopics,
    );
  }

  Future<void> _generateSubjectQuiz() async {
    if (_isGeneratingQuiz) return;
    setState(() {
      _isGeneratingQuiz = true;
      _quizError = null;
    });
    try {
      final aiQuestions = await _aiQuizService.generateQuestions(
        quizId: 'subject_${widget.subject.id}',
        subject: widget.subject,
        chapter: _subjectChapter,
        count: 10,
        baseDifficulty: QuizDifficulty.medium,
        nonce: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final freshQuestions = aiQuestions.isNotEmpty
          ? aiQuestions
          : _fallbackQuestionsFromNotes();
      if (freshQuestions.isEmpty) {
        throw Exception('No questions available for this subject.');
      }
      final merged = List<QuizQuestionItem>.from(_questions);
      final pageStartIndex = merged.length;
      for (final question in freshQuestions) {
        final key = question.prompt.trim().toLowerCase();
        if (key.isEmpty || _seenQuestionPrompts.contains(key)) {
          continue;
        }
        _seenQuestionPrompts.add(key);
        merged.add(question);
      }
      if (merged.length == _questions.length) {
        throw Exception('No new questions generated. Try again.');
      }
      if (_pageMarkers.isEmpty) {
        _pageMarkers.add(0);
      } else if (pageStartIndex < merged.length) {
        _pageMarkers.add(pageStartIndex);
      }
      final pageIndex = _pageMarkers.isEmpty ? 0 : _pageMarkers.length - 1;
      setState(() {
        _questions = merged;
      });
      if (pageIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              pageIndex,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (error) {
      setState(() {
        _quizError = error.toString();
      });
    } finally {
      setState(() {
        _isGeneratingQuiz = false;
      });
    }
  }

  List<QuizQuestionItem> _fallbackQuestionsFromNotes() {
    final notes = _subjectChapter.notes
        .where((note) =>
            note.shortAnswer.trim().isNotEmpty ||
            note.detailedAnswer.trim().isNotEmpty)
        .toList();
    if (notes.isEmpty) {
      final topics = _subjectChapter.subtopics
          .map((topic) => topic.title.trim())
          .where((title) => title.isNotEmpty)
          .toList();
      final fallbackTopics = topics.isNotEmpty
          ? topics
          : widget.subject.chapters
              .map((chapter) => chapter.title.trim())
              .where((title) => title.isNotEmpty)
              .toList();
      if (fallbackTopics.isEmpty) {
        return [];
      }
      final questions = <QuizQuestionItem>[];
      for (var i = 0; i < min(fallbackTopics.length, 10); i += 1) {
        final correct = fallbackTopics[i];
        final options = <String>{correct};
        while (options.length < 4 && options.length < fallbackTopics.length) {
          options.add(fallbackTopics[_random.nextInt(fallbackTopics.length)]);
        }
        while (options.length < 4) {
          options.add('None of the above');
        }
        final optionList = options.toList()..shuffle(_random);
        final correctIndex = optionList.indexOf(correct);
        questions.add(
          QuizQuestionItem(
            id: 'subject_topic_${DateTime.now().millisecondsSinceEpoch}_$i',
            prompt:
                topics.isNotEmpty
                    ? 'Which of the following is a subtopic in ${widget.subject.name}?'
                    : 'Which chapter belongs to ${widget.subject.name}?',
            options: optionList,
            correctIndex: correctIndex == -1 ? 0 : correctIndex,
            topic: correct,
            difficulty: i < 4
                ? 'easy'
                : i < 7
                    ? 'medium'
                    : 'hard',
            explanation:
                topics.isNotEmpty
                    ? '$correct is listed as a subtopic under ${widget.subject.name}.'
                    : '$correct is a chapter in ${widget.subject.name}.',
          ),
        );
      }
      return questions;
    }
    final questions = <QuizQuestionItem>[];
    for (var i = 0; i < min(notes.length, 10); i += 1) {
      final note = notes[i];
      final correct = note.shortAnswer.trim().isNotEmpty
          ? note.shortAnswer.trim()
          : note.detailedAnswer.trim();
      final options = <String>{_trimText(correct, 120)};
      while (options.length < 4 && options.length < notes.length) {
        final other = notes[_random.nextInt(notes.length)];
        final text = other.shortAnswer.trim().isNotEmpty
            ? other.shortAnswer.trim()
            : other.detailedAnswer.trim();
        if (text.isNotEmpty) {
          options.add(_trimText(text, 120));
        }
      }
      while (options.length < 4) {
        options.add('None of the above');
      }
      final optionList = options.toList()..shuffle(_random);
      final correctIndex = optionList.indexOf(_trimText(correct, 120));
      questions.add(
        QuizQuestionItem(
          id: 'subject_fallback_${DateTime.now().millisecondsSinceEpoch}_$i',
          prompt: 'What is ${note.title}?',
          options: optionList,
          correctIndex: correctIndex == -1 ? 0 : correctIndex,
          topic: note.title,
          difficulty: i < 4
              ? 'easy'
              : i < 7
                  ? 'medium'
                  : 'hard',
          explanation: _trimText(
            note.detailedAnswer.trim().isNotEmpty
                ? note.detailedAnswer.trim()
                : note.shortAnswer.trim(),
            200,
          ),
        ),
      );
    }
    return questions;
  }

  String _trimText(String text, int max) {
    if (text.length <= max) {
      return text;
    }
    return text.substring(0, max);
  }

  @override
  Widget build(BuildContext context) {
    _ensureTabController();
    final tabController = _tabController!;
    final tabBar = TabBar(
      controller: tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: const Color(0xFF4FA3C7),
      tabs: [
        Tab(text: context.tr('Notes', 'नोट्स')),
        Tab(text: context.tr('Questions', 'प्रश्नहरू')),
      ],
    );

    final tabBarWidget = PreferredSize(
      preferredSize:
          Size.fromHeight(_showTabs ? kTextTabBarHeight : 0),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _showTabs ? kTextTabBarHeight : 0,
          child: _showTabs ? tabBar : const SizedBox.shrink(),
        ),
      ),
    );

    final appBar = AppBar(
      title: AnimatedOpacity(
        opacity: _showTitle ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          widget.subject.name,
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
      surfaceTintColor: Colors.transparent,
      bottom: tabBarWidget,
    );

    final body = NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: TabBarView(
        controller: tabController,
        children: [
          _SubjectNotesTab(
            subject: widget.subject,
            subjectChapter: _subjectChapter,
            initialSection: widget.initialNotesSection,
          ),
          _buildQuestionsTab(),
        ],
      ),
    );

    return GameZoneScaffold(
      appBar: appBar,
      body: body,
      useSafeArea: false,
      extendBodyBehindAppBar: true,
    );
  }

  Widget _buildQuestionsTab() {
    final pages = _splitQuestionsByPage();
    final topInset = MediaQuery.of(context).padding.top +
        kToolbarHeight +
        kTextTabBarHeight +
        8;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topInset, 20, 20),
      child: Column(
        children: [
          _GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('AI Subject Quiz', 'AI विषय क्विज'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                const AiStatusChip(compact: true),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Generate MCQs using all chapters in this subject.',
                    'यस विषयका सबै अध्यायबाट MCQ बनाउनुहोस्।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isGeneratingQuiz ? null : _generateSubjectQuiz,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4FA3C7),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                      _isGeneratingQuiz
                          ? context.tr('Generating...', 'बनाइँदैछ...')
                          : context.tr('Generate Questions', 'प्रश्न बनाउनुहोस्')),
                ),
              ],
            ),
          ),
          if (_quizError != null) ...[
            const SizedBox(height: 6),
            Text(
              _quizError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ],
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.tr(
                  '${_questions.length} questions',
                  '${_questions.length} प्रश्न',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (_) {},
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return ListView(
                    padding: EdgeInsets.zero,
                    primary: false,
                    children: [
                      _SectionTitle(
                        title: context.tr(
                          'Page ${index + 1}',
                          'पृष्ठ ${index + 1}',
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...page.map((question) => _buildQuestionCard(context, question)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          if (index > 0)
                            OutlinedButton.icon(
                              onPressed: () => _goToPage(index - 1),
                              icon: const Icon(Icons.chevron_left),
                              label:
                                  Text(context.tr('Previous', 'अघिल्लो')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(
                                  color: Color(0xFF4FA3C7),
                                ),
                              ),
                            ),
                          if (index < pages.length - 1)
                            OutlinedButton.icon(
                              onPressed: () => _goToPage(index + 1),
                              icon: const Icon(Icons.chevron_right),
                              label:
                                  Text(context.tr('Next Page', 'अर्को पृष्ठ')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(
                                  color: Color(0xFF4FA3C7),
                                ),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _isGeneratingQuiz
                                  ? null
                                  : _generateSubjectQuiz,
                              icon: const Icon(Icons.auto_awesome),
                              label: Text(
                                context.tr(
                                  'Generate Next Page',
                                  'अर्को पृष्ठ बनाउनुहोस्',
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(
                                  color: Color(0xFF4FA3C7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isGeneratingQuiz ? null : _generateSubjectQuiz,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isGeneratingQuiz
                    ? context.tr('Generating...', 'बनाइँदैछ...')
                    : context.tr('Generate Next Page', 'अर्को पृष्ठ बनाउनुहोस्'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<List<QuizQuestionItem>> _splitQuestionsByPage() {
    if (_questions.isEmpty) return const [];
    final markers = _pageMarkers.isEmpty ? [0] : _pageMarkers.toList();
    markers.sort();
    final pages = <List<QuizQuestionItem>>[];
    for (var i = 0; i < markers.length; i += 1) {
      final start = markers[i];
      final end = i + 1 < markers.length ? markers[i + 1] : _questions.length;
      if (start >= _questions.length || start >= end) continue;
      pages.add(_questions.sublist(start, end));
    }
    if (pages.isEmpty) {
      pages.add(List<QuizQuestionItem>.from(_questions));
    }
    return pages;
  }

  Widget _buildQuestionCard(BuildContext context, QuizQuestionItem question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _GameCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MathText(
              text: question.prompt,
              textStyle: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 6),
            ...question.options.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: MathText(
                      text:
                          '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                      textStyle: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ),
            const SizedBox(height: 6),
            MathText(
              text: context.tr(
                'Answer: ${_answerFor(context, question)}',
                'उत्तर: ${_answerFor(context, question)}',
              ),
              textStyle: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: const Color(0xFF22C55E),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (question.explanation != null &&
                question.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              MathText(
                text: question.explanation!,
                textStyle: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _goToPage(int index) {
    if (index < 0) return;
    final pages = _splitQuestionsByPage();
    if (index >= pages.length) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    }
  }

  String _answerFor(BuildContext context, QuizQuestionItem question) {
    final index = question.correctIndex;
    if (index >= 0 && index < question.options.length) {
      return question.options[index];
    }
    return context.tr('Answer not available', 'उत्तर उपलब्ध छैन');
  }

}

class _SubjectNotesTab extends StatefulWidget {
  final Subject subject;
  final Chapter subjectChapter;
  final SubjectNotesSection? initialSection;

  const _SubjectNotesTab({
    required this.subject,
    required this.subjectChapter,
    this.initialSection,
  });

  @override
  State<_SubjectNotesTab> createState() => _SubjectNotesTabState();
}

class _SubjectNotesTabState extends State<_SubjectNotesTab> {
  late final UserNotesService _userNotesService;
  late final AiNotesService _aiNotesService;
  bool _isLoading = true;
  bool _isGeneratingAll = false;
  String? _deletingNoteId;
  String? _errorMessage;
  List<UserNote> _userNotes = const [];
  final Map<String, NoteDraft> _draftsByChapter = {};
  final Set<String> _generatingChapters = {};
  final Set<String> _savingChapters = {};
  final Map<String, String> _definitionCache = {};
  late final List<Chapter> _chapters;
  late final List<String> _chapterIds;
  final GlobalKey _myNotesKey = GlobalKey();
  final GlobalKey _officialNotesKey = GlobalKey();
  late final FlutterTts _tts;
  bool _ttsReady = false;
  bool _isSpeaking = false;
  String? _speakingKey;
  int _speakingStart = -1;
  int _speakingEnd = -1;
  String? _speakingText;
  int _speakingCursor = 0;
  String? _speakingCursorText;
  String? _speakingWord;

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _tts = FlutterTts();
    _initTts();
    _chapters = widget.subject.chapters;
    _chapterIds = _chapters
        .map((chapter) => chapter.id)
        .where((id) => id.isNotEmpty)
        .toList();
    _loadUserNotes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      bool hasEngine = true;
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.isEmpty) {
          hasEngine = false;
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
      await _tts.setSpeechRate(0.35);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingKey = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
          _speakingWord = null;
        });
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingKey = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
          _speakingWord = null;
        });
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingKey = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
          _speakingWord = null;
        });
      });
      _tts.setProgressHandler((text, start, end, word) {
        if (!mounted || !_isSpeaking) return;
        final baseText = _speakingCursorText ?? text;
        final range = _resolveSpeechRange(baseText, text, start, end, word);
        if (range == null) return;
        setState(() {
          _speakingText = baseText;
          _speakingStart = range.start;
          _speakingEnd = range.end;
          _speakingWord = word.toString();
        });
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

  Future<void> _toggleSpeak(String key, String text) async {
    if (!_ttsReady) {
      await _initTts();
    }
    if (!_ttsReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable text-to-speech to use voice notes.'),
        ),
      );
      return;
    }
    if (_isSpeaking && _speakingKey == key) {
      await _tts.stop();
      return;
    }
    if (_isSpeaking) {
      await _tts.stop();
    }
    setState(() {
      _isSpeaking = true;
      _speakingKey = key;
      _speakingText = text;
      _speakingStart = -1;
      _speakingEnd = -1;
      _speakingCursor = 0;
      _speakingCursorText = text;
      _speakingWord = null;
    });
    await _tts.speak(text);
  }

  void _scrollToSection() {
    final targetKey = widget.initialSection == SubjectNotesSection.officialNotes
        ? _officialNotesKey
        : widget.initialSection == SubjectNotesSection.myNotes
            ? _myNotesKey
            : null;
    final context = targetKey?.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  Future<void> _loadUserNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final notes = await _userNotesService.fetchForSubject(_chapterIds);
      if (!mounted) return;
      setState(() {
        _userNotes = notes;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to load notes: $error',
          'नोट लोड गर्न असफल: $error',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _generateChapterNote(Chapter chapter) async {
    if (_generatingChapters.contains(chapter.id)) return;
    setState(() {
      _generatingChapters.add(chapter.id);
      _errorMessage = null;
    });
    try {
      final draft = await _aiNotesService.generateNote(
        subject: widget.subject,
        chapter: chapter,
      );
      if (!mounted) return;
      if (draft == null) {
        setState(() {
          _errorMessage = _aiNotesUnavailableMessage();
        });
        return;
      }
      setState(() {
        _draftsByChapter[chapter.id] = draft;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to generate note: $error',
          'नोट बनाउन असफल: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _generatingChapters.remove(chapter.id);
        });
      }
    }
  }

  String _aiNotesUnavailableMessage() {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.notes).toLowerCase();
    if (mode == 'ollama') {
      return context.tr(
        'AI notes unavailable. Start Ollama to generate.',
        'AI नोट उपलब्ध छैन। Ollama सुरु गर्नुहोस्।',
      );
    }
    if (mode.contains('lmstudio') || mode.contains('lm-studio')) {
      return context.tr(
        'AI notes unavailable. Start LM Studio to generate.',
        'AI नोट उपलब्ध छैन। LM Studio सुरु गर्नुहोस्।',
      );
    }
    if (mode == 'backend') {
      return context.tr(
        'AI notes unavailable. Backend AI not reachable.',
        'AI नोट उपलब्ध छैन। Backend AI पहुँचमा छैन।',
      );
    }
    if (mode == 'groq' || mode == 'gemini' || mode == 'cloud' || mode == 'auto') {
      return context.tr(
        'AI notes unavailable. Check cloud AI keys or switch to Ollama.',
        'AI नोट उपलब्ध छैन। Cloud key जाँच गर्नुहोस् वा Ollama प्रयोग गर्नुहोस्।',
      );
    }
    return context.tr(
      'AI notes unavailable right now.',
      'AI नोट अहिले उपलब्ध छैन।',
    );
  }

  Future<void> _generateAllNotes() async {
    if (_isGeneratingAll) return;
    setState(() {
      _isGeneratingAll = true;
      _errorMessage = null;
    });
    for (final chapter in _chapters) {
      await _generateChapterNote(chapter);
    }
    if (!mounted) return;
    setState(() {
      _isGeneratingAll = false;
    });
  }

  Future<void> _saveChapterDraft(Chapter chapter) async {
    final draft = _draftsByChapter[chapter.id];
    if (draft == null || _savingChapters.contains(chapter.id)) return;
    setState(() {
      _savingChapters.add(chapter.id);
      _errorMessage = null;
    });
    try {
      await _userNotesService.saveNote(
        chapterId: chapter.id,
        title: draft.title,
        shortAnswer: draft.shortAnswer,
        detailedAnswer: draft.detailedAnswer,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to save note: $error',
          'नोट सुरक्षित गर्न असफल: $error',
        );
      });
      return;
    } finally {
      if (mounted) {
        setState(() {
          _savingChapters.remove(chapter.id);
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _draftsByChapter.remove(chapter.id);
    });
    await _loadUserNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Saved ${chapter.title} to My Notes',
            '${chapter.title} मेरो नोटमा सुरक्षित भयो',
          ),
        ),
      ),
    );
  }

  void _openAttachment({
    required String title,
    required String url,
  }) {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('No attachment available.', 'संलग्न फाइल छैन।'),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: title,
          url: url,
        ),
      ),
    );
  }

  void _showTextNoteDetails({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    String? fileUrl,
  }) {
    final contextText = _buildNoteContext(
      title: title,
      shortAnswer: shortAnswer,
      detailedAnswer: detailedAnswer,
    );
    final highlight = _buildHighlightSets(contextText);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
      final safeUrl = fileUrl ?? '';
      return ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2A44),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 16),
                if (safeUrl.isNotEmpty) ...[
                  if (_isImageUrl(safeUrl)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        safeUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 180,
                            alignment: Alignment.center,
                            color: const Color(0xFF0B1220),
                            child: const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          alignment: Alignment.center,
                          color: const Color(0xFF0B1220),
                          child: Text(
                            context.tr(
                              'Image unavailable',
                              'तस्बिर उपलब्ध छैन',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _GameCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file_rounded,
                          color: Color(0xFF4FA3C7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('Attachment available', 'संलग्न उपलब्ध'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openAttachment(
                            title: title,
                            url: safeUrl,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF4FA3C7),
                          ),
                          child: Text(context.tr('Open', 'खोल्नुहोस्')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (detailedAnswer.isNotEmpty ||
                    shortAnswer.isNotEmpty) ...[
                  Text(
                    context.tr('Notes', 'नोट्स'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildFormattedTappableNoteBody(
                    detailedAnswer.isNotEmpty ? detailedAnswer : shortAnswer,
                    contextText: contextText,
                    mainWords: highlight.mainWords,
                    difficultWords: highlight.difficultWords,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ] else if (safeUrl.isEmpty) ...[
                  Text(
                    context.tr(
                      'No note content available yet.',
                      'अहिलेसम्म नोट सामग्री छैन।',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  void _showUserNoteDetails(UserNote note) {
    _showTextNoteDetails(
      title: note.title,
      shortAnswer: note.shortAnswer,
      detailedAnswer: note.detailedAnswer,
      fileUrl: null,
    );
  }

  String _buildNoteContext({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
  }) {
    return [
      title,
      shortAnswer,
      detailedAnswer,
    ].where((line) => line.trim().isNotEmpty).join('\n');
  }

  Widget _buildTappableText(
    String text, {
    required String contextText,
    required Set<String> mainWords,
    required Set<String> difficultWords,
    TextStyle? style,
    bool justify = false,
  }) {
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    final segments = _splitBlockMath(text);
    final widgets = <Widget>[];
    for (final segment in segments) {
      if (segment.isMath) {
        widgets.add(_buildMathBlock(segment.text, baseStyle));
        continue;
      }
      final lines = segment.text.split('\n');
      for (var i = 0; i < lines.length; i += 1) {
        final lineWidgets = _buildInlineMathWidgets(
          lines[i],
          baseStyle,
          contextText,
          mainWords,
          difficultWords,
        );
        if (lineWidgets.isNotEmpty) {
          widgets.add(
            Wrap(
              alignment:
                  justify ? WrapAlignment.spaceBetween : WrapAlignment.start,
              runSpacing: 6,
              children: lineWidgets,
            ),
          );
        }
        if (i != lines.length - 1) {
          widgets.add(const SizedBox(height: 6));
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<_MathSegment> _splitBlockMath(String text) {
    final regex = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    final segments = <_MathSegment>[];
    var cursor = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        segments.add(_MathSegment(
          text: text.substring(cursor, match.start),
          isMath: false,
        ));
      }
      final math = match.group(1) ?? '';
      segments.add(_MathSegment(text: math, isMath: true));
      cursor = match.end;
    }
    if (cursor < text.length) {
      segments.add(_MathSegment(text: text.substring(cursor), isMath: false));
    }
    if (segments.isEmpty) {
      segments.add(_MathSegment(text: text, isMath: false));
    }
    return segments;
  }

  Widget _buildMathBlock(String tex, TextStyle style) {
    final content = tex.trim();
    if (content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          content,
          mathStyle: MathStyle.display,
          textStyle: style.copyWith(color: style.color),
        ),
      ),
    );
  }

  List<Widget> _buildInlineMathWidgets(
    String line,
    TextStyle style,
    String contextText,
    Set<String> mainWords,
    Set<String> difficultWords,
  ) {
    if (line.isEmpty) return const [];
    final inlineRegex = RegExp(r'\$(.+?)\$');
    final widgets = <Widget>[];
    var cursor = 0;
    for (final match in inlineRegex.allMatches(line)) {
      if (match.start > cursor) {
        widgets.addAll(_buildWordWidgets(
          line.substring(cursor, match.start),
          style,
          contextText,
          mainWords,
          difficultWords,
        ));
      }
      final tex = match.group(1)?.trim() ?? '';
      if (tex.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Math.tex(
              tex,
              mathStyle: MathStyle.text,
              textStyle: style.copyWith(color: style.color),
            ),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < line.length) {
      widgets.addAll(_buildWordWidgets(
        line.substring(cursor),
        style,
        contextText,
        mainWords,
        difficultWords,
      ));
    }
    return widgets;
  }

  bool _isImageUrl(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      return path.endsWith('.png') ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.gif') ||
          path.endsWith('.webp');
    } catch (_) {
      final lower = url.toLowerCase();
      return lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.gif') ||
          lower.contains('.webp');
    }
  }

  List<Widget> _buildWordWidgets(
    String line,
    TextStyle style,
    String contextText,
    Set<String> mainWords,
    Set<String> difficultWords,
  ) {
    final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final widgets = <Widget>[];
    for (final word in words) {
      final cleaned =
          word.replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '');
      if (cleaned.length < 2) {
        widgets.add(Text('$word ', style: style));
        continue;
      }
      final key = cleaned.toLowerCase();
      final isMain = mainWords.contains(key);
      final isDifficult = difficultWords.contains(key);
      final cached = _definitionCache[key];
      final highlightStyle = _buildHighlightStyle(
        style,
        isMain: isMain,
        isDifficult: isDifficult,
      );
      widgets.add(
        Tooltip(
          message: cached ??
              context.tr('Tap to see meaning', 'अर्थ हेर्न ट्याप गर्नुहोस्'),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showWordMeaning(cleaned, contextText),
              child: Text(
                '$word ',
                style: highlightStyle,
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  TextStyle _buildHighlightStyle(
    TextStyle base, {
    required bool isMain,
    required bool isDifficult,
  }) {
    var style = base.copyWith(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
    );
    if (isMain) {
      style = style.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.secondary,
      );
    }
    if (isDifficult) {
      style = style.copyWith(
        backgroundColor: AppColors.warning.withValues(alpha: 0.2),
      );
    }
    return style;
  }

  Future<void> _showWordMeaning(String word, String contextText) async {
    final key = word.toLowerCase();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(word),
          content: FutureBuilder<String>(
            future: _fetchMeaning(key, word, contextText),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  context.tr(
                    'Failed to load meaning: ${snapshot.error}',
                    'अर्थ लोड गर्न असफल: ${snapshot.error}',
                  ),
                );
              }
              final meaning = snapshot.data ??
                  context.tr('No meaning available.', 'अर्थ उपलब्ध छैन।');
              return Text(meaning);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('Close', 'बन्द गर्नुहोस्')),
            ),
          ],
        );
      },
    );
  }

  Future<String> _fetchMeaning(
    String key,
    String word,
    String contextText,
  ) async {
    final cached = _definitionCache[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final meaning = await _aiNotesService.defineWord(
      word: word,
      context: contextText,
    );
    if (mounted) {
      setState(() {
        _definitionCache[key] = meaning;
      });
    }
    return meaning;
  }

  ({Set<String> mainWords, Set<String> difficultWords}) _buildHighlightSets(
    String text,
  ) {
    final tokens = _extractTokens(text);
    final freq = <String, int>{};
    for (final token in tokens) {
      freq[token] = (freq[token] ?? 0) + 1;
    }
    final sorted = freq.keys.toList()
      ..sort((a, b) => (freq[b] ?? 0).compareTo(freq[a] ?? 0));
    final mainWords = sorted.take(10).toSet();

    final difficultWords = tokens
        .where((token) => token.length >= 8 && !mainWords.contains(token))
        .take(8)
        .toSet();

    return (mainWords: mainWords, difficultWords: difficultWords);
  }

  List<String> _extractTokens(String text) {
    final lower = text.toLowerCase();
    final matches = RegExp(r'[a-zA-Z]{3,}').allMatches(lower);
    final tokens = <String>[];
    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token.isEmpty) continue;
      if (_stopWords.contains(token)) continue;
      tokens.add(token);
    }
    return tokens;
  }

  static const Set<String> _stopWords = {
    'the',
    'and',
    'for',
    'with',
    'that',
    'this',
    'from',
    'into',
    'are',
    'was',
    'were',
    'has',
    'have',
    'had',
    'can',
    'could',
    'should',
    'would',
    'will',
    'shall',
    'may',
    'might',
    'also',
    'about',
    'above',
    'below',
    'between',
    'within',
    'without',
    'these',
    'those',
    'their',
    'there',
    'here',
    'such',
    'then',
    'than',
    'when',
    'what',
    'which',
    'where',
    'while',
    'who',
    'whom',
    'why',
    'how',
    'your',
    'our',
    'you',
    'we',
    'they',
    'them',
    'its',
    'it',
    'a',
    'an',
    'in',
    'on',
    'of',
    'to',
    'as',
    'at',
    'by',
    'or',
    'is',
    'be',
    'not',
    'no',
    'yes',
    'if',
    'so',
    'because',
    'using',
    'used',
    'use',
    'based',
    'each',
    'every',
    'most',
    'more',
    'less',
    'many',
    'much',
    'some',
    'any',
    'other',
    'another',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  };

  Future<void> _confirmDelete(UserNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Delete note?', 'नोट हटाउने?')),
          content: Text(
            context.tr(
              'This will remove the note permanently.',
              'यसले नोट स्थायी रूपमा हटाउनेछ।',
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
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await _deleteNote(note);
  }

  Future<void> _deleteNote(UserNote note) async {
    if (_deletingNoteId == note.id) return;
    setState(() {
      _deletingNoteId = note.id;
      _errorMessage = null;
    });
    try {
      await _userNotesService.deleteNote(note.id);
      await _loadUserNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Note deleted', 'नोट हटाइयो'))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to delete note: $error',
          'नोट हटाउन असफल: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }

  Widget _noteBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  _TextHighlightRange? _resolveHighlightRange(
    String displayText,
    bool isSpeaking,
  ) {
    if (!isSpeaking) return null;
    final speakingText = _speakingText;
    if (speakingText == null || speakingText.isEmpty) return null;
    var start = _speakingStart;
    var end = _speakingEnd;
    if (start < 0 || end <= start) return null;
    if (speakingText != displayText) {
      final index = speakingText.indexOf(displayText);
      if (index < 0) {
        return _fallbackWordRange(displayText);
      }
      start = start - index;
      end = end - index;
    }
    if (start < 0 || end > displayText.length) {
      return _fallbackWordRange(displayText);
    }
    return _TextHighlightRange(start, end);
  }

  _TextHighlightRange? _fallbackWordRange(String displayText) {
    final word = _speakingWord?.trim();
    if (word == null || word.isEmpty) return null;
    final lowerText = displayText.toLowerCase();
    final lowerWord = word.toLowerCase();
    final wordIndex = lowerText.indexOf(lowerWord);
    if (wordIndex >= 0) {
      return _TextHighlightRange(wordIndex, wordIndex + lowerWord.length);
    }
    return null;
  }

  _TextHighlightRange? _resolveSpeechRange(
    String baseText,
    String rawText,
    int start,
    int end,
    String? word,
  ) {
    final token = (word ?? '').trim();
    if (token.isNotEmpty) {
      final lowerBase = baseText.toLowerCase();
      final lowerWord = token.toLowerCase();
      var index = lowerBase.indexOf(lowerWord, _speakingCursor);
      if (index < 0) {
        index = lowerBase.indexOf(lowerWord);
      }
      if (index >= 0) {
        _speakingCursor = index + lowerWord.length;
        return _TextHighlightRange(index, index + lowerWord.length);
      }
    }
    if (rawText == baseText &&
        start >= 0 &&
        end > start &&
        end <= baseText.length) {
      return _TextHighlightRange(start, end);
    }
    return null;
  }

  Widget _buildHighlightedText(
    String text,
    TextStyle? style, {
    int? maxLines,
    TextOverflow overflow = TextOverflow.visible,
    TextAlign textAlign = TextAlign.start,
    required bool isSpeaking,
  }) {
    final highlight = _resolveHighlightRange(text, isSpeaking);
    if (highlight == null) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      );
    }
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium;
    final highlightStyle = baseStyle?.copyWith(
      color: Colors.black,
      backgroundColor: const Color(0xFFFFD54F).withValues(alpha: 0.65),
      fontWeight: FontWeight.w600,
    );
    return RichText(
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      text: TextSpan(
        style: baseStyle,
        children: [
          if (highlight.start > 0)
            TextSpan(text: text.substring(0, highlight.start)),
          TextSpan(
            text: text.substring(highlight.start, highlight.end),
            style: highlightStyle,
          ),
          if (highlight.end < text.length)
            TextSpan(text: text.substring(highlight.end)),
        ],
      ),
    );
  }

  List<_NoteBlock> _parseNoteBlocks(String text) {
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final blocks = <_NoteBlock>[];
    final paragraph = <String>[];
    final bullets = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_NoteBlock.paragraph(paragraph.join(' ')));
      paragraph.clear();
    }

    void flushBullets() {
      if (bullets.isEmpty) return;
      blocks.add(_NoteBlock.bullets(List<String>.from(bullets)));
      bullets.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        flushParagraph();
        flushBullets();
        continue;
      }
      if (_isHeadingLine(line)) {
        flushParagraph();
        flushBullets();
        blocks.add(_NoteBlock.heading(_cleanHeading(line)));
        continue;
      }
      final bulletText = _extractBullet(line);
      if (bulletText != null) {
        flushParagraph();
        bullets.add(bulletText);
        continue;
      }
      if (bullets.isNotEmpty) {
        flushBullets();
      }
      paragraph.add(line);
    }
    flushParagraph();
    flushBullets();
    return blocks;
  }

  bool _isHeadingLine(String line) {
    if (line.startsWith('#')) return true;
    final lowered = line.toLowerCase();
    if (line.endsWith(':') && line.length <= 40) return true;
    const tokens = [
      'summary',
      'key points',
      'important',
      'steps',
      'examples',
      'example',
      'formula',
      'definition',
      'use cases',
      'applications',
    ];
    return tokens.any(
      (token) =>
          lowered == token ||
          lowered.startsWith('$token:') ||
          lowered.startsWith('$token -'),
    );
  }

  String _cleanHeading(String line) {
    var cleaned = line.replaceAll(RegExp(r'^#+\\s*'), '').trim();
    if (cleaned.endsWith(':')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned;
  }

  String? _extractBullet(String line) {
    final match = RegExp(r'^(\\d+[\\).\\s]+|[-*•]\\s+)(.+)$').firstMatch(line);
    if (match == null) return null;
    return match.group(2)?.trim();
  }

  List<Widget> _buildFormattedNoteBody(
    String text, {
    required bool isSpeaking,
  }) {
    final blocks = _parseNoteBlocks(text);
    final widgets = <Widget>[];
    for (final block in blocks) {
      switch (block.type) {
        case _NoteBlockType.heading:
          widgets.add(_noteSectionHeader(block.text ?? ''));
          break;
        case _NoteBlockType.paragraph:
          widgets.add(
            _buildHighlightedText(
              block.text ?? '',
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.justify,
              isSpeaking: isSpeaking,
            ),
          );
          break;
        case _NoteBlockType.bullets:
          widgets.add(
            Column(
              children: [
                for (final item in block.items ?? const [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4FA3C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHighlightedText(
                            item,
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                            textAlign: TextAlign.justify,
                            isSpeaking: isSpeaking,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
          break;
      }
      widgets.add(const SizedBox(height: 10));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  List<Widget> _buildFormattedTappableNoteBody(
    String text, {
    required String contextText,
    required Set<String> mainWords,
    required Set<String> difficultWords,
    TextStyle? style,
  }) {
    final blocks = _parseNoteBlocks(text);
    final widgets = <Widget>[];
    for (final block in blocks) {
      switch (block.type) {
        case _NoteBlockType.heading:
          widgets.add(_noteSectionHeader(block.text ?? ''));
          break;
        case _NoteBlockType.paragraph:
          widgets.add(
            _buildTappableText(
              block.text ?? '',
              contextText: contextText,
              mainWords: mainWords,
              difficultWords: difficultWords,
              style: style,
              justify: true,
            ),
          );
          break;
        case _NoteBlockType.bullets:
          widgets.add(
            Column(
              children: [
                for (final item in block.items ?? const [])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4FA3C7),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTappableText(
                            item,
                            contextText: contextText,
                            mainWords: mainWords,
                            difficultWords: difficultWords,
                            style: style,
                            justify: true,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
          break;
      }
      widgets.add(const SizedBox(height: 10));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _noteSectionHeader(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF122039),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: Color(0xFF4FA3C7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    Widget? trailing,
    VoidCallback? onTap,
    bool collapsible = false,
    bool showTapHint = false,
    String? badgeLabel,
    Color? badgeColor,
    IconData? badgeIcon,
    bool showAttachmentBadge = false,
    String? voiceKey,
    String? voiceText,
    bool formatAsAi = false,
  }) {
    final speechText = (voiceText ?? '').trim();
    final resolvedKey = voiceKey ?? title;
    final isSpeaking = _isSpeaking && _speakingKey == resolvedKey;
    final voiceButton = speechText.isEmpty
        ? null
        : IconButton(
            tooltip: isSpeaking ? 'Stop' : 'Listen',
            onPressed: () => _toggleSpeak(resolvedKey, speechText),
            icon: Icon(
              isSpeaking ? Icons.stop_circle : Icons.volume_up_rounded,
              color: Colors.white70,
            ),
          );
    Widget? mergedTrailing;
    if (voiceButton != null && trailing != null) {
      mergedTrailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [voiceButton, trailing],
      );
    } else {
      mergedTrailing = voiceButton ?? trailing;
    }
    if (collapsible) {
      final summaryText =
          detailedAnswer.trim().isNotEmpty ? detailedAnswer.trim() : shortAnswer.trim();
      final detailText = detailedAnswer.trim();
      return _GameCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          subtitle: summaryText.isEmpty
              ? null
              : _buildHighlightedText(
                  summaryText,
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  isSpeaking: isSpeaking,
                ),
          trailing: mergedTrailing,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            if (badgeLabel != null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _noteBadge(
                    label: badgeLabel,
                    color: badgeColor ?? AppColors.secondary,
                    icon: badgeIcon ?? Icons.auto_awesome_rounded,
                  ),
                  if (showAttachmentBadge)
                    _noteBadge(
                      label: context.tr('Attachment', 'संलग्न'),
                      color: AppColors.warning,
                      icon: Icons.attach_file_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (detailText.isNotEmpty && detailText != summaryText) ...[
              if (formatAsAi)
                ..._buildFormattedNoteBody(detailText, isSpeaking: isSpeaking)
              else
                _buildHighlightedText(
                  detailText,
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                  isSpeaking: isSpeaking,
                ),
            ] else if (summaryText.isNotEmpty) ...[
              if (formatAsAi)
                ..._buildFormattedNoteBody(summaryText, isSpeaking: isSpeaking)
              else
                _buildHighlightedText(
                  summaryText,
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                  isSpeaking: isSpeaking,
                ),
            ],
          ],
        ),
      );
    }

    final previewText = detailedAnswer.trim().isNotEmpty
        ? detailedAnswer.trim()
        : shortAnswer.trim();
    final card = _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badgeLabel != null || showAttachmentBadge) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (badgeLabel != null)
                  _noteBadge(
                    label: badgeLabel,
                    color: badgeColor ?? AppColors.secondary,
                    icon: badgeIcon ?? Icons.bookmark_rounded,
                  ),
                if (showAttachmentBadge)
                  _noteBadge(
                    label: context.tr('Attachment', 'संलग्न'),
                    color: AppColors.warning,
                    icon: Icons.attach_file_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
              ...?(mergedTrailing == null ? null : [mergedTrailing]),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isNotEmpty)
            _buildHighlightedText(
              previewText,
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              isSpeaking: isSpeaking,
            ),
          if (previewText.isNotEmpty) const SizedBox(height: 12),
          if (showTapHint && onTap != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr(
                    'Tap to open full note',
                    'पूरा नोट खोल्न ट्याप गर्नुहोस्',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final officialNotes = <({Note note, String chapterTitle})>[];
    for (final chapter in widget.subject.chapters) {
      for (final note in chapter.notes) {
        officialNotes.add((note: note, chapterTitle: chapter.title));
      }
    }
    return RefreshIndicator(
      onRefresh: _loadUserNotes,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          max(
            0.0,
            MediaQuery.of(context).padding.top +
                kToolbarHeight +
                kTextTabBarHeight -
                96,
          ),
          20,
          24,
        ),
        children: [
          _GameCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('AI Chapter Notes', 'AI अध्याय नोट्स'),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        const AiStatusChip(compact: true),
                      ],
                    ),
                  ),
                  if (_isGeneratingAll)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF4FA3C7),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _generateAllNotes,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: Text(context.tr('Generate All', 'सबै बनाउनुहोस्')),
                    ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                if (_chapters.isEmpty)
                  Text(
                    context.tr(
                      'No chapters found for this subject.',
                      'यस विषयका कुनै अध्याय भेटिएन।',
                    ),
                    style: const TextStyle(color: Colors.white70),
                  )
                else
                  ..._chapters.map(
                    (chapter) {
                      final draft = _draftsByChapter[chapter.id];
                      final isGenerating =
                          _generatingChapters.contains(chapter.id);
                      final isSaving = _savingChapters.contains(chapter.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      chapter.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                    ),
                                  ),
                                  if (isGenerating)
                                    const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4FA3C7),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (draft == null)
                                Text(
                                  context.tr(
                                    'No AI note yet for this chapter.',
                                    'यस अध्यायका लागि AI नोट छैन।',
                                  ),
                                  style: const TextStyle(color: Colors.white70),
                                )
                              else
                                _noteCard(
                                  title: draft.title,
                                  shortAnswer: draft.shortAnswer,
                                  detailedAnswer: draft.detailedAnswer,
                                  collapsible: true,
                                  formatAsAi: true,
                                  badgeLabel: context.tr('AI Draft', 'AI ड्राफ्ट'),
                                  badgeColor: AppColors.secondary,
                                  badgeIcon: Icons.auto_awesome_rounded,
                                  voiceKey: 'draft_${chapter.id}',
                                  voiceText: _buildNoteContext(
                                    title: draft.title,
                                    shortAnswer: draft.shortAnswer,
                                    detailedAnswer: draft.detailedAnswer,
                                  ),
                                  trailing: IconButton(
                                    tooltip: context.tr('Open', 'खोल्नुहोस्'),
                                    onPressed: () => _showTextNoteDetails(
                                      title: draft.title,
                                      shortAnswer: draft.shortAnswer,
                                      detailedAnswer: draft.detailedAnswer,
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton(
                                    onPressed: isGenerating
                                        ? null
                                        : () => _generateChapterNote(chapter),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF4FA3C7),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      draft == null
                                          ? context.tr('Generate', 'बनाउनुहोस्')
                                          : context.tr('Regenerate', 'पुनः बनाउनुहोस्'),
                                    ),
                                  ),
                                  if (draft != null)
                                    OutlinedButton(
                                      onPressed: isSaving
                                          ? null
                                          : () =>
                                              _saveChapterDraft(chapter),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(
                                          color: Color(0xFF4FA3C7),
                                        ),
                                      ),
                                      child: isSaving
                                          ? const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF4FA3C7),
                                              ),
                                            )
                                          : Text(
                                              context.tr(
                                                'Save to My Notes',
                                                'मेरो नोटमा सुरक्षित गर्नुहोस्',
                                              ),
                                            ),
                                    ),
                                  if (draft != null)
                                    TextButton(
                                      onPressed: isSaving
                                          ? null
                                          : () {
                                              setState(() {
                                                _draftsByChapter
                                                    .remove(chapter.id);
                                              });
                                            },
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                      ),
                                      child: Text(
                                        context.tr('Discard', 'रद्द गर्नुहोस्'),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFFF87171)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _myNotesKey,
            child: _SectionTitle(
              title: context.tr('My Notes', 'मेरो नोट्स'),
              actionLabel:
                  _isLoading ? null : context.tr('Refresh', 'रिफ्रेस'),
              onAction: _isLoading ? null : _loadUserNotes,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4FA3C7),
              ),
            )
          else if (_userNotes.isEmpty)
            Text(
              context.tr('No saved notes yet.', 'अहिलेसम्म नोट सुरक्षित छैन।'),
              style: const TextStyle(color: Colors.white70),
            )
          else
            ..._userNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _noteCard(
                  title: note.title,
                  shortAnswer: note.shortAnswer,
                  detailedAnswer: note.detailedAnswer,
                  onTap: () => _showUserNoteDetails(note),
                  showTapHint: true,
                  formatAsAi: true,
                  badgeLabel: context.tr('My Note', 'मेरो नोट'),
                  badgeColor: AppColors.accent,
                  badgeIcon: Icons.bookmark_rounded,
                  voiceKey: note.id,
                  voiceText: _buildNoteContext(
                    title: note.title,
                    shortAnswer: note.shortAnswer,
                    detailedAnswer: note.detailedAnswer,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.tr('Open', 'खोल्नुहोस्'),
                        onPressed: () => _showUserNoteDetails(note),
                        icon: const Icon(Icons.open_in_new),
                      ),
                      IconButton(
                        tooltip: context.tr('Delete', 'हटाउनुहोस्'),
                        onPressed: _deletingNoteId == note.id
                            ? null
                            : () => _confirmDelete(note),
                        icon: _deletingNoteId == note.id
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: _officialNotesKey,
            child: _SectionTitle(
              title: context.tr('Official Notes', 'आधिकारिक नोट्स'),
            ),
          ),
          const SizedBox(height: 12),
          if (officialNotes.isEmpty)
            Text(
              context.tr('No official notes yet.', 'अहिलेसम्म आधिकारिक नोट्स छैन।'),
              style: const TextStyle(color: Colors.white70),
            )
          else
            ...officialNotes.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _noteCard(
                  title: '${entry.note.title} • ${entry.chapterTitle}',
                  shortAnswer: entry.note.shortAnswer,
                  detailedAnswer: entry.note.detailedAnswer,
                  onTap: () => _showTextNoteDetails(
                    title: '${entry.note.title} (${entry.chapterTitle})',
                    shortAnswer: entry.note.shortAnswer,
                    detailedAnswer: entry.note.detailedAnswer,
                    fileUrl: entry.note.fileUrl,
                  ),
                  showTapHint: true,
                  badgeLabel: context.tr('Official', 'आधिकारिक'),
                  badgeColor: AppColors.secondary,
                  badgeIcon: Icons.verified_rounded,
                  showAttachmentBadge: (entry.note.fileUrl ?? '').isNotEmpty,
                  voiceKey: entry.note.id,
                  voiceText: _buildNoteContext(
                    title: entry.note.title,
                    shortAnswer: entry.note.shortAnswer,
                    detailedAnswer: entry.note.detailedAnswer,
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111B2E),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF1E2A44)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new,
                            size: 14, color: Color(0xFF4FA3C7)),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('Open', 'खोल्नुहोस्'),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF4FA3C7),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF4FA3C7),
            ),
            child: Text(actionLabel!),
          ),
      ],
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

class _MathSegment {
  final String text;
  final bool isMath;

  const _MathSegment({
    required this.text,
    required this.isMath,
  });
}

class _TextHighlightRange {
  final int start;
  final int end;

  const _TextHighlightRange(this.start, this.end);
}

enum _NoteBlockType { heading, paragraph, bullets }

class _NoteBlock {
  final _NoteBlockType type;
  final String? text;
  final List<String>? items;

  const _NoteBlock._(this.type, {this.text, this.items});

  factory _NoteBlock.heading(String text) =>
      _NoteBlock._(_NoteBlockType.heading, text: text);

  factory _NoteBlock.paragraph(String text) =>
      _NoteBlock._(_NoteBlockType.paragraph, text: text);

  factory _NoteBlock.bullets(List<String> items) =>
      _NoteBlock._(_NoteBlockType.bullets, items: items);
}
