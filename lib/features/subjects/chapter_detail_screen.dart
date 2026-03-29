import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/note_submission_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/models/app_models.dart';

class ChapterDetailScreen extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final bool useGameZoneTheme;
  final bool openSubmitSheet;

  const ChapterDetailScreen({
    super.key,
    required this.subject,
    required this.chapter,
    this.useGameZoneTheme = false,
    this.openSubmitSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    final tabBar = TabBar(
      isScrollable: true,
      labelColor: useGameZoneTheme ? AppColors.ink : null,
      unselectedLabelColor: useGameZoneTheme ? AppColors.mutedInk : null,
      indicatorColor: useGameZoneTheme ? AppColors.secondary : null,
      tabs: const [
        Tab(text: 'Notes'),
        Tab(text: 'Important'),
        Tab(text: 'Past Qs'),
      ],
    );

    final appBar = AppBar(
      title: Text(chapter.title),
      backgroundColor: useGameZoneTheme ? AppColors.paper : null,
      foregroundColor: useGameZoneTheme ? AppColors.ink : null,
      elevation: useGameZoneTheme ? 0 : null,
      scrolledUnderElevation: useGameZoneTheme ? 0 : null,
      surfaceTintColor: useGameZoneTheme ? Colors.transparent : null,
      bottom: tabBar,
    );

    final body = TabBarView(
      children: [
        _NotesTab(
          subject: subject,
          chapter: chapter,
          openSubmitSheet: openSubmitSheet,
        ),
        _QuestionsTab(
          title: 'Important Questions',
          subject: subject,
          chapter: chapter,
          questions: chapter.importantQuestions,
        ),
        _QuestionsTab(
          title: 'Past Questions',
          subject: subject,
          chapter: chapter,
          questions: chapter.pastQuestions,
        ),
      ],
    );

    return DefaultTabController(
      length: 3,
      child: useGameZoneTheme
          ? GameZoneScaffold(
              appBar: appBar,
              body: body,
              useSafeArea: false,
            )
          : Scaffold(
              appBar: appBar,
              body: body,
            ),
    );
  }
}

