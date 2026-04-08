import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/note_generated_question_service.dart';
import 'package:student_survivor/data/note_submission_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/models/app_models.dart';

class ChapterDetailScreen extends StatefulWidget {
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
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  bool _showTitle = true;
  bool _showTabs = true;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final shouldShow = notification.metrics.pixels < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
    return false;
  }

  void _updateTitleVisibility(bool shouldShow) {
    if (shouldShow == _showTitle && shouldShow == _showTabs) {
      return;
    }
    setState(() {
      _showTitle = shouldShow;
      _showTabs = shouldShow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGamingTheme = !widget.useGameZoneTheme;
    final tabBar = TabBar(
      isScrollable: true,
      labelColor: isGamingTheme
          ? Colors.white
          : widget.useGameZoneTheme
              ? AppColors.ink
              : null,
      unselectedLabelColor: isGamingTheme
          ? Colors.white70
          : widget.useGameZoneTheme
              ? AppColors.mutedInk
              : null,
      indicatorColor: isGamingTheme
          ? const Color(0xFF38BDF8)
          : widget.useGameZoneTheme
              ? AppColors.secondary
              : null,
      tabs: [
        Tab(text: context.tr('Notes', 'नोट्स')),
        Tab(text: context.tr('Important', 'महत्वपूर्ण')),
        Tab(text: context.tr('Past Qs', 'विगत प्रश्न')),
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
          widget.chapter.title,
          style: isGamingTheme
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )
              : null,
        ),
      ),
      backgroundColor: isGamingTheme
          ? Colors.transparent
          : widget.useGameZoneTheme
              ? AppColors.paper
              : null,
      foregroundColor: isGamingTheme
          ? Colors.white
          : widget.useGameZoneTheme
              ? AppColors.ink
              : null,
      iconTheme: IconThemeData(
        color: isGamingTheme
            ? Colors.white
            : (widget.useGameZoneTheme ? AppColors.secondary : null),
      ),
      elevation: isGamingTheme ? 0 : (widget.useGameZoneTheme ? 0 : null),
      scrolledUnderElevation:
          isGamingTheme ? 0 : (widget.useGameZoneTheme ? 0 : null),
      surfaceTintColor: Colors.transparent,
      bottom: tabBarWidget,
    );

    final body = NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: TabBarView(
        children: [
          _NotesTab(
            subject: widget.subject,
            chapter: widget.chapter,
            openSubmitSheet: widget.openSubmitSheet,
            useGameTheme: isGamingTheme,
            onTitleVisibilityChanged: _updateTitleVisibility,
          ),
          _QuestionsTab(
            title: context.tr('Important Questions', 'महत्वपूर्ण प्रश्नहरू'),
            subject: widget.subject,
            chapter: widget.chapter,
            questions: widget.chapter.importantQuestions,
            allowGenerateFromNotes: false,
            useGameTheme: isGamingTheme,
            onTitleVisibilityChanged: _updateTitleVisibility,
          ),
          _QuestionsTab(
            title: context.tr('Past Questions', 'विगत प्रश्नहरू'),
            subject: widget.subject,
            chapter: widget.chapter,
            questions: widget.chapter.pastQuestions,
            useGameTheme: isGamingTheme,
            onTitleVisibilityChanged: _updateTitleVisibility,
          ),
        ],
      ),
    );

    return DefaultTabController(
      length: 3,
      child: widget.useGameZoneTheme
          ? GameZoneScaffold(
              appBar: appBar,
              body: body,
              useSafeArea: false,
            )
          : Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: const Color(0xFF070B14),
              appBar: appBar,
              body: Stack(
                children: [
                  const Positioned.fill(child: _ChapterBackdrop()),
                  body,
                ],
              ),
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

class _NotesTab extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;
  final bool openSubmitSheet;
  final bool useGameTheme;
  final ValueChanged<bool>? onTitleVisibilityChanged;

  const _NotesTab({
    required this.subject,
    required this.chapter,
    this.openSubmitSheet = false,
    this.useGameTheme = false,
    this.onTitleVisibilityChanged,
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

  bool get _useGameTheme => widget.useGameTheme;
  Color get _mutedTextColor =>
      _useGameTheme ? Colors.white70 : AppColors.mutedInk;

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? color,
  }) {
    if (_useGameTheme) {
      return _GameCard(
        padding: padding,
        child: child,
      );
    }
    return AppCard(
      padding: padding,
      color: color,
      child: child,
    );
  }

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
      backgroundColor: _useGameTheme ? AppColors.paper : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview not available for this file.')),
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
      backgroundColor:
          _useGameTheme ? const Color(0xFF0B1220) : AppColors.surface,
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
                    color: _useGameTheme
                        ? Colors.white24
                        : AppColors.outline,
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
                        color: _useGameTheme ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _copyToClipboard(url),
                  style: _useGameTheme
                      ? OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        )
                      : null,
                  child: const Text('Copy link'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Read & tap for meanings',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _useGameTheme ? Colors.white : null,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _useGameTheme
                        ? const Color(0xFF10192E)
                        : AppColors.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useGameTheme
                          ? const Color(0xFF1E2A44)
                          : AppColors.outline,
                    ),
                  ),
                  child: _buildTappableText(
                    extracted,
                    contextText: mergedContext,
                    mainWords: highlight.mainWords,
                    difficultWords: highlight.difficultWords,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _useGameTheme ? Colors.white70 : null,
                        ),
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
      backgroundColor:
          _useGameTheme ? const Color(0xFF0B1220) : AppColors.surface,
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
                  String? answer;
                  String? generatedId;
                  var isAnswerLoading = false;
                  final pointCount =
                      _countQuestionPoints(generated.question);
                  final safeNoteId = noteId;
                  final safeChapterId = chapterId;
                  if (safeNoteId != null && safeChapterId != null) {
                    generatedId =
                        await _noteGeneratedQuestionService.create(
                      noteId: safeNoteId,
                      chapterId: safeChapterId,
                      question: generated.question,
                    );
                  }
                  if (!context.mounted) return;
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
                            final safeGeneratedId = generatedId;
                            final safeAnswer = answer;
                            if (safeGeneratedId != null &&
                                safeAnswer != null &&
                                safeAnswer.trim().isNotEmpty) {
                              await _noteGeneratedQuestionService.updateAnswer(
                                id: safeGeneratedId,
                                answer: safeAnswer.trim(),
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
                        color: _useGameTheme
                            ? Colors.white24
                            : AppColors.outline,
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
                            color: _useGameTheme ? Colors.white : null,
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
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 180,
                                alignment: Alignment.center,
                                color: _useGameTheme
                                    ? const Color(0xFF0B1220)
                                    : AppColors.surface,
                                child: const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 180,
                              alignment: Alignment.center,
                              color: _useGameTheme
                                  ? const Color(0xFF0B1220)
                                  : AppColors.surface,
                              child: Text(
                                'Image unavailable',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _useGameTheme
                                          ? Colors.white70
                                          : null,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildCard(
                        color: AppColors.secondary.withValues(alpha: 0.06),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.attach_file_rounded,
                                  color:
                                      _useGameTheme ? Colors.white : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Attachment available',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: _useGameTheme
                                              ? Colors.white
                                              : null,
                                        ),
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
                                    url: safeUrl,
                                    contextText: _buildNoteContext(
                                      title: title,
                                      shortAnswer: shortAnswer,
                                      detailedAnswer: detailedAnswer,
                                    ),
                                  ),
                                  child: const Text('Open'),
                                ),
                                TextButton(
                                  onPressed: () => _copyToClipboard(safeUrl),
                                  child: const Text('Copy link'),
                                ),
                                TextButton(
                                  onPressed: isGenerating
                                      ? null
                                      : handleGenerate,
                                  style: _useGameTheme
                                      ? TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        )
                                      : null,
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
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _useGameTheme ? Colors.white : null,
                            ),
                      ),
                      const SizedBox(height: 8),
                      MathText(
                        text: detailedAnswer.isNotEmpty
                            ? detailedAnswer
                            : shortAnswer,
                        textStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: _useGameTheme ? Colors.white70 : null,
                            ),
                      ),
                    ] else if ((fileUrl ?? '').isEmpty) ...[
                      Text(
                        'No note content available yet.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: _mutedTextColor),
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
          widgets.add(Wrap(children: lineWidgets));
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
      return _buildCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _useGameTheme ? Colors.white : null,
                ),
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
                      ?.copyWith(color: _mutedTextColor),
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
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: _useGameTheme ? Colors.white70 : null,
                    ),
              ),
            ] else if (summaryText.isNotEmpty) ...[
              Text(
                summaryText,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: _useGameTheme ? Colors.white70 : null,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    final previewText = detailedAnswer.trim().isNotEmpty
        ? detailedAnswer.trim()
        : shortAnswer.trim();
    final card = _buildCard(
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
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _useGameTheme ? Colors.white : null,
                      ),
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
                  ?.copyWith(color: _mutedTextColor),
            ),
          if (previewText.isNotEmpty) const SizedBox(height: 12),
          if (showTapHint && onTap != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: _mutedTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tap to open full note',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: _mutedTextColor),
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

  Widget _buildSectionHeader({
    required String title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!_useGameTheme) {
      return SectionHeader(
        title: title,
        actionLabel: actionLabel,
        onAction: onAction,
      );
    }
    return _GameSectionHeader(
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.chapter.notes;
    final topInset = _useGameTheme
        ? max(
            0.0,
            MediaQuery.of(context).padding.top +
                kToolbarHeight +
                kTextTabBarHeight -
                96,
          )
        : 20.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        final shouldShow = notification.metrics.pixels < 24;
        widget.onTitleVisibilityChanged?.call(shouldShow);
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadUserNotes();
          await _loadSubmissions();
        },
        child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          topInset,
          20,
          24,
        ),
        children: [
          _ChapterHero(
            subject: widget.subject,
            chapter: widget.chapter,
            title: 'Chapter Notes',
            subtitle: 'AI notes, your notes, and official references.',
            useGameTheme: _useGameTheme,
            chips: [
              _InfoChip(
                icon: Icons.menu_book_rounded,
                label: '${notes.length} official',
                useGameTheme: _useGameTheme,
              ),
              _InfoChip(
                icon: Icons.bookmark_rounded,
                label: '${_userNotes.length} my notes',
                color: AppColors.accent,
                useGameTheme: _useGameTheme,
              ),
              _InfoChip(
                icon: Icons.upload_file_rounded,
                label: '${_submissions.length} submitted',
                color: AppColors.warning,
                useGameTheme: _useGameTheme,
              ),
            ],
          ),
          if (widget.chapter.subtopics.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtopics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _useGameTheme ? Colors.white : null,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...(() {
                    final items = [...widget.chapter.subtopics]
                      ..sort(
                        (a, b) => a.sortOrder.compareTo(b.sortOrder),
                      );
                    return items.map(
                      (topic) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubtopicTile(
                          topic: topic,
                          useGameTheme: _useGameTheme,
                        ),
                      ),
                    );
                  })(),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _useGameTheme
                          ? const Color(0xFF111B2E)
                          : AppColors.secondary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Notes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _useGameTheme ? Colors.white : null,
                          ),
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
                      style: _useGameTheme
                          ? FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF162033),
                              foregroundColor: Colors.white,
                            )
                          : null,
                      child: Text(_draft == null ? 'Generate' : 'Regenerate'),
                    ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                if (_draft == null)
                  Text(
                    'Generate a quick AI note for this chapter.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _useGameTheme ? Colors.white70 : null,
                        ),
                  )
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
                        style: _useGameTheme
                            ? FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: Colors.white,
                              )
                            : null,
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
                        style: _useGameTheme
                            ? TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              )
                            : null,
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
          _buildSectionHeader(
            title: 'My Notes',
            actionLabel: _isLoading ? null : 'Refresh',
            onAction: _isLoading ? null : _loadUserNotes,
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_userNotes.isEmpty)
            Text(
              'No saved notes yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedTextColor),
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
                  badgeLabel: 'My Note',
                  badgeColor: AppColors.accent,
                  badgeIcon: Icons.bookmark_rounded,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        onPressed: () => _showUserNoteDetails(note),
                        icon: Icon(
                          Icons.open_in_new,
                          color: _useGameTheme ? Colors.white : null,
                        ),
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
                            : Icon(
                                Icons.delete_outline,
                                color: _useGameTheme ? Colors.white70 : null,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'Submit Notes for Approval',
            actionLabel: 'Submit',
            onAction: _openSubmissionSheet,
          ),
          const SizedBox(height: 12),
          if (_submissions.isEmpty)
            Text(
              'No submissions yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedTextColor),
            )
          else
            ..._submissions.map(
              (submission) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCard(
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
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: _useGameTheme ? Colors.white : null,
                                  ),
                            ),
                          ),
                          if (submission.status == 'pending')
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _deleteSubmission(submission),
                              icon: Icon(
                                Icons.delete_outline,
                                color: _useGameTheme ? Colors.white70 : null,
                              ),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    _useGameTheme ? Colors.white70 : null,
                              ),
                        ),
                      ],
                      if ((submission.fileUrl ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 16,
                              color: _mutedTextColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Attachment submitted',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _mutedTextColor,
                                    ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _copyToClipboard(submission.fileUrl!),
                              style: _useGameTheme
                                  ? TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    )
                                  : null,
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
                              ?.copyWith(color: _mutedTextColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submission.adminFeedback!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    _useGameTheme ? Colors.white70 : null,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          _buildSectionHeader(title: 'Official Notes'),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            Text(
              'No official notes yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _mutedTextColor),
            )
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
                      color: _useGameTheme
                          ? const Color(0xFF111B2E)
                          : AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: _useGameTheme
                              ? const Color(0xFF38BDF8)
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Open',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _useGameTheme
                                        ? const Color(0xFF38BDF8)
                                        : AppColors.secondary,
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
  final bool useGameTheme;
  final ValueChanged<bool>? onTitleVisibilityChanged;

  const _QuestionsTab({
    required this.title,
    required this.subject,
    required this.chapter,
    required this.questions,
    this.allowGenerateFromNotes = false,
    this.useGameTheme = false,
    this.onTitleVisibilityChanged,
  });

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  bool _isGenerating = false;
  String? _generateError;
  final List<Question> _generated = [];
  final Random _random = Random();

  bool get _useGameTheme => widget.useGameTheme;
  Color get _mutedTextColor =>
      _useGameTheme ? Colors.white70 : AppColors.mutedInk;

  Widget _buildCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    Color? color,
  }) {
    if (_useGameTheme) {
      return _GameCard(
        padding: padding,
        child: child,
      );
    }
    return AppCard(
      padding: padding,
      color: color,
      child: child,
    );
  }

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
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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
    final topInset = _useGameTheme
        ? max(
            0.0,
            MediaQuery.of(context).padding.top +
                kToolbarHeight +
                kTextTabBarHeight -
                96,
          )
        : 20.0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        final shouldShow = notification.metrics.pixels < 24;
        widget.onTitleVisibilityChanged?.call(shouldShow);
        return false;
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          topInset,
          20,
          24,
        ),
        children: [
          _ChapterHero(
            subject: widget.subject,
            chapter: widget.chapter,
            title: widget.title,
            subtitle: 'Review and revise key questions.',
            useGameTheme: _useGameTheme,
            chips: [
              _InfoChip(
                icon: Icons.help_outline_rounded,
                label: '${allQuestions.length} questions',
                useGameTheme: _useGameTheme,
              ),
            ],
          ),
          if (widget.allowGenerateFromNotes) ...[
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate from official notes',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _useGameTheme ? Colors.white : null,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a new important question based on chapter notes.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedTextColor),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _isGenerating ? null : _generateFromNotes,
                    style: _useGameTheme
                        ? FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF162033),
                            foregroundColor: Colors.white,
                          )
                        : null,
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
            _buildCard(
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined,
                      size: 48, color: _mutedTextColor),
                  const SizedBox(height: 12),
                  Text(
                    'No questions yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _useGameTheme ? Colors.white : null,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Questions will appear once content is added.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: _mutedTextColor),
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
                      useGameTheme: _useGameTheme,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ChapterHero extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;
  final String title;
  final String subtitle;
  final List<Widget> chips;
  final bool useGameTheme;

  const _ChapterHero({
    required this.subject,
    required this.chapter,
    required this.title,
    required this.subtitle,
    required this.chips,
    this.useGameTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = subject.accentColor;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: useGameTheme
            ? LinearGradient(
                colors: [
                  const Color(0xFF0B1220),
                  accent.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.16),
                  AppColors.secondary.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: useGameTheme ? const Color(0xFF1E2A44) : AppColors.outline,
        ),
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
                  color: useGameTheme
                      ? const Color(0xFF111B2E)
                      : accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.menu_book_rounded, color: accent),
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
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: useGameTheme ? Colors.white : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chapter.title,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: useGameTheme
                                ? Colors.white70
                                : AppColors.mutedInk,
                          ),
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
                ?.copyWith(
                  color: useGameTheme ? Colors.white70 : AppColors.mutedInk,
                ),
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
  final bool useGameTheme;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
    this.useGameTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: useGameTheme
            ? resolved.withValues(alpha: 0.18)
            : resolved.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: useGameTheme
            ? Border.all(color: const Color(0xFF1E2A44))
            : null,
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

class _SubtopicTile extends StatelessWidget {
  final ChapterTopic topic;
  final bool useGameTheme;

  const _SubtopicTile({
    required this.topic,
    this.useGameTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: useGameTheme
                ? const Color(0xFF111B2E)
                : AppColors.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.label_rounded,
              size: 16, color: AppColors.secondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: useGameTheme ? Colors.white : null,
                    ),
              ),
              if (topic.summary.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  topic.summary,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            useGameTheme ? Colors.white70 : AppColors.mutedInk,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final Question question;
  final bool useGameTheme;

  const _QuestionCard({
    required this.index,
    required this.question,
    this.useGameTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    final year = question.year;
    final card = useGameTheme
        ? _GameCard(child: _buildContent(context, year))
        : AppCard(child: _buildContent(context, year));
    return card;
  }

  Widget _buildContent(BuildContext context, int? year) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: useGameTheme
                ? const Color(0xFF111B2E)
                : AppColors.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '#$index',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(
                    color: useGameTheme
                        ? const Color(0xFF38BDF8)
                        : AppColors.secondary,
                  ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                      color: useGameTheme ? Colors.white : null,
                    ),
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
                    useGameTheme: useGameTheme,
                  ),
                  if (year != null)
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      label: year.toString(),
                      color: AppColors.warning,
                      useGameTheme: useGameTheme,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _GameSectionHeader({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
            ),
            child: Text(actionLabel!.toUpperCase()),
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
            Color(0xFF38BDF8),
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

class _ChapterBackdrop extends StatelessWidget {
  const _ChapterBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _ChapterGridPainter())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _ChapterGridPainter extends CustomPainter {
  const _ChapterGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChapterGridPainter oldDelegate) => false;
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
