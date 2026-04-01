import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/note_generated_question_service.dart';
import 'package:student_survivor/data/note_submission_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/games/battle_quiz_screen.dart';
import 'package:student_survivor/features/games/flashcards_screen.dart';
import 'package:student_survivor/features/games/survival_quiz_game_screen.dart';
import 'package:student_survivor/features/quiz/quiz_detail_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
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
        Tab(text: 'Games'),
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
          allowGenerateFromNotes: false,
        ),
        _QuestionsTab(
          title: 'Past Questions',
          subject: subject,
          chapter: chapter,
          questions: chapter.pastQuestions,
        ),
        _GamesTab(
          subject: subject,
          chapter: chapter,
          useGameZoneTheme: useGameZoneTheme,
        ),
      ],
    );

    return DefaultTabController(
      length: 4,
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

class _GamesTab extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final bool useGameZoneTheme;

  const _GamesTab({
    required this.subject,
    required this.chapter,
    required this.useGameZoneTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: 'Play & Practice'),
        const SizedBox(height: 12),
        _GameCard(
          title: 'Study Survivor',
          subtitle: 'Survive waves and answer questions for rewards.',
          icon: Icons.shield,
          actionLabel: 'Play',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SurvivalQuizGameScreen(
                  subject: subject,
                  chapter: chapter,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _GameCard(
          title: 'Battle Quiz (2P)',
          subtitle: 'Challenge others in a live quiz battle.',
          icon: Icons.sports_esports,
          actionLabel: 'Start',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BattleQuizScreen(
                  subject: subject,
                  chapter: chapter,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _GameCard(
          title: 'Flashcards',
          subtitle: 'Quick revision with chapter flashcards.',
          icon: Icons.auto_stories,
          actionLabel: 'Open',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FlashcardsScreen(
                  subject: subject,
                  chapter: chapter,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Chapter Quizzes'),
        const SizedBox(height: 12),
        if (chapter.quizzes.isEmpty)
          Text(
            'No quizzes available for this chapter yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedInk,
            ),
          )
        else
          ...chapter.quizzes.map(
            (quiz) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _QuizCard(
                subject: subject,
                chapter: chapter,
                quiz: quiz,
                useGameZoneTheme: useGameZoneTheme,
              ),
            ),
          ),
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline),
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.paper.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.22),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final Quiz quiz;
  final bool useGameZoneTheme;

  const _QuizCard({
    required this.subject,
    required this.chapter,
    required this.quiz,
    required this.useGameZoneTheme,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuizDetailScreen(
                quiz: quiz,
                subject: subject,
                chapter: chapter,
                useGameZoneTheme: useGameZoneTheme,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: subject.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.quiz, color: subject.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(
                        label: '${quiz.questionCount} Qs',
                        color: AppColors.ink.withValues(alpha: 0.06),
                      ),
                      _MetaChip(
                        label: '${quiz.duration.inMinutes} min',
                        color: AppColors.ink.withValues(alpha: 0.06),
                      ),
                      _MetaChip(
                        label: _difficultyLabel(quiz.difficulty),
                        color: _difficultyColor(quiz.difficulty)
                            .withValues(alpha: 0.16),
                        textColor: _difficultyColor(quiz.difficulty),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }

  String _difficultyLabel(QuizDifficulty difficulty) {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return 'Easy';
      case QuizDifficulty.medium:
        return 'Medium';
      case QuizDifficulty.hard:
        return 'Hard';
    }
  }

  Color _difficultyColor(QuizDifficulty difficulty) {
    switch (difficulty) {
      case QuizDifficulty.easy:
        return AppColors.success;
      case QuizDifficulty.medium:
        return AppColors.warning;
      case QuizDifficulty.hard:
        return AppColors.danger;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;

  const _MetaChip({
    required this.label,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor ?? AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
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
  late final NoteGeneratedQuestionService _noteGeneratedQuestionService;
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
    _noteGeneratedQuestionService =
        NoteGeneratedQuestionService(SupabaseConfig.client);
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

  Future<void> _openAttachment({
    required String title,
    required String url,
    String? contextText,
  }) async {
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment available.')),
      );
      return;
    }
    final extracted = await _NoteQuestionBuilder.extractTextFromFile(url);
    if (!mounted) return;
    if (extracted.trim().isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SyllabusWebViewScreen(
            title: title,
            url: url,
          ),
        ),
      );
      return;
    }
    final mergedContext = [
      contextText ?? '',
      extracted,
    ].where((value) => value.trim().isNotEmpty).join('\n');
    final highlight = _buildHighlightSets(mergedContext);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.98,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SyllabusWebViewScreen(
                              title: title,
                              url: url,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open original'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => _copyToClipboard(url),
                      child: const Text('Copy link'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Read & tap for meanings',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: _buildTappableText(
                    extracted,
                    contextText: mergedContext,
                    mainWords: highlight.mainWords,
                    difficultWords: highlight.difficultWords,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            );
          },
        );
      },
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
    String? fileUrl,
    String? noteId,
    String? chapterId,
  }) {
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
            var isGenerating = false;
            String? generateError;
            return StatefulBuilder(
              builder: (context, setModalState) {
                final contextText = _buildNoteContext(
                  title: title,
                  shortAnswer: shortAnswer,
                  detailedAnswer: detailedAnswer,
                );
                final highlight = _buildHighlightSets(contextText);

                Future<void> handleGenerate() async {
                  if (isGenerating) return;
                  setModalState(() {
                    isGenerating = true;
                    generateError = null;
                  });
                  final generated = await _generateQuestionFromNote(
                    title: title,
                    shortAnswer: shortAnswer,
                    detailedAnswer: detailedAnswer,
                    fileUrl: fileUrl,
                  );
                  if (!mounted) return;
                  if (generated == null ||
                      generated.question.trim().isEmpty) {
                    setModalState(() {
                      generateError =
                          'Unable to generate a question from this file.';
                      isGenerating = false;
                    });
                    return;
                  }
                  setModalState(() {
                    isGenerating = false;
                  });
                  if (!context.mounted) return;
                  String? answer;
                  String? generatedId;
                  var isAnswerLoading = false;
                  final pointCount =
                      _countQuestionPoints(generated.question);
                  if (noteId != null && chapterId != null) {
                    generatedId =
                        await _noteGeneratedQuestionService.create(
                      noteId: noteId!,
                      chapterId: chapterId!,
                      question: generated.question,
                    );
                  }
                  await showDialog<void>(
                    context: context,
                    builder: (context) {
                      return StatefulBuilder(
                        builder: (context, setAnswerState) {
                          Future<void> generateAnswer() async {
                            if (isAnswerLoading) return;
                            setAnswerState(() {
                              isAnswerLoading = true;
                            });
                            try {
                              answer =
                                  await _aiNotesService.generateAnswerFromNotes(
                                question: generated.question,
                                content: generated.content,
                                points: pointCount,
                              );
                            } catch (_) {
                              answer = _fallbackAnswerFromContent(
                                generated.content,
                                pointCount,
                              );
                            }
                            if (generatedId != null &&
                                answer != null &&
                                answer!.trim().isNotEmpty) {
                              await _noteGeneratedQuestionService.updateAnswer(
                                id: generatedId!,
                                answer: answer!.trim(),
                              );
                            }
                            if (!context.mounted) return;
                            setAnswerState(() {
                              isAnswerLoading = false;
                            });
                          }

                          return AlertDialog(
                            title: const Text('Generated Question'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(generated.question),
                                  const SizedBox(height: 12),
                                  if (answer != null && answer!.isNotEmpty) ...[
                                    Text(
                                      'Sample Answer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(answer!),
                                  ],
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    isAnswerLoading ? null : generateAnswer,
                                child: isAnswerLoading
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Generate Answer'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                }

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
                    if ((fileUrl ?? '').isNotEmpty) ...[
                      AppCard(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.attach_file_rounded),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Attachment available',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                TextButton(
                          onPressed: () => _openAttachment(
                            title: title,
                            url: fileUrl!,
                            contextText: contextText,
                          ),
                                  child: const Text('Open'),
                                ),
                                TextButton(
                                  onPressed: () => _copyToClipboard(fileUrl!),
                                  child: const Text('Copy link'),
                                ),
                                TextButton(
                                  onPressed: isGenerating
                                      ? null
                                      : handleGenerate,
                                  child: isGenerating
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Generate Q'),
                                ),
                              ],
                            ),
                            if (generateError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                generateError!,
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
                    ],
                    if (detailedAnswer.isNotEmpty ||
                        shortAnswer.isNotEmpty) ...[
                      Text(
                        'Notes',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detailedAnswer.isNotEmpty
                            ? detailedAnswer
                            : shortAnswer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else if ((fileUrl ?? '').isEmpty) ...[
                      Text(
                        'No note content available yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<_GeneratedQuestion?> _generateQuestionFromNote({
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    String? fileUrl,
    String? noteId,
    String? chapterId,
  }) async {
    var contentParts = <String>[];
    if ((fileUrl ?? '').isNotEmpty) {
      final fileText =
          await _NoteQuestionBuilder.extractTextFromFile(fileUrl!);
      if (fileText.trim().isNotEmpty) {
        contentParts.add(fileText.trim());
      }
    }
    if (detailedAnswer.trim().isNotEmpty) {
      contentParts.add(detailedAnswer.trim());
    } else if (shortAnswer.trim().isNotEmpty) {
      contentParts.add(shortAnswer.trim());
    }
    if (contentParts.isEmpty) return null;
    final content = contentParts.join(' ');
    final prompt = _NoteQuestionBuilder.buildPromptFromContent(
      content,
      fallbackTitle: title,
    );
    if (prompt.trim().isEmpty) {
      return _GeneratedQuestion(
        question:
            'Explain: ${title.trim().isEmpty ? 'the topic' : title.trim()}',
        content: content,
      );
    }
    return _GeneratedQuestion(question: prompt, content: content);
  }

  String _fallbackAnswerFromContent(String content, int points) {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    final selected =
        _NoteQuestionBuilder._extractKeyPoints(cleaned, '').take(points).toList();
    if (selected.isEmpty) {
      return _NoteQuestionBuilder._trimText(cleaned, 400);
    }
    final buffer = StringBuffer();
    for (var i = 0; i < selected.length; i += 1) {
      buffer.writeln('${i + 1}. ${selected[i]}');
    }
    return buffer.toString().trim();
  }

  int _countQuestionPoints(String question) {
    final lines = question.split('\n');
    final count = lines
        .where((line) => RegExp(r'^\s*\d+\.\s+').hasMatch(line))
        .length;
    return count == 0 ? 5 : count;
  }

  void _showUserNoteDetails(UserNote note) {
    _showTextNoteDetails(
      title: note.title,
      shortAnswer: note.shortAnswer,
      detailedAnswer: note.detailedAnswer,
      fileUrl: null,
      noteId: null,
      chapterId: note.chapterId,
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

  Widget _noteBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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
  }) {
    if (collapsible) {
      final summaryText =
          detailedAnswer.trim().isNotEmpty ? detailedAnswer.trim() : shortAnswer.trim();
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
                      label: 'Attachment',
                      color: AppColors.warning,
                      icon: Icons.attach_file_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
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

    final previewText = detailedAnswer.trim().isNotEmpty
        ? detailedAnswer.trim()
        : shortAnswer.trim();
    final card = AppCard(
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
                    label: 'Attachment',
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
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ...?(trailing == null ? null : [trailing]),
            ],
          ),
          const SizedBox(height: 8),
          if (previewText.isNotEmpty)
            Text(
              previewText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          if (previewText.isNotEmpty) const SizedBox(height: 12),
          if (showTapHint && onTap != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppColors.mutedInk,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to open full note',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.mutedInk),
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
                    badgeLabel: 'AI Draft',
                    badgeColor: AppColors.secondary,
                    badgeIcon: Icons.auto_awesome_rounded,
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
                  onTap: () => _showUserNoteDetails(note),
                  showTapHint: true,
                  badgeLabel: 'My Note',
                  badgeColor: AppColors.accent,
                  badgeIcon: Icons.bookmark_rounded,
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
                  onTap: () => _showTextNoteDetails(
                    title: note.title,
                    shortAnswer: note.shortAnswer,
                    detailedAnswer: note.detailedAnswer,
                    fileUrl: note.fileUrl,
                    noteId: note.id,
                    chapterId: widget.chapter.id,
                  ),
                  showTapHint: true,
                  badgeLabel: 'Official',
                  badgeColor: AppColors.secondary,
                  badgeIcon: Icons.verified_rounded,
                  showAttachmentBadge: (note.fileUrl ?? '').isNotEmpty,
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_new,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Open',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.secondary,
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

class _QuestionsTab extends StatefulWidget {
  final String title;
  final Subject subject;
  final Chapter chapter;
  final List<Question> questions;
  final bool allowGenerateFromNotes;

  const _QuestionsTab({
    required this.title,
    required this.subject,
    required this.chapter,
    required this.questions,
    this.allowGenerateFromNotes = false,
  });

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  bool _isGenerating = false;
  String? _generateError;
  final List<Question> _generated = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generateFromNotes() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _generateError = null;
    });
    try {
      final officialNotes = await _fetchOfficialNotes();
      if (!mounted) return;
      if (officialNotes.isEmpty) {
        setState(() {
          _generateError = 'No official notes found for this chapter yet.';
        });
        return;
      }
      final note = officialNotes[_random.nextInt(officialNotes.length)];
      final content = await _noteContentForPrompt(note);
      if (!mounted) return;
      if (content.trim().isEmpty) {
        setState(() {
          _generateError =
              'Could not read the note file. Try another note or add text.';
        });
        return;
      }
      final generated = Question(
        id: 'note_q_${note.id}_${DateTime.now().millisecondsSinceEpoch}',
        prompt: _buildPromptFromContent(content, fallbackTitle: note.title),
        marks: 5,
        kind: 'important',
      );
      setState(() {
        _generated.insert(0, generated);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _generateError = 'Failed to generate: $error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<List<Note>> _fetchOfficialNotes() async {
    try {
      final rows = await SupabaseConfig.client
          .from('notes')
          .select('id,title,short_answer,detailed_answer,file_url')
          .eq('chapter_id', widget.chapter.id)
          .order('created_at', ascending: false)
          .limit(6);
      return (rows as List<dynamic>)
          .map(
            (row) => Note(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              shortAnswer: row['short_answer']?.toString() ?? '',
              detailedAnswer: row['detailed_answer']?.toString() ?? '',
              fileUrl: row['file_url']?.toString(),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _buildPromptFromNote(Note note) {
    final title = note.title.trim();
    if (title.isEmpty) {
      return 'Explain the key concept from the official notes.';
    }
    final lower = title.toLowerCase();
    const starters = [
      'define',
      'explain',
      'describe',
      'discuss',
      'what',
      'why',
      'how',
      'list',
      'outline',
      'compare',
      'differentiate',
      'state',
    ];
    if (starters.any((starter) => lower.startsWith(starter))) {
      return title.endsWith('?') ? title : '$title?';
    }
    return 'Explain: $title';
  }

  Future<String> _noteContentForPrompt(Note note) async {
    final parts = <String>[];
    final url = note.fileUrl ?? '';
    if (url.isNotEmpty) {
      final fileText = await _extractTextFromFile(url);
      if (fileText.trim().isNotEmpty) {
        parts.add(fileText.trim());
      }
    }
    final detailed = note.detailedAnswer.trim();
    if (detailed.isNotEmpty) {
      parts.add(detailed);
    } else {
      final short = note.shortAnswer.trim();
      if (short.isNotEmpty) {
        parts.add(short);
      }
    }
    return parts.join(' ');
  }

  Future<String> _extractTextFromFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }
      final bytes = response.bodyBytes;
      final contentType = response.headers['content-type'] ?? '';
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.endsWith('.pdf') || contentType.contains('pdf')) {
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      }
      if (lowerUrl.endsWith('.pptx') ||
          contentType.contains('presentationml')) {
        return _extractTextFromPptx(bytes);
      }
      if (lowerUrl.endsWith('.docx') ||
          contentType.contains('wordprocessingml')) {
        return _extractTextFromDocx(bytes);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  String _buildPromptFromContent(
    String content, {
    required String fallbackTitle,
  }) {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    final sentence = _pickContentSnippet(cleaned, fallbackTitle);
    if (sentence.isEmpty) {
      return 'Explain: ${_trimText(cleaned, 180)}';
    }
    if (sentence.endsWith('?')) {
      return sentence;
    }
    final lower = sentence.toLowerCase();
    const starters = [
      'define',
      'explain',
      'describe',
      'discuss',
      'what',
      'why',
      'how',
      'list',
      'outline',
      'compare',
      'differentiate',
      'state',
    ];
    if (starters.any((starter) => lower.startsWith(starter))) {
      return '$sentence?';
    }
    return 'Explain: $sentence';
  }

  String _trimText(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  String _firstSentence(String text, int maxLen) {
    final trimmed = _trimText(text, maxLen);
    final match = RegExp(r'^(.+?[.!?])(\s|$)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return trimmed;
  }

  String _pickContentSnippet(String text, String title) {
    final normalizedTitle = title.trim().toLowerCase();
    final candidates = text.split(RegExp(r'(?<=[.!?])\s+'));
    for (final raw in candidates) {
      final sentence = raw.trim();
      if (sentence.length < 24) continue;
      if (normalizedTitle.isNotEmpty &&
          sentence.toLowerCase().contains(normalizedTitle)) {
        continue;
      }
      return _trimText(sentence, 180);
    }
    return _trimText(text, 180);
  }

  String _extractTextFromPptx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final buffer = StringBuffer();
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;
        if (!name.startsWith('ppt/slides/slide') || !name.endsWith('.xml')) {
          continue;
        }
        final content = utf8.decode(file.content as List<int>,
            allowMalformed: true);
        final doc = XmlDocument.parse(content);
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  String _extractTextFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.firstWhere(
        (file) => file.isFile && file.name == 'word/document.xml',
        orElse: () => ArchiveFile.noCompress('', 0, []),
      );
      if (documentFile.isFile && documentFile.size > 0) {
        final content = utf8.decode(documentFile.content as List<int>,
            allowMalformed: true);
        final doc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
        return buffer.toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allQuestions = [..._generated, ...widget.questions];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ChapterHero(
          subject: widget.subject,
          chapter: widget.chapter,
          title: widget.title,
          subtitle: 'Review and revise key questions.',
          chips: [
            _InfoChip(
              icon: Icons.help_outline_rounded,
              label: '${allQuestions.length} questions',
            ),
          ],
        ),
        if (widget.allowGenerateFromNotes) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate from official notes',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create a new important question based on chapter notes.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _isGenerating ? null : _generateFromNotes,
                  child: _isGenerating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Generate Question'),
                ),
                if (_generateError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _generateError!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (allQuestions.isEmpty)
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
          ...allQuestions.asMap().entries.map(
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

class _GeneratedQuestion {
  final String question;
  final String content;

  const _GeneratedQuestion({
    required this.question,
    required this.content,
  });
}

class _NoteQuestionBuilder {
  static Future<String> extractTextFromFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return '';
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }
      final bytes = response.bodyBytes;
      final contentType = response.headers['content-type'] ?? '';
      final lowerUrl = url.toLowerCase();
      if (lowerUrl.endsWith('.pdf') || contentType.contains('pdf')) {
        final document = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(document).extractText();
        document.dispose();
        return text;
      }
      if (lowerUrl.endsWith('.pptx') ||
          contentType.contains('presentationml')) {
        return _extractTextFromPptx(bytes);
      }
      if (lowerUrl.endsWith('.docx') ||
          contentType.contains('wordprocessingml')) {
        return _extractTextFromDocx(bytes);
      }
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  static String buildPromptFromContent(
    String content, {
    required String fallbackTitle,
  }) {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    final points = _extractKeyPoints(cleaned, fallbackTitle);
    if (points.isEmpty) {
      final snippet = _pickContentSnippet(cleaned, fallbackTitle);
      if (snippet.isEmpty) return '';
      if (snippet.endsWith('?')) return snippet;
      return 'Explain: $snippet';
    }
    final marksPerPoint = points.length <= 3 ? 5 : 2;
    final totalMarks = marksPerPoint * points.length;
    final per = marksPerPoint;
    var remainder = 0;
    final buffer = StringBuffer();
    buffer.writeln(
        'Attempt all. Answer the following point-wise (Total: $totalMarks marks):');
    for (var i = 0; i < points.length; i += 1) {
      final marks = per + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder -= 1;
      buffer.writeln('${i + 1}. Explain: ${points[i]} ($marks marks)');
    }
    return buffer.toString().trim();
  }

  static String _trimText(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  static String _firstSentence(String text, int maxLen) {
    final trimmed = _trimText(text, maxLen);
    final match = RegExp(r'^(.+?[.!?])(\s|$)').firstMatch(trimmed);
    if (match != null) {
      return match.group(1)!.trim();
    }
    return trimmed;
  }

  static String _pickContentSnippet(String text, String title) {
    final normalizedTitle = title.trim().toLowerCase();
    final chunks = text
        .split(RegExp(r'[\n\r•\-–]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final filtered = chunks.where((line) {
      if (normalizedTitle.isEmpty) return true;
      final lower = line.toLowerCase();
      if (lower == normalizedTitle) return false;
      if (lower.contains(normalizedTitle) && lower.length <= normalizedTitle.length + 8) {
        return false;
      }
      return true;
    }).toList();
    final joined = (filtered.isNotEmpty ? filtered : chunks).join(' ');
    if (joined.isNotEmpty) {
      return _trimText(joined, 180);
    }
    return _trimText(text, 180);
  }

  static List<String> _extractKeyPoints(String text, String title) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalized = text
        .replaceAll(RegExp(r'[•·]'), '\n')
        .replaceAll(RegExp(r'\s*\-\s+'), '\n')
        .replaceAll(RegExp(r'\s*\*\s+'), '\n')
        .replaceAll(RegExp(r'\s*\d+[\.\)]\s+'), '\n');
    final lines = normalized
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final points = <String>[];
    for (final line in lines) {
      if (line.length < 20) continue;
      final lower = line.toLowerCase();
      if (normalizedTitle.isNotEmpty) {
        if (lower == normalizedTitle) continue;
        if (lower.contains(normalizedTitle) &&
            lower.length <= normalizedTitle.length + 8) {
          continue;
        }
      }
      final cleaned = _trimText(line, 140);
      if (!points.contains(cleaned)) {
        points.add(cleaned);
      }
      if (points.length >= 10) break;
    }
    if (points.length >= 3) return points;

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    for (final raw in sentences) {
      final sentence = raw.trim();
      if (sentence.length < 24) continue;
      final lower = sentence.toLowerCase();
      if (normalizedTitle.isNotEmpty &&
          lower.contains(normalizedTitle) &&
          sentence.length <= normalizedTitle.length + 10) {
        continue;
      }
      final cleaned = _trimText(sentence, 140);
      if (!points.contains(cleaned)) {
        points.add(cleaned);
      }
      if (points.length >= 10) break;
    }
    return points;
  }

  static String _extractTextFromPptx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final buffer = StringBuffer();
      for (final file in archive) {
        if (!file.isFile) continue;
        final name = file.name;
        if (!name.startsWith('ppt/slides/slide') || !name.endsWith('.xml')) {
          continue;
        }
        final content =
            utf8.decode(file.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(content);
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static String _extractTextFromDocx(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.firstWhere(
        (file) => file.isFile && file.name == 'word/document.xml',
        orElse: () => ArchiveFile.noCompress('', 0, []),
      );
      if (documentFile.isFile && documentFile.size > 0) {
        final content =
            utf8.decode(documentFile.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(content);
        final buffer = StringBuffer();
        for (final node in doc.descendants.whereType<XmlElement>()) {
          if (node.name.local != 't') continue;
          final text = node.innerText.trim();
          if (text.isNotEmpty) {
            buffer.writeln(text);
          }
        }
        return buffer.toString();
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}