class _NotesTab extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;
  final bool openSubmitSheet;

  const _NotesTab({
    required this.subject,
    required this.chapter,
    this.openSubmitSheet = false,
  });

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  late final UserNotesService _userNotesService;
  late final AiNotesService _aiNotesService;
  late final NoteSubmissionService _noteSubmissionService;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isSaving = false;
  String? _deletingNoteId;
  String? _errorMessage;
  List<UserNote> _userNotes = const [];
  List<NoteSubmission> _submissions = const [];
  NoteDraft? _draft;
  final Map<String, String> _definitionCache = {};

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _noteSubmissionService = NoteSubmissionService(SupabaseConfig.client);
    _loadUserNotes();
    _loadSubmissions();
    if (widget.openSubmitSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openSubmissionSheet();
      });
    }
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

  Future<void> _loadSubmissions() async {
    try {
      final submissions = await _noteSubmissionService.fetchMySubmissions(
        widget.chapter.id,
      );
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
      });
    } catch (_) {
      // Keep silent for now; submissions are optional.
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

  Future<void> _openSubmissionSheet() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _NoteSubmissionSheet(
          onUploadAttachment: (file) =>
              _noteSubmissionService.uploadSubmissionAttachment(
                chapterId: widget.chapter.id,
                file: file,
              ),
          onSubmit: (title, content, tags, fileUrl) async {
            try {
              await _noteSubmissionService.submitNote(
                chapterId: widget.chapter.id,
                title: title,
                shortAnswer: _deriveShortFromDetailed(content),
                detailedAnswer: content,
                fileUrl: fileUrl,
                tags: tags,
              );
              return null;
            } catch (error) {
              return 'Submit failed: $error';
            }
          },
        );
      },
    );

    if (submitted == true) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await _loadSubmissions();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Submitted for approval.')),
      );
    }
  }

  Future<void> _deleteSubmission(NoteSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete submission?'),
        content: const Text('This will remove your pending submission.'),
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
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _noteSubmissionService.deleteSubmission(submission.id);
      await _loadSubmissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
    }
  }

  String _deriveShortFromDetailed(String detailed) {
    final lines = detailed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length >= 3) {
      return lines.take(3).join('\n');
    }
    final sentences = detailed
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isNotEmpty) {
      return sentences.take(3).join('\n');
    }
    return detailed;
  }

  Color _submissionStatusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard.')),
    );
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
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }

  Widget _noteCard({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    Widget? trailing,
    VoidCallback? onTap,
    bool collapsible = false,
  }) {
    if (collapsible) {
      final summaryText = shortAnswer.trim();
      final detailText = detailedAnswer.trim();
      return AppCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: summaryText.isEmpty
              ? null
              : Text(
                  summaryText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
          trailing: trailing,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            if (detailText.isNotEmpty && detailText != summaryText) ...[
              Text(
                detailText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (summaryText.isNotEmpty) ...[
              Text(
                summaryText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

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
              ...?(trailing == null ? null : [trailing]),
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
      onRefresh: () async {
        await _loadUserNotes();
        await _loadSubmissions();
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ChapterHero(
            subject: widget.subject,
            chapter: widget.chapter,
            title: 'Chapter Notes',
            subtitle: 'AI notes, your notes, and official references.',
            chips: [
              _InfoChip(
                icon: Icons.menu_book_rounded,
                label: '${notes.length} official',
              ),
              _InfoChip(
                icon: Icons.bookmark_rounded,
                label: '${_userNotes.length} my notes',
                color: AppColors.accent,
              ),
              _InfoChip(
                icon: Icons.upload_file_rounded,
                label: '${_submissions.length} submitted',
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Notes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_isGenerating)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: _generateNote,
                      child: Text(_draft == null ? 'Generate' : 'Regenerate'),
                    ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                if (_draft == null)
                  const Text('Generate a quick AI note for this chapter.')
                else ...[
                  _noteCard(
                    title: _draft!.title,
                    shortAnswer: _draft!.shortAnswer,
                    detailedAnswer: _draft!.detailedAnswer,
                    collapsible: true,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _isSaving ? null : _saveDraft,
                        child: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
              ],
            ),
          ),
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
                  collapsible: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        onPressed: () => _showUserNoteDetails(note),
                        icon: const Icon(Icons.open_in_new),
                      ),
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
          SectionHeader(
            title: 'Submit Notes for Approval',
            actionLabel: 'Submit',
            onAction: _openSubmissionSheet,
          ),
          const SizedBox(height: 12),
          if (_submissions.isEmpty)
            const Text('No submissions yet.')
          else
            ..._submissions.map(
              (submission) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              submission.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (submission.status == 'pending')
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteSubmission(submission),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _submissionStatusColor(submission.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              submission.status.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        _submissionStatusColor(submission.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      if (submission.shortAnswer.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          submission.shortAnswer,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if ((submission.fileUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_file,
                              size: 16,
                              color: AppColors.mutedInk,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text('Attachment submitted'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _copyToClipboard(submission.fileUrl!),
                              child: const Text('Copy link'),
                            ),
                          ],
                        ),
                      ],
                      if ((submission.adminFeedback ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Admin feedback:',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submission.adminFeedback!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
                  collapsible: true,
                  trailing: IconButton(
                    tooltip: 'Open',
                    onPressed: () => _showTextNoteDetails(
                      title: note.title,
                      shortAnswer: note.shortAnswer,
                      detailedAnswer: note.detailedAnswer,
                    ),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteSubmissionSheet extends StatefulWidget {
  final Future<String?> Function(
    String title,
    String content,
    List<String> tags,
    String? fileUrl,
  ) onSubmit;
  final Future<String> Function(PlatformFile file)? onUploadAttachment;

  const _NoteSubmissionSheet({
    required this.onSubmit,
    this.onUploadAttachment,
  });

  @override
  State<_NoteSubmissionSheet> createState() => _NoteSubmissionSheetState();
}

class _NoteSubmissionSheetState extends State<_NoteSubmissionSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  PlatformFile? _attachment;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _contentController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required.')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    String? fileUrl;
    if (_attachment != null && widget.onUploadAttachment != null) {
      try {
        fileUrl = await widget.onUploadAttachment!(_attachment!);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment upload failed: $error')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }
    }
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final error = await widget.onSubmit(title, content, tags, fileUrl);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'png',
        'jpg',
        'jpeg',
      ],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final picked = result.files.first;
    if (picked.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read the selected file.')),
      );
      return;
    }
    setState(() {
      _attachment = picked;
    });
  }

  void _clearAttachment() {
    setState(() {
      _attachment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit Note for Approval',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Note content'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _attachment?.name ?? 'No attachment selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_attachment != null)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: _isSubmitting ? null : _clearAttachment,
                    icon: const Icon(Icons.close),
                  ),
                TextButton(
                  onPressed: _isSubmitting ? null : _pickAttachment,
                  child: Text(_attachment == null ? 'Attach file' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    : const Text('Submit for Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final String title;
  final Subject subject;
  final Chapter chapter;
  final List<Question> questions;

  const _QuestionsTab({
    required this.title,
    required this.subject,
    required this.chapter,
    required this.questions,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ChapterHero(
          subject: subject,
          chapter: chapter,
          title: title,
          subtitle: 'Review and revise key questions.',
          chips: [
            _InfoChip(
              icon: Icons.help_outline_rounded,
              label: '${questions.length} questions',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (questions.isEmpty)
          AppCard(
            child: Column(
              children: [
                const Icon(Icons.quiz_outlined,
                    size: 48, color: AppColors.mutedInk),
                const SizedBox(height: 12),
                Text(
                  'No questions yet.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Questions will appear once content is added.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          )
        else
          ...questions.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _QuestionCard(
                    index: entry.key + 1,
                    question: entry.value,
                  ),
                ),
              ),
      ],
    );
  }
}

class _ChapterHero extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final String title;
  final String subtitle;
  final List<Widget> chips;

  const _ChapterHero({
    required this.subject,
    required this.chapter,
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            subject.accentColor.withValues(alpha: 0.16),
            AppColors.secondary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: subject.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_rounded,
                    color: subject.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chapter.title,
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
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolved),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: resolved),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final Question question;

  const _QuestionCard({
    required this.index,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final year = question.year;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '#$index',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.stars_rounded,
                      label: '${question.marks} marks',
                      color: AppColors.accent,
                    ),
                    if (year != null)
                      _InfoChip(
                        icon: Icons.calendar_today_rounded,
                        label: year.toString(),
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
