import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/admin_service.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_breadcrumb.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class AdminScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final int initialTabIndex;
  final bool showTabs;
  final String? title;
  final String? breadcrumbLabel;

  const AdminScreen({
    super.key,
    this.onLogout,
    this.initialTabIndex = 0,
    this.showTabs = true,
    this.title,
    this.breadcrumbLabel,
  });

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final SubjectService _subjectService;
  late final AdminService _adminService;
  late final AiNotesService _aiNotesService;
  late final AiQuizService _aiQuizService;

  bool _isLoading = true;
  String? _errorMessage;
  List<Semester> _semesters = const [];
  Semester? _subjectSemester;
  Semester? _syllabusSemester;
  Semester? _noteSemester;
  Semester? _qaSemester;
  Subject? _chapterSubject;
  Subject? _noteSubject;
  Subject? _qaSubject;
  Chapter? _noteChapter;
  Chapter? _qaChapter;
  List<Chapter> _noteChapters = const [];
  List<AdminNote> _adminNotes = const [];
  List<AdminNoteSubmission> _pendingSubmissions = const [];
  List<Chapter> _qaChapters = const [];
  List<Quiz> _qaQuizzes = const [];
  Quiz? _qaSelectedQuiz;
  bool _noteChapterWise = true;
  bool _showNotePublisher = false;
  bool _isUploadingSyllabus = false;
  bool _isNotesLoading = false;
  bool _isAiNoteLoading = false;
  bool _isAiQuestionLoading = false;
  bool _isAiQuizQuestionLoading = false;
  String? _notesError;
  bool _isPendingLoading = false;
  String? _pendingError;
  List<String> _syllabusMessages = const [];
  List<String> _syllabusUnmatched = const [];
  List<String> _syllabusAmbiguous = const [];
  PlatformFile? _noteAttachment;
  PlatformFile? _pastPaperFile;
  String? _deletingNoteId;
  String? _reviewingSubmissionId;
  String _questionKind = 'important';
  String _quizType = 'mcq';
  String _quizDifficulty = 'easy';

  final _semesterName = TextEditingController();
  final _semesterCode = TextEditingController();
  final _semesterSort = TextEditingController(text: '1');

  final _subjectName = TextEditingController();
  final _subjectCode = TextEditingController();
  final _subjectDesc = TextEditingController();
  final _subjectColor = TextEditingController(text: '#2563EB');
  final _subjectSort = TextEditingController(text: '1');

  final _chapterTitle = TextEditingController();
  final _chapterSummary = TextEditingController();
  final _chapterSort = TextEditingController(text: '1');

  final _noteTitle = TextEditingController();
  final _noteShort = TextEditingController();
  final _noteDetailed = TextEditingController();
  final _noteTags = TextEditingController();
  final _questionPrompt = TextEditingController();
  final _questionMarks = TextEditingController(text: '5');
  final _questionYear = TextEditingController();
  final _pastPaperTitle = TextEditingController();
  final _pastPaperYear = TextEditingController();
  final _quizTitle = TextEditingController();
  final _quizDuration = TextEditingController(text: '10');
  final _quizQuestionPrompt = TextEditingController();
  final _quizQuestionOptions = TextEditingController();
  final _quizQuestionCorrect = TextEditingController();
  final _quizQuestionExplanation = TextEditingController();
  final _quizQuestionTopic = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subjectService = SubjectService(SupabaseConfig.client);
    _adminService = AdminService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _load();
  }

  @override
  void dispose() {
    _semesterName.dispose();
    _semesterCode.dispose();
    _semesterSort.dispose();
    _subjectName.dispose();
    _subjectCode.dispose();
    _subjectDesc.dispose();
    _subjectColor.dispose();
    _subjectSort.dispose();
    _chapterTitle.dispose();
    _chapterSummary.dispose();
    _chapterSort.dispose();
    _noteTitle.dispose();
    _noteShort.dispose();
    _noteDetailed.dispose();
    _noteTags.dispose();
    _questionPrompt.dispose();
    _questionMarks.dispose();
    _questionYear.dispose();
    _pastPaperTitle.dispose();
    _pastPaperYear.dispose();
    _quizTitle.dispose();
    _quizDuration.dispose();
    _quizQuestionPrompt.dispose();
    _quizQuestionOptions.dispose();
    _quizQuestionCorrect.dispose();
    _quizQuestionExplanation.dispose();
    _quizQuestionTopic.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final semesters = await _subjectService.fetchSemesters();
      final firstSemester = semesters.isNotEmpty ? semesters.first : null;
      setState(() {
        _semesters = semesters;
        _subjectSemester = firstSemester;
        _syllabusSemester = firstSemester;
        _chapterSubject = _subjectSemester?.subjects.isNotEmpty == true
            ? _subjectSemester!.subjects.first
            : null;
        _noteSemester = firstSemester;
        _noteSubject = firstSemester?.subjects.isNotEmpty == true
            ? firstSemester!.subjects.first
            : null;
        _qaSemester = firstSemester;
        _qaSubject = firstSemester?.subjects.isNotEmpty == true
            ? firstSemester!.subjects.first
            : null;
        _qaChapter = null;
        _qaSelectedQuiz = null;
        _isLoading = false;
      });
      await _loadNoteChapters();
      await _loadQaChapters();
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNoteChapters() async {
    final subject = _noteSubject;
    if (subject == null) {
      setState(() {
        _noteChapters = const [];
        _noteChapter = null;
      });
      await _loadAdminNotes();
      await _loadPendingSubmissions();
      return;
    }
    final chapters = await _adminService.fetchChaptersForSubject(subject.id);
    setState(() {
      _noteChapters = chapters;
      _noteChapter = chapters.isNotEmpty ? chapters.first : null;
    });
    await _loadAdminNotes();
    await _loadPendingSubmissions();
  }

  Future<String?> _resolveNoteChapterId() async {
    if (_noteChapterWise) {
      return _noteChapter?.id;
    }
    final subject = _noteSubject;
    if (subject == null) {
      return null;
    }
    return _adminService.ensureGeneralChapter(subject.id);
  }

  Future<void> _loadAdminNotes() async {
    setState(() {
      _isNotesLoading = true;
      _notesError = null;
    });
    try {
      final chapterId = await _resolveNoteChapterId();
      if (chapterId == null || chapterId.isEmpty) {
        setState(() {
          _adminNotes = const [];
          _isNotesLoading = false;
        });
        return;
      }
      final notes = await _adminService.fetchNotesForChapter(chapterId);
      if (!mounted) return;
      setState(() {
        _adminNotes = notes;
        _isNotesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notesError = 'Failed to load notes: $error';
        _isNotesLoading = false;
      });
    }
  }

  Future<void> _loadPendingSubmissions() async {
    final chapterId = _noteChapter?.id;
    if (chapterId == null || chapterId.isEmpty) {
      setState(() {
        _pendingSubmissions = const [];
        _pendingError = null;
      });
      return;
    }
    setState(() {
      _isPendingLoading = true;
      _pendingError = null;
    });
    try {
      final submissions =
          await _adminService.fetchPendingNoteSubmissions(
        chapterId: chapterId,
      );
      if (!mounted) return;
      setState(() {
        _pendingSubmissions = submissions;
        _isPendingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pendingError = 'Failed to load submissions: $error';
        _isPendingLoading = false;
      });
    }
  }

  Future<void> _generateAdminNoteDraft() async {
    if (_isAiNoteLoading) return;
    final subject = _noteSubject;
    final chapter = _noteChapter ??
        (_noteChapters.isNotEmpty ? _noteChapters.first : null);
    if (subject == null || chapter == null) {
      _show('Select a subject and chapter first.');
      return;
    }
    setState(() {
      _isAiNoteLoading = true;
      _showNotePublisher = true;
    });
    try {
      final draft = await _aiNotesService.generateNote(
        subject: subject,
        chapter: chapter,
      );
      if (draft == null) {
        _show('AI unavailable. Configure Ollama or LM Studio.');
        return;
      }
      _noteTitle.text = draft.title;
      _noteShort.text = draft.shortAnswer;
      _noteDetailed.text = draft.detailedAnswer;
      _show('AI draft ready.');
    } catch (error) {
      _show('AI generate failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAiNoteLoading = false;
        });
      }
    }
  }

  Future<void> _generateAdminQuestionPrompt() async {
    if (_isAiQuestionLoading) return;
    final subject = _qaSubject;
    final chapter = _qaChapter;
    if (subject == null || chapter == null) {
      _show('Select a subject and chapter first.');
      return;
    }
    setState(() {
      _isAiQuestionLoading = true;
    });
    try {
      final questions = await _aiQuizService.generateQuestions(
        quizId: 'admin-draft',
        subject: subject,
        chapter: chapter,
        count: 1,
        baseDifficulty: QuizDifficulty.easy,
      );
      if (questions.isEmpty) {
        _show('AI could not generate a question.');
        return;
      }
      final q = questions.first;
      _questionPrompt.text = q.prompt;
      if (_questionMarks.text.trim().isEmpty) {
        _questionMarks.text = '5';
      }
      _show('AI question ready.');
    } catch (error) {
      _show('AI generate failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAiQuestionLoading = false;
        });
      }
    }
  }

  Future<void> _generateAdminQuizQuestion() async {
    if (_isAiQuizQuestionLoading) return;
    final subject = _qaSubject;
    final chapter = _qaChapter;
    if (subject == null || chapter == null) {
      _show('Select a subject and chapter first.');
      return;
    }
    setState(() {
      _isAiQuizQuestionLoading = true;
    });
    try {
      final questions = await _aiQuizService.generateQuestions(
        quizId: _qaSelectedQuiz?.id ?? 'admin-draft',
        subject: subject,
        chapter: chapter,
        count: 1,
        baseDifficulty: QuizDifficulty.easy,
      );
      if (questions.isEmpty) {
        _show('AI could not generate a quiz question.');
        return;
      }
      final q = questions.first;
      _quizQuestionPrompt.text = q.prompt;
      _quizQuestionOptions.text = q.options.join('\n');
      _quizQuestionCorrect.text = (q.correctIndex + 1).toString();
      _quizQuestionExplanation.text = q.explanation ?? '';
      _quizQuestionTopic.text = q.topic ?? '';
      _show('AI quiz question ready.');
    } catch (error) {
      _show('AI generate failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAiQuizQuestionLoading = false;
        });
      }
    }
  }

  Future<void> _loadQaChapters() async {
    final subject = _qaSubject;
    if (subject == null) {
      setState(() {
        _qaChapters = const [];
        _qaChapter = null;
        _qaQuizzes = const [];
        _qaSelectedQuiz = null;
      });
      return;
    }
    final chapters = await _adminService.fetchChaptersForSubject(subject.id);
    setState(() {
      _qaChapters = chapters;
      _qaChapter = chapters.isNotEmpty ? chapters.first : null;
    });
    await _loadQaQuizzes();
  }

  Future<void> _loadQaQuizzes() async {
    final chapter = _qaChapter;
    if (chapter == null) {
      setState(() {
        _qaQuizzes = const [];
        _qaSelectedQuiz = null;
      });
      return;
    }
    final quizzes = await _adminService.fetchQuizzesForChapter(chapter.id);
    setState(() {
      _qaQuizzes = quizzes;
      _qaSelectedQuiz = quizzes.isNotEmpty ? quizzes.first : null;
    });
  }

  Future<void> _refreshProfileContent() async {
    final profile = AppState.profile.value;
    if (profile.semester.id.isEmpty) {
      return;
    }
    final subjects = await _subjectService.fetchSubjectsForSemester(
      profile.semester.id,
      includeContent: true,
    );
    AppState.updateProfile(
      UserProfile(
        name: profile.name,
        email: profile.email,
        semester: profile.semester,
        subjects: subjects,
        isAdmin: profile.isAdmin,
      ),
    );
  }

  Future<void> _addSemester() async {
    final name = _semesterName.text.trim();
    final code = _semesterCode.text.trim();
    final sortOrder = int.tryParse(_semesterSort.text.trim()) ?? 0;
    if (name.isEmpty || code.isEmpty) {
      _show('Name and code required.');
      return;
    }
    await _adminService.addSemester(
      name: name,
      code: code,
      sortOrder: sortOrder,
    );
    _semesterName.clear();
    _semesterCode.clear();
    await _load();
    await _refreshProfileContent();
    _show('Semester added.');
  }

  Future<void> _addSubject() async {
    final semester = _subjectSemester;
    if (semester == null) {
      _show('Select a semester.');
      return;
    }
    final name = _subjectName.text.trim();
    final code = _subjectCode.text.trim();
    if (name.isEmpty || code.isEmpty) {
      _show('Subject name and code required.');
      return;
    }
    await _adminService.addSubject(
      semesterId: semester.id,
      name: name,
      code: code,
      description: _subjectDesc.text.trim(),
      accentColor: _subjectColor.text.trim(),
      sortOrder: int.tryParse(_subjectSort.text.trim()) ?? 0,
    );
    _subjectName.clear();
    _subjectCode.clear();
    _subjectDesc.clear();
    await _load();
    await _refreshProfileContent();
    _show('Subject added.');
  }

  Future<void> _addChapter() async {
    final subject = _chapterSubject;
    if (subject == null) {
      _show('Select a subject.');
      return;
    }
    final title = _chapterTitle.text.trim();
    if (title.isEmpty) {
      _show('Chapter title required.');
      return;
    }
    await _adminService.addChapter(
      subjectId: subject.id,
      title: title,
      summary: _chapterSummary.text.trim(),
      sortOrder: int.tryParse(_chapterSort.text.trim()) ?? 0,
    );
    _chapterTitle.clear();
    _chapterSummary.clear();
    await _load();
    await _refreshProfileContent();
    _show('Chapter added.');
  }

  Future<void> _bulkUploadSyllabus() async {
    final semester = _syllabusSemester;
    if (semester == null) {
      _show('Select a semester first.');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _isUploadingSyllabus = true;
      _syllabusMessages = const [];
      _syllabusUnmatched = const [];
      _syllabusAmbiguous = const [];
    });
    try {
      final result = await _adminService.uploadSyllabusBatch(
        semester: semester,
        files: picked.files,
      );
      await _refreshProfileContent();
      setState(() {
        _syllabusMessages = result.messages;
        _syllabusUnmatched = result.unmatchedFiles;
        _syllabusAmbiguous = result.ambiguousFiles;
      });
      _show(
        'Uploaded ${result.uploaded} file(s), skipped ${result.skipped}.',
      );
    } catch (error) {
      _show('Upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingSyllabus = false;
        });
      }
    }
  }

  void _openSyllabus(Subject subject) {
    final url = subject.syllabusUrl;
    if (url == null || url.isEmpty) {
      _show('No syllabus URL for ${subject.code}.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: subject.name,
          url: url,
        ),
      ),
    );
  }

  Future<void> _addNote() async {
    String chapterId;
    if (_noteChapterWise) {
      final chapter = _noteChapter;
      if (chapter == null) {
        _show('Select a chapter.');
        return;
      }
      chapterId = chapter.id;
    } else {
      final subject = _noteSubject;
      if (subject == null) {
        _show('Select a subject.');
        return;
      }
      chapterId = await _adminService.ensureGeneralChapter(subject.id);
    }
    final title = _noteTitle.text.trim();
    var short = _noteShort.text.trim();
    var detailed = _noteDetailed.text.trim();
    if (title.isEmpty) {
      _show('Title required.');
      return;
    }
    if (short.isEmpty && detailed.isEmpty) {
      _show('Add note content.');
      return;
    }
    if (detailed.isEmpty) {
      detailed = short;
    }
    if (short.isEmpty) {
      short = _deriveShortFromDetailed(detailed);
    }
    String? fileUrl;
    if (_noteAttachment != null) {
      fileUrl = await _adminService.uploadNoteAttachment(
        chapterId: chapterId,
        file: _noteAttachment!,
      );
    }
    await _adminService.addNote(
      chapterId: chapterId,
      title: title,
      shortAnswer: short,
      detailedAnswer: detailed,
      tags: _adminService.parseTags(_noteTags.text),
      fileUrl: fileUrl,
    );
    _noteTitle.clear();
    _noteShort.clear();
    _noteDetailed.clear();
    _noteTags.clear();
    setState(() {
      _noteAttachment = null;
    });
    await _loadAdminNotes();
    await _refreshProfileContent();
    _show('Note added.');
  }

  Future<void> _editNote(AdminNote note) async {
    final titleController = TextEditingController(text: note.title);
    final shortController = TextEditingController(text: note.shortAnswer);
    final detailedController = TextEditingController(text: note.detailedAnswer);
    final tagsController = TextEditingController(text: note.tags.join(', '));
    PlatformFile? attachment;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Note',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailedController,
                      maxLines: 6,
                      decoration:
                          const InputDecoration(labelText: 'Note content'),
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Advanced options'),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        TextField(
                          controller: shortController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Short answer (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: tagsController,
                          decoration: const InputDecoration(
                            labelText: 'Tags (comma separated)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                attachment?.name ??
                                    (note.fileUrl == null
                                        ? 'No attachment'
                                        : 'Current attachment'),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked =
                                    await FilePicker.platform.pickFiles(
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
                                if (picked != null &&
                                    picked.files.isNotEmpty) {
                                  setSheetState(() {
                                    attachment = picked.files.first;
                                  });
                                }
                              },
                              child: const Text('Replace File'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    void disposeControllers() {
      titleController.dispose();
      shortController.dispose();
      detailedController.dispose();
      tagsController.dispose();
    }

    if (saved != true) {
      disposeControllers();
      return;
    }

    final title = titleController.text.trim();
    var short = shortController.text.trim();
    var detailed = detailedController.text.trim();
    if (title.isEmpty) {
      _show('Title required.');
      disposeControllers();
      return;
    }
    if (short.isEmpty && detailed.isEmpty) {
      _show('Add note content.');
      disposeControllers();
      return;
    }
    if (detailed.isEmpty) {
      detailed = short;
    }
    if (short.isEmpty) {
      short = _deriveShortFromDetailed(detailed);
    }
    String? fileUrl;
    if (attachment != null) {
      fileUrl = await _adminService.uploadNoteAttachment(
        chapterId: note.chapterId,
        file: attachment!,
      );
    }
    await _adminService.updateNote(
      noteId: note.id,
      title: title,
      shortAnswer: short,
      detailedAnswer: detailed,
      tags: _adminService.parseTags(tagsController.text),
      fileUrl: fileUrl,
    );
    await _loadAdminNotes();
    await _refreshProfileContent();
    _show('Note updated.');
    disposeControllers();
  }

  Future<void> _confirmDeleteAdminNote(AdminNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: Text('Delete "${note.title}"? This cannot be undone.'),
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
    await _deleteAdminNote(note);
  }

  Future<void> _deleteAdminNote(AdminNote note) async {
    if (_deletingNoteId == note.id) return;
    setState(() {
      _deletingNoteId = note.id;
    });
    try {
      await _adminService.deleteNote(note.id);
      await _loadAdminNotes();
      if (!mounted) return;
      _show('Note deleted.');
    } catch (error) {
      if (!mounted) return;
      _show('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingNoteId = null;
        });
      }
    }
  }

  Future<void> _approveSubmission(AdminNoteSubmission submission) async {
    if (_reviewingSubmissionId == submission.id) return;
    setState(() {
      _reviewingSubmissionId = submission.id;
    });
    try {
      await _adminService.approveNoteSubmission(submission);
      await _loadAdminNotes();
      await _loadPendingSubmissions();
      if (!mounted) return;
      _show('Submission approved.');
    } catch (error) {
      if (!mounted) return;
      _show('Approve failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _reviewingSubmissionId = null;
        });
      }
    }
  }

  Future<void> _rejectSubmission(AdminNoteSubmission submission) async {
    final feedbackController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject submission?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will mark the note as rejected.'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin feedback (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final feedback = feedbackController.text.trim();
    feedbackController.dispose();
    if (confirmed != true || !mounted) return;
    setState(() {
      _reviewingSubmissionId = submission.id;
    });
    try {
      await _adminService.rejectNoteSubmission(
        submission,
        feedback: feedback.isEmpty ? null : feedback,
      );
      await _loadPendingSubmissions();
      if (!mounted) return;
      _show('Submission rejected.');
    } catch (error) {
      if (!mounted) return;
      _show('Reject failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _reviewingSubmissionId = null;
        });
      }
    }
  }

  Future<void> _deleteSubmission(AdminNoteSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete submission?'),
        content: const Text('This will permanently delete the submission.'),
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
    setState(() {
      _reviewingSubmissionId = submission.id;
    });
    try {
      await _adminService.deleteNoteSubmission(submission.id);
      await _loadPendingSubmissions();
      if (!mounted) return;
      _show('Submission deleted.');
    } catch (error) {
      if (!mounted) return;
      _show('Delete failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _reviewingSubmissionId = null;
        });
      }
    }
  }

  String _deriveShortFromDetailed(String detailed) {
    final lines = detailed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length >= 5) {
      return lines.take(5).join('\n');
    }
    final sentences = detailed
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isNotEmpty) {
      return sentences.take(5).join('\n');
    }
    return detailed;
  }

  Future<void> _pickNoteAttachment() async {
    final picked = await FilePicker.platform.pickFiles(
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
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _noteAttachment = picked.files.first;
    });
  }

  Future<void> _pickPastPaper() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }
    setState(() {
      _pastPaperFile = picked.files.first;
    });
  }

  Future<void> _addQuestion() async {
    final chapter = _qaChapter;
    if (chapter == null) {
      _show('Select a chapter for the question.');
      return;
    }
    final prompt = _questionPrompt.text.trim();
    if (prompt.isEmpty) {
      _show('Question prompt required.');
      return;
    }
    final marks = int.tryParse(_questionMarks.text.trim()) ?? 5;
    int? year;
    if (_questionKind == 'past' && _questionYear.text.trim().isNotEmpty) {
      year = int.tryParse(_questionYear.text.trim());
      if (year == null) {
        _show('Enter a valid year.');
        return;
      }
    }
    await _adminService.addQuestion(
      chapterId: chapter.id,
      prompt: prompt,
      marks: marks,
      kind: _questionKind,
      year: year,
    );
    _questionPrompt.clear();
    _questionMarks.text = '5';
    _questionYear.clear();
    await _refreshProfileContent();
    _show('Question added.');
  }

  Future<void> _addQuiz() async {
    final chapter = _qaChapter;
    if (chapter == null) {
      _show('Select a chapter for the quiz.');
      return;
    }
    final title = _quizTitle.text.trim();
    if (title.isEmpty) {
      _show('Quiz title required.');
      return;
    }
    final duration = int.tryParse(_quizDuration.text.trim()) ?? 10;
    final quizId = await _adminService.addQuiz(
      chapterId: chapter.id,
      title: title,
      quizType: _quizType,
      difficulty: _quizDifficulty,
      durationMinutes: duration,
    );
    _quizTitle.clear();
    await _loadQaQuizzes();
    final created = _qaQuizzes.where((q) => q.id == quizId).toList();
    if (created.isNotEmpty) {
      setState(() {
        _qaSelectedQuiz = created.first;
      });
    }
    await _refreshProfileContent();
    _show('Quiz created.');
  }

  Future<void> _addQuizQuestion() async {
    final quiz = _qaSelectedQuiz;
    if (quiz == null) {
      _show('Select a quiz first.');
      return;
    }
    final prompt = _quizQuestionPrompt.text.trim();
    if (prompt.isEmpty) {
      _show('Quiz question prompt required.');
      return;
    }
    final options = _parseQuizOptions(_quizQuestionOptions.text);
    if (options.length < 2) {
      _show('Enter at least two options.');
      return;
    }
    int? correctIndex;
    if (_quizQuestionCorrect.text.trim().isNotEmpty) {
      final parsed = int.tryParse(_quizQuestionCorrect.text.trim());
      if (parsed == null) {
        _show('Correct option must be a number.');
        return;
      }
      correctIndex = parsed - 1;
      if (correctIndex < 0 || correctIndex >= options.length) {
        _show('Correct option must be between 1 and ${options.length}.');
        return;
      }
    }

    await _adminService.addQuizQuestion(
      quizId: quiz.id,
      prompt: prompt,
      options: options,
      correctIndex: correctIndex,
      explanation: _quizQuestionExplanation.text.trim().isEmpty
          ? null
          : _quizQuestionExplanation.text.trim(),
      topic: _quizQuestionTopic.text.trim().isEmpty
          ? null
          : _quizQuestionTopic.text.trim(),
    );

    _quizQuestionPrompt.clear();
    _quizQuestionOptions.clear();
    _quizQuestionCorrect.clear();
    _quizQuestionExplanation.clear();
    _quizQuestionTopic.clear();
    await _loadQaQuizzes();
    await _refreshProfileContent();
    _show('Quiz question added.');
  }

  Future<void> _addPastPaper() async {
    final subject = _qaSubject;
    if (subject == null) {
      _show('Select a subject for the past paper.');
      return;
    }
    final title = _pastPaperTitle.text.trim();
    if (title.isEmpty) {
      _show('Past paper title required.');
      return;
    }
    final file = _pastPaperFile;
    if (file == null) {
      _show('Select a PDF file.');
      return;
    }
    int? year;
    if (_pastPaperYear.text.trim().isNotEmpty) {
      year = int.tryParse(_pastPaperYear.text.trim());
      if (year == null) {
        _show('Enter a valid year.');
        return;
      }
    }
    final url = await _adminService.uploadPastPaper(
      subjectId: subject.id,
      file: file,
    );
    await _adminService.addPastPaper(
      subjectId: subject.id,
      title: title,
      year: year,
      fileUrl: url,
    );
    _pastPaperTitle.clear();
    _pastPaperYear.clear();
    setState(() {
      _pastPaperFile = null;
    });
    await _refreshProfileContent();
    _show('Past paper added.');
  }

  List<String> _parseQuizOptions(String raw) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length > 1) {
      return lines;
    }
    return raw
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
  }

  Subject? _matchSubject(List<Subject> subjects, Subject? selected) {
    if (selected == null) return null;
    for (final subject in subjects) {
      if (subject.id == selected.id) {
        return subject;
      }
    }
    return null;
  }

  Chapter? _matchChapter(List<Chapter> chapters, Chapter? selected) {
    if (selected == null) return null;
    for (final chapter in chapters) {
      if (chapter.id == selected.id) {
        return chapter;
      }
    }
    return null;
  }

  Quiz? _matchQuiz(List<Quiz> quizzes, Quiz? selected) {
    if (selected == null) return null;
    for (final quiz in quizzes) {
      if (quiz.id == selected.id) {
        return quiz;
      }
    }
    return null;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = widget.title ?? 'Admin';
    final appBar = AppBar(
      title: Text(resolvedTitle),
      actions: [
        if (widget.onLogout != null)
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
      ],
      bottom: widget.showTabs
          ? const TabBar(
              tabs: [
                Tab(text: 'Syllabus'),
                Tab(text: 'Notes'),
                Tab(text: 'Questions & Quizzes'),
              ],
            )
          : null,
    );

    final baseBody = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : widget.showTabs
                ? const TabBarView(
                    children: [
                      _SyllabusTab(),
                      _NotesTab(),
                      _QuestionsTab(),
                    ],
                  )
                : _buildBodyByIndex(widget.initialTabIndex);

    final body = !widget.showTabs && widget.breadcrumbLabel != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminBreadcrumb(label: widget.breadcrumbLabel!),
              const SizedBox(height: 8),
              Expanded(child: baseBody),
            ],
          )
        : baseBody;

    final scaffold = Scaffold(
      appBar: appBar,
      body: body,
    );

    if (!widget.showTabs) {
      return scaffold;
    }

    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
      child: scaffold,
    );
  }

  Widget _buildBodyByIndex(int index) {
    switch (index) {
      case 0:
        return _buildSyllabusTab();
      case 1:
        return _buildNotesTab();
      case 2:
      default:
        return _buildQuestionsTab();
    }
  }

  Widget _buildSyllabusTab() {
    final chapterSubjects = _subjectSemester?.subjects ?? const <Subject>[];
    final chapterSubjectValue = _matchSubject(
      chapterSubjects,
      _chapterSubject,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulk Upload Syllabus',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Semester>(
                key: ValueKey(_syllabusSemester?.id ?? ''),
                initialValue: _syllabusSemester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: _semesters
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _syllabusSemester = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Filename should include subject code or name '
                '(example: BCA1-CFA.pdf).',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isUploadingSyllabus ? null : _bulkUploadSyllabus,
                child: Text(
                  _isUploadingSyllabus ? 'Uploading…' : 'Select PDFs & Upload',
                ),
              ),
              if (_syllabusMessages.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._syllabusMessages.map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(message),
                  ),
                ),
              ],
              if (_syllabusUnmatched.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Unmatched files:'),
                const SizedBox(height: 4),
                ..._syllabusUnmatched.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(name),
                  ),
                ),
              ],
              if (_syllabusAmbiguous.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Ambiguous files:'),
                const SizedBox(height: 4),
                ..._syllabusAmbiguous.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(name),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Syllabus Links',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_syllabusSemester == null)
                const Text('Select a semester to view subjects.')
              else if (_syllabusSemester!.subjects.isEmpty)
                const Text('No subjects found for this semester.')
              else
                ..._syllabusSemester!.subjects.map(
                  (subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${subject.code} — ${subject.name}',
                          ),
                        ),
                        TextButton(
                          onPressed: subject.syllabusUrl == null ||
                                  subject.syllabusUrl!.isEmpty
                              ? null
                              : () => _openSyllabus(subject),
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Add Semester',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _semesterName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _semesterCode,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced options'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _semesterSort,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Sort order'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addSemester,
                child: const Text('Save Semester'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Add Subject',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<Semester>(
                key: ValueKey(_subjectSemester?.id ?? ''),
                initialValue: _subjectSemester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: _semesters
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _subjectSemester = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectName,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCode,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced options'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _subjectDesc,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectColor,
                    decoration: const InputDecoration(
                      labelText: 'Accent color (#hex)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectSort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort order'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addSubject,
                child: const Text('Save Subject'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Add Chapter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<Subject>(
                key: ValueKey(chapterSubjectValue?.id ?? ''),
                initialValue: chapterSubjectValue,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: chapterSubjects
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _chapterSubject = value;
                    _noteSubject = value;
                  });
                  _loadNoteChapters();
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _chapterTitle,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Advanced options'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _chapterSummary,
                    decoration: const InputDecoration(labelText: 'Summary'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _chapterSort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sort order'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addChapter,
                child: const Text('Save Chapter'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesTab() {
    final noteSubjects = _noteSemester?.subjects ?? const <Subject>[];
    final noteSubjectValue = _matchSubject(noteSubjects, _noteSubject);
    final noteChapterValue = _matchChapter(_noteChapters, _noteChapter);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Publish Note',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isAiNoteLoading ? null : _generateAdminNoteDraft,
                    child: _isAiNoteLoading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('AI Draft'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showNotePublisher = !_showNotePublisher;
                      });
                    },
                    child: Text(_showNotePublisher ? 'Hide' : 'Add Note'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _showNotePublisher
                    ? 'Only title and content are required. Short answer and tags '
                        'are optional.'
                    : 'Added notes are shown below. Use Add Note when you want to publish.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              if (_showNotePublisher) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _noteChapterWise,
                  onChanged: (value) {
                    setState(() {
                      _noteChapterWise = value;
                    });
                    _loadNoteChapters();
                  },
                  title: const Text('Chapter-wise notes'),
                  subtitle: const Text(
                    'Turn off to add notes directly to subject.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Semester>(
                  key: ValueKey(_noteSemester?.id ?? ''),
                  initialValue: _noteSemester,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  isExpanded: true,
                  items: _semesters
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _noteSemester = value;
                      _noteSubject = value?.subjects.isNotEmpty == true
                          ? value!.subjects.first
                          : null;
                      _noteChapter = null;
                    });
                    _loadNoteChapters();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Subject>(
                  key: ValueKey(noteSubjectValue?.id ?? ''),
                  initialValue: noteSubjectValue,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  isExpanded: true,
                  items: noteSubjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _noteSubject = value;
                    });
                    _loadNoteChapters();
                  },
                ),
                const SizedBox(height: 12),
                if (_noteChapterWise) ...[
                  DropdownButtonFormField<Chapter>(
                    key: ValueKey(noteChapterValue?.id ?? ''),
                    initialValue: noteChapterValue,
                    decoration: const InputDecoration(labelText: 'Chapter'),
                    isExpanded: true,
                    items: _noteChapters
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  onChanged: (value) {
                    setState(() {
                      _noteChapter = value;
                    });
                    _loadAdminNotes();
                    _loadPendingSubmissions();
                  },
                ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _noteTitle,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteDetailed,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Note content'),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advanced options'),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    TextField(
                      controller: _noteShort,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Short answer (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteTags,
                      decoration: const InputDecoration(
                        labelText: 'Tags (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _noteAttachment?.name ?? 'No attachment selected',
                          ),
                        ),
                        TextButton(
                          onPressed: _pickNoteAttachment,
                          child: const Text('Select File'),
                        ),
                        if (_noteAttachment != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _noteAttachment = null;
                              });
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _addNote,
                  child: const Text('Save Note'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Manage Notes',
          actionLabel: _isNotesLoading ? null : 'Refresh',
          onAction: _isNotesLoading ? null : _loadAdminNotes,
        ),
        const SizedBox(height: 12),
        if (_isNotesLoading)
          const Center(child: CircularProgressIndicator())
        else if (_notesError != null)
          Text(
            _notesError!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.danger),
          )
        else if (_adminNotes.isEmpty)
          const Text('No notes found for the selected chapter.')
        else
          ..._adminNotes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _editNote(note),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: _deletingNoteId == note.id
                              ? null
                              : () => _confirmDeleteAdminNote(note),
                          icon: _deletingNoteId == note.id
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (note.shortAnswer.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note.shortAnswer,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: note.tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Pending Student Notes',
          actionLabel: _isPendingLoading ? null : 'Refresh',
          onAction: _isPendingLoading ? null : _loadPendingSubmissions,
        ),
        const SizedBox(height: 12),
        if (_noteChapter == null)
          const Text('Select a chapter to review submissions.')
        else if (_isPendingLoading)
          const Center(child: CircularProgressIndicator())
        else if (_pendingError != null)
          Text(
            _pendingError!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.danger),
          )
        else if (_pendingSubmissions.isEmpty)
          const Text('No pending submissions for this chapter.')
        else
          ..._pendingSubmissions.map(
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
                        if (_reviewingSubmissionId == submission.id)
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          TextButton(
                            onPressed: () => _approveSubmission(submission),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => _rejectSubmission(submission),
                            child: const Text('Reject'),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () => _deleteSubmission(submission),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      submission.subjectName == null
                          ? submission.chapterTitle
                          : '${submission.subjectName} • ${submission.chapterTitle}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    if (submission.shortAnswer.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        submission.shortAnswer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (submission.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: submission.tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionsTab() {
    final qaSubjects = _qaSemester?.subjects ?? const <Subject>[];
    final qaSubjectValue = _matchSubject(qaSubjects, _qaSubject);
    final qaChapterValue = _matchChapter(_qaChapters, _qaChapter);
    final qaQuizValue = _matchQuiz(_qaQuizzes, _qaSelectedQuiz);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Chapter',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick the chapter first. Everything below will publish to it.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Semester>(
                key: ValueKey(_qaSemester?.id ?? ''),
                initialValue: _qaSemester,
                decoration: const InputDecoration(labelText: 'Semester'),
                isExpanded: true,
                items: _semesters
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _qaSemester = value;
                    _qaSubject = value?.subjects.isNotEmpty == true
                        ? value!.subjects.first
                        : null;
                    _qaChapter = null;
                    _qaSelectedQuiz = null;
                  });
                  _loadQaChapters();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Subject>(
                key: ValueKey(qaSubjectValue?.id ?? ''),
                initialValue: qaSubjectValue,
                decoration: const InputDecoration(labelText: 'Subject'),
                isExpanded: true,
                items: qaSubjects
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _qaSubject = value;
                    _qaChapter = null;
                  });
                  _loadQaChapters();
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Chapter>(
                key: ValueKey(qaChapterValue?.id ?? ''),
                initialValue: qaChapterValue,
                decoration: const InputDecoration(labelText: 'Chapter'),
                isExpanded: true,
                items: _qaChapters
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _qaChapter = value;
                  });
                  _loadQaQuizzes();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Publish Question',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _isAiQuestionLoading
                      ? null
                      : _generateAdminQuestionPrompt,
                  child: _isAiQuestionLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('AI Suggest'),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _questionKind,
                decoration: const InputDecoration(labelText: 'Question type'),
                items: const [
                  DropdownMenuItem(
                    value: 'important',
                    child: Text('Important'),
                  ),
                  DropdownMenuItem(
                    value: 'past',
                    child: Text('Past Qs'),
                  ),
                  DropdownMenuItem(
                    value: 'practice',
                    child: Text('Practice'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _questionKind = value ?? 'important';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionPrompt,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionMarks,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Marks (default 5)',
                ),
              ),
              if (_questionKind == 'past') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _questionYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addQuestion,
                child: const Text('Save Question'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Publish Past Paper',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _pastPaperTitle,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pastPaperYear,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Year (optional)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _pastPaperFile?.name ?? 'No file selected',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickPastPaper,
                    child: const Text('Select PDF'),
                  ),
                  if (_pastPaperFile != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _pastPaperFile = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addPastPaper,
                child: const Text('Save Past Paper'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Create Quiz',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _quizTitle,
                decoration: const InputDecoration(labelText: 'Quiz title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _quizType,
                decoration: const InputDecoration(labelText: 'Quiz type'),
                items: const [
                  DropdownMenuItem(value: 'mcq', child: Text('MCQ')),
                  DropdownMenuItem(value: 'time', child: Text('Time Attack')),
                  DropdownMenuItem(value: 'level', child: Text('Level')),
                ],
                onChanged: (value) {
                  setState(() {
                    _quizType = value ?? 'mcq';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _quizDifficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard')),
                ],
                onChanged: (value) {
                  setState(() {
                    _quizDifficulty = value ?? 'easy';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizDuration,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Duration (minutes)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _addQuiz,
                child: const Text('Create Quiz'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Quiz Question',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _isAiQuizQuestionLoading
                      ? null
                      : _generateAdminQuizQuestion,
                  child: _isAiQuizQuestionLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('AI Generate'),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              if (_qaQuizzes.isEmpty)
                const Text('Create a quiz first for this chapter.')
              else
                DropdownButtonFormField<Quiz>(
                  key: ValueKey(qaQuizValue?.id ?? ''),
                  initialValue: qaQuizValue,
                  decoration: const InputDecoration(labelText: 'Quiz'),
                  isExpanded: true,
                  items: _qaQuizzes
                      .map(
                        (q) => DropdownMenuItem(
                          value: q,
                          child: Text(
                            '${q.title} (${q.questionCount} Qs)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _qaSelectedQuiz = value;
                    });
                  },
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizQuestionPrompt,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'Question prompt'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizQuestionOptions,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Options (one per line or comma separated)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizQuestionCorrect,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Correct option number (1-based)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizQuestionExplanation,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Explanation (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quizQuestionTopic,
                decoration:
                    const InputDecoration(labelText: 'Topic (optional)'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _qaQuizzes.isEmpty ? null : _addQuizQuestion,
                child: const Text('Save Quiz Question'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyllabusTab extends StatelessWidget {
  const _SyllabusTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminScreenState>();
    if (state == null) {
      return const SizedBox.shrink();
    }
    return state._buildSyllabusTab();
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminScreenState>();
    if (state == null) {
      return const SizedBox.shrink();
    }
    return state._buildNotesTab();
  }
}

class _QuestionsTab extends StatelessWidget {
  const _QuestionsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_AdminScreenState>();
    if (state == null) {
      return const SizedBox.shrink();
    }
    return state._buildQuestionsTab();
  }
}
