import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/games/battle_quiz_screen.dart';
import 'package:student_survivor/features/games/flashcards_screen.dart';
import 'package:student_survivor/features/quiz/quiz_detail_screen.dart';
import 'package:student_survivor/features/quiz/quiz_play_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class ChapterDetailScreen extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;

  const ChapterDetailScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapter.title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Important'),
              Tab(text: 'Past Qs'),
              Tab(text: 'Games'),
              Tab(text: 'Quizzes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotesTab(subject: subject, chapter: chapter),
            _QuestionsTab(
              subject: subject,
              chapter: chapter,
              questions: chapter.importantQuestions,
              showAiQuiz: true,
            ),
            _QuestionsTab(questions: chapter.pastQuestions),
            _GamesTab(subject: subject, chapter: chapter),
            _QuizzesTab(
              subject: subject,
              chapter: chapter,
              quizzes: chapter.quizzes,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesTab extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;

  const _NotesTab({
    required this.subject,
    required this.chapter,
  });

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  late final UserNotesService _userNotesService;
  late final AiNotesService _aiNotesService;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _deletingNoteId;
  String? _errorMessage;
  List<UserNote> _userNotes = const [];
  NoteDraft? _draft;
  final Map<String, String> _definitionCache = {};

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _loadUserNotes();
  }

  Future<void> _loadUserNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final notes = await _userNotesService.fetchForChapter(widget.chapter.id);
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

  Future<void> _generateNote() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final draft = await _aiNotesService.generateNote(
        subject: widget.subject,
        chapter: widget.chapter,
      );
      if (!mounted) return;
      if (draft == null) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'AI notes unavailable. Enable Ollama to generate.';
        });
        return;
      }
      setState(() {
        _draft = draft;
        _isGenerating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate note: $error';
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    final draft = _draft;
    if (draft == null || _isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await _userNotesService.saveNote(
        chapterId: widget.chapter.id,
        title: draft.title,
        shortAnswer: draft.shortAnswer,
        detailedAnswer: draft.detailedAnswer,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save note: $error';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _draft = null;
      _isSaving = false;
    });
    await _loadUserNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to My Notes')),
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
      final cleaned = word.replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '');
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
    final notes = widget.chapter.notes;
    return RefreshIndicator(
      onRefresh: _loadUserNotes,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SectionHeader(
            title: 'AI Notes',
            actionLabel: _isGenerating ? null : 'Generate',
            onAction: _isGenerating ? null : _generateNote,
          ),
          const SizedBox(height: 12),
          if (_isGenerating)
            const Center(child: CircularProgressIndicator())
          else if (_draft == null)
            const Text('Generate a quick AI note for this chapter.'),
          if (_draft != null) ...[
            _noteCard(
              title: _draft!.title,
              shortAnswer: _draft!.shortAnswer,
              detailedAnswer: _draft!.detailedAnswer,
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveDraft,
                  child: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save to My Notes'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _draft = null;
                          });
                        },
                  child: const Text('Discard'),
                ),
              ],
            ),
          ],
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
          if (notes.isEmpty)
            const Text('No official notes yet.')
          else
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _noteCard(
                  title: note.title,
                  shortAnswer: note.shortAnswer,
                  detailedAnswer: note.detailedAnswer,
                  onTap: () => _showTextNoteDetails(
                    title: note.title,
                    shortAnswer: note.shortAnswer,
                    detailedAnswer: note.detailedAnswer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final List<Question> questions;
  final Subject? subject;
  final Chapter? chapter;
  final bool showAiQuiz;

  const _QuestionsTab({
    required this.questions,
    this.subject,
    this.chapter,
    this.showAiQuiz = false,
  });

  Quiz? _pickAiQuiz(List<Quiz> quizzes) {
    if (quizzes.isEmpty) return null;
    for (final quiz in quizzes) {
      if (quiz.title.toLowerCase().contains('ai')) {
        return quiz;
      }
    }
    return quizzes.first;
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (showAiQuiz && subject != null && chapter != null) {
      final aiQuiz = _pickAiQuiz(chapter!.quizzes);
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Quick Quiz',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Answer AI-generated MCQs based on this chapter.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: aiQuiz == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuizPlayScreen(
                                quiz: aiQuiz,
                                subject: subject!,
                                chapter: chapter,
                                isAi: true,
                              ),
                            ),
                          );
                        },
                  child: Text(
                    aiQuiz == null ? 'No quiz available' : 'Start AI Quiz',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (questions.isEmpty) {
      items.add(const Text('No questions yet.'));
      return ListView(
        padding: const EdgeInsets.all(20),
        children: items,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length + questions.length,
      itemBuilder: (context, index) {
        if (index < items.length) {
          return items[index];
        }
        final questionIndex = index - items.length;
        final question = questions[questionIndex];
        final year = question.year;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_outline, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        year == null
                            ? '${question.marks} marks'
                            : '${question.marks} marks • $year',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuizzesTab extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final List<Quiz> quizzes;

  const _QuizzesTab({
    required this.subject,
    required this.chapter,
    required this.quizzes,
  });

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return const Center(child: Text('No quizzes yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${quiz.questionCount} questions • ${quiz.duration.inMinutes} min',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizDetailScreen(
                            quiz: quiz,
                            subject: subject,
                            chapter: chapter,
                          ),
                        ),
                      );
                    },
                    child: const Text('Play Quiz'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GamesTab extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;

  const _GamesTab({
    required this.subject,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Flashcards',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Flip cards based on official notes and your saved notes.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FlashcardsScreen(
                          subject: subject,
                          chapter: chapter,
                        ),
                      ),
                    );
                  },
                  child: const Text('Play Flashcards'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Battle Quiz',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Answer questions to attack and level up. Difficulty increases.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BattleQuizScreen(
                          subject: subject,
                          chapter: chapter,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Battle'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
