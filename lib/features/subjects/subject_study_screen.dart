import 'dart:math';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/games/subject_flashcards_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectStudyScreen extends StatefulWidget {
  final Subject subject;

  const SubjectStudyScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectStudyScreen> createState() => _SubjectStudyScreenState();
}

class _SubjectStudyScreenState extends State<SubjectStudyScreen> {
  late final AiQuizService _aiQuizService;
  late final Chapter _subjectChapter;
  final _random = Random();

  List<QuizQuestionItem> _questions = const [];
  bool _isGeneratingQuiz = false;
  String? _quizError;

  @override
  void initState() {
    super.initState();
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _subjectChapter = _buildSubjectChapter(widget.subject);
  }

  Chapter _buildSubjectChapter(Subject subject) {
    final notes = <Note>[];
    final important = <Question>[];
    final past = <Question>[];
    for (final chapter in subject.chapters) {
      notes.addAll(chapter.notes);
      important.addAll(chapter.importantQuestions);
      past.addAll(chapter.pastQuestions);
    }
    return Chapter(
      id: 'subject_${subject.id}',
      title: '${subject.name} Overview',
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: const [],
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
      );
      final questions = aiQuestions.isNotEmpty
          ? aiQuestions
          : _fallbackQuestionsFromNotes();
      if (questions.isEmpty) {
        throw Exception('No questions available for this subject.');
      }
      setState(() {
        _questions = questions;
      });
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
      return [];
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
          explanation: null,
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.subject.name),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Questions'),
              Tab(text: 'Games'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SubjectNotesTab(
              subject: widget.subject,
              subjectChapter: _subjectChapter,
            ),
            _buildQuestionsTab(),
            _buildGamesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Subject Quiz',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Generate MCQs using all chapters in this subject.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isGeneratingQuiz ? null : _generateSubjectQuiz,
                child: Text(
                    _isGeneratingQuiz ? 'Generating...' : 'Generate Questions'),
              ),
            ],
          ),
        ),
        if (_quizError != null) ...[
          const SizedBox(height: 12),
          Text(
            _quizError!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
        ],
        if (_questions.isNotEmpty) ...[
          const SizedBox(height: 16),
          ..._questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.prompt,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...question.options.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${String.fromCharCode(65 + entry.key)}. ${entry.value}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.mutedInk),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGamesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject Flashcards',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Practice flashcards across all chapters in this subject.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SubjectFlashcardsScreen(subject: widget.subject),
                    ),
                  );
                },
                child: const Text('Open Flashcards'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectNotesTab extends StatefulWidget {
  final Subject subject;
  final Chapter subjectChapter;

  const _SubjectNotesTab({
    required this.subject,
    required this.subjectChapter,
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

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _chapters = widget.subject.chapters;
    _chapterIds = _chapters
        .map((chapter) => chapter.id)
        .where((id) => id.isNotEmpty)
        .toList();
    _loadUserNotes();
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
        _errorMessage = 'Failed to load notes: $error';
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
          _errorMessage = 'AI notes unavailable. Enable Ollama to generate.';
        });
        return;
      }
      setState(() {
        _draftsByChapter[chapter.id] = draft;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate note: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _generatingChapters.remove(chapter.id);
      });
    }
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
        _errorMessage = 'Failed to save note: $error';
      });
      return;
    } finally {
      if (!mounted) return;
      setState(() {
        _savingChapters.remove(chapter.id);
      });
    }

    if (!mounted) return;
    setState(() {
      _draftsByChapter.remove(chapter.id);
    });
    await _loadUserNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${chapter.title} to My Notes')),
    );
  }

  void _showTextNoteDetails({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
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
      backgroundColor: AppColors.surface,
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
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (shortAnswer.isNotEmpty) ...[
                  Text(
                    'Short Notes',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildTappableText(
                    shortAnswer,
                    contextText: contextText,
                    mainWords: highlight.mainWords,
                    difficultWords: highlight.difficultWords,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: 16),
                ],
                if (detailedAnswer.isNotEmpty) ...[
                  Text(
                    'Detailed Notes',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildTappableText(
                    detailedAnswer,
                    contextText: contextText,
                    mainWords: highlight.mainWords,
                    difficultWords: highlight.difficultWords,
                    style: Theme.of(context).textTheme.bodySmall,
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
  }) {
    final lines = text.split('\n');
    final baseStyle = style ?? Theme.of(context).textTheme.bodyMedium!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          Wrap(
            children: _buildWordWidgets(
              lines[i],
              baseStyle,
              contextText,
              mainWords,
              difficultWords,
            ),
          ),
          if (i != lines.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
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
          message: cached ?? 'Tap to see meaning',
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
                return Text('Failed to load meaning: ${snapshot.error}');
              }
              final meaning = snapshot.data ?? 'No meaning available.';
              return Text(meaning);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
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
          title: const Text('Delete note?'),
          content: const Text('This will remove the note permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
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
        const SnackBar(content: Text('Note deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to delete note: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _deletingNoteId = null;
      });
    }
  }

  Widget _noteCard({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final card = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          if (shortAnswer.isNotEmpty)
            Text(
              shortAnswer,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          if (shortAnswer.isNotEmpty) const SizedBox(height: 12),
          if (detailedAnswer.isNotEmpty)
            Text(
              detailedAnswer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }
    return GestureDetector(
      onTap: onTap,
      child: card,
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
        padding: const EdgeInsets.all(20),
        children: [
          SectionHeader(
            title: 'AI Chapter Notes',
            actionLabel: _isGeneratingAll ? null : 'Generate All',
            onAction: _isGeneratingAll ? null : _generateAllNotes,
          ),
          const SizedBox(height: 12),
          if (_chapters.isEmpty)
            const Text('No chapters found for this subject.')
          else
            ..._chapters.map(
              (chapter) {
                final draft = _draftsByChapter[chapter.id];
                final isGenerating = _generatingChapters.contains(chapter.id);
                final isSaving = _savingChapters.contains(chapter.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppCard(
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
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isGenerating)
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (draft == null)
                          const Text('No AI note yet for this chapter.')
                        else
                          _noteCard(
                            title: draft.title,
                            shortAnswer: draft.shortAnswer,
                            detailedAnswer: draft.detailedAnswer,
                            onTap: () => _showTextNoteDetails(
                              title: draft.title,
                              shortAnswer: draft.shortAnswer,
                              detailedAnswer: draft.detailedAnswer,
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
                              child: Text(
                                draft == null ? 'Generate' : 'Regenerate',
                              ),
                            ),
                            if (draft != null)
                              OutlinedButton(
                                onPressed:
                                    isSaving ? null : () => _saveChapterDraft(chapter),
                                child: isSaving
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save to My Notes'),
                              ),
                            if (draft != null)
                              TextButton(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setState(() {
                                          _draftsByChapter.remove(chapter.id);
                                        });
                                      },
                                child: const Text('Discard'),
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
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            title: 'My Notes',
            actionLabel: _isLoading ? null : 'Refresh',
            onAction: _isLoading ? null : _loadUserNotes,
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_userNotes.isEmpty)
            const Text('No saved notes yet.')
          else
            ..._userNotes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _noteCard(
                  title: note.title,
                  shortAnswer: note.shortAnswer,
                  detailedAnswer: note.detailedAnswer,
                  onTap: () => _showUserNoteDetails(note),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Delete',
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
          const SectionHeader(title: 'Official Notes'),
          const SizedBox(height: 12),
          if (officialNotes.isEmpty)
            const Text('No official notes yet.')
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
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
