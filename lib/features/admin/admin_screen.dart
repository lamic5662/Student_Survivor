import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
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
  List<AdminCommunityQuestion> _pendingCommunityQuestions = const [];
  List<Chapter> _qaChapters = const [];
  List<Quiz> _qaQuizzes = const [];
  Quiz? _qaSelectedQuiz;
  List<College> _colleges = const [];
  College? _editingCollege;
  bool _isCollegeLoading = false;
  bool _noteChapterWise = true;
  bool _showNotePublisher = false;
  bool _isUploadingSyllabus = false;
  bool _isNotesLoading = false;
  bool _isAiNoteLoading = false;
  bool _isAiQuestionLoading = false;
  bool _isAiQuizQuestionLoading = false;
  bool _isBulkNotesUploading = false;
  bool _isBulkQuestionsUploading = false;
  List<String> _bulkNotesMessages = const [];
  List<String> _bulkQuestionMessages = const [];
  String? _notesError;
  bool _isPendingLoading = false;
  String? _pendingError;
  bool _isCommunityPendingLoading = false;
  String? _communityPendingError;
  List<String> _syllabusMessages = const [];
  List<String> _syllabusUnmatched = const [];
  List<String> _syllabusAmbiguous = const [];
  PlatformFile? _noteAttachment;
  PlatformFile? _pastPaperFile;
  String? _deletingNoteId;
  String? _reviewingSubmissionId;
  String? _reviewingCommunityQuestionId;
  String _questionKind = 'important';
  String _quizType = 'mcq';
  String _quizDifficulty = 'easy';

  final _semesterName = TextEditingController();
  final _semesterCode = TextEditingController();
  final _semesterSort = TextEditingController(text: '1');
  final _collegeName = TextEditingController();

  final _subjectName = TextEditingController();
  final _subjectCode = TextEditingController();
  final _subjectDesc = TextEditingController();
  final _subjectColor = TextEditingController(text: '#2563EB');
  final _subjectSort = TextEditingController(text: '1');

  final _chapterTitle = TextEditingController();
  final _chapterSummary = TextEditingController();
  final _chapterSort = TextEditingController(text: '1');
  final _chapterSubtopics = TextEditingController();

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
    _collegeName.dispose();
    _subjectName.dispose();
    _subjectCode.dispose();
    _subjectDesc.dispose();
    _subjectColor.dispose();
    _subjectSort.dispose();
    _chapterTitle.dispose();
    _chapterSummary.dispose();
    _chapterSort.dispose();
    _chapterSubtopics.dispose();
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
      await _loadPendingCommunityQuestions();
      await _loadColleges();
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load data: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadColleges() async {
    setState(() {
      _isCollegeLoading = true;
    });
    try {
      final colleges = await _adminService.fetchColleges();
      if (!mounted) return;
      setState(() {
        _colleges = colleges;
        _isCollegeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCollegeLoading = false;
      });
    }
  }

  void _editCollege(College college) {
    setState(() {
      _editingCollege = college;
      _collegeName.text = college.name;
    });
  }

  void _clearCollegeForm() {
    setState(() {
      _editingCollege = null;
      _collegeName.clear();
    });
  }

  Future<void> _saveCollege() async {
    final name = _collegeName.text.trim();
    if (name.isEmpty) {
      _show('College name required.');
      return;
    }
    try {
      final editing = _editingCollege;
      if (editing == null) {
        await _adminService.addCollege(name: name);
        _show('College added.');
      } else {
        await _adminService.updateCollege(collegeId: editing.id, name: name);
        _show('College updated.');
      }
      _clearCollegeForm();
      await _loadColleges();
    } catch (error) {
      _show('Failed to save college: $error');
    }
  }

  Future<void> _toggleCollege(College college) async {
    try {
      await _adminService.setCollegeActive(
        collegeId: college.id,
        isActive: !college.isActive,
      );
      await _loadColleges();
    } catch (error) {
      _show('Failed to update college: $error');
    }
  }

  Future<void> _deleteCollege(College college) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete college?'),
        content: Text('Remove ${college.name}?'),
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
    if (confirmed != true) return;
    try {
      await _adminService.deleteCollege(college.id);
      await _loadColleges();
      _show('College deleted.');
    } catch (error) {
      _show('Failed to delete college: $error');
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

  Future<void> _loadPendingCommunityQuestions() async {
    setState(() {
      _isCommunityPendingLoading = true;
      _communityPendingError = null;
    });
    try {
      final pending =
          await _adminService.fetchPendingCommunityQuestions();
      if (!mounted) return;
      setState(() {
        _pendingCommunityQuestions = pending;
        _isCommunityPendingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _communityPendingError =
            'Failed to load community questions: $error';
        _isCommunityPendingLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard.')),
    );
  }

  void _openNoteAttachment({
    required String title,
    required String url,
  }) {
    if (url.trim().isEmpty) {
      _show('No attachment available.');
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

  void _showAdminNoteDetails(AdminNote note) {
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
                MathText(
                  text: note.title,
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),
                if ((note.fileUrl ?? '').isNotEmpty) ...[
                  if (_isImageUrl(note.fileUrl!)) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        note.fileUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
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
                            'Image unavailable',
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
                  _AdminCard(
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file_rounded,
                            color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attachment available',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openNoteAttachment(
                            title: note.title,
                            url: note.fileUrl!,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                          ),
                          child: const Text('Open'),
                        ),
                        TextButton(
                          onPressed: () => _copyToClipboard(note.fileUrl!),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                          ),
                          child: const Text('Copy link'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (note.detailedAnswer.isNotEmpty ||
                    note.shortAnswer.isNotEmpty) ...[
                  Text(
                    'Notes',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  MathText(
                    text: note.detailedAnswer.isNotEmpty
                        ? note.detailedAnswer
                        : note.shortAnswer,
                    textStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                ],
                if (note.tags.isNotEmpty) ...[
                  Text(
                    'Tags',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
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
            );
          },
        );
      },
    );
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
    final subtopics = <Map<String, dynamic>>[];
    var sortOrder = 1;
    final lines = _chapterSubtopics.text.split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split('|');
      final topicTitle = parts.first.trim();
      if (topicTitle.isEmpty) continue;
      final summary = parts.length > 1
          ? parts.sublist(1).join('|').trim()
          : '';
      subtopics.add({
        'title': topicTitle,
        'summary': summary,
        'sort_order': sortOrder,
      });
      sortOrder += 1;
    }
    await _adminService.addChapter(
      subjectId: subject.id,
      title: title,
      summary: _chapterSummary.text.trim(),
      sortOrder: int.tryParse(_chapterSort.text.trim()) ?? 0,
      subtopics: subtopics,
    );
    _chapterTitle.clear();
    _chapterSummary.clear();
    _chapterSubtopics.clear();
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

  Future<void> _bulkUploadNotes() async {
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
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _isBulkNotesUploading = true;
      _bulkNotesMessages = const [];
    });
    try {
      final result = await _adminService.uploadNotesBatch(
        chapterId: chapterId,
        files: picked.files,
        tags: _adminService.parseTags(_noteTags.text),
      );
      await _loadAdminNotes();
      await _refreshProfileContent();
      setState(() {
        _bulkNotesMessages = result.messages;
      });
      _show(
        'Uploaded ${result.uploaded} file(s), skipped ${result.skipped}.',
      );
    } catch (error) {
      _show('Bulk upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBulkNotesUploading = false;
        });
      }
    }
  }

  Future<void> _bulkUploadQuestions() async {
    final chapter = _qaChapter;
    if (chapter == null) {
      _show('Select a chapter for the questions.');
      return;
    }
    final marks = int.tryParse(_questionMarks.text.trim()) ?? 5;
    int? year;
    if (_questionKind == 'past' && _questionYear.text.trim().isNotEmpty) {
      year = int.tryParse(_questionYear.text.trim());
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'txt',
        'csv',
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
      ],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }

    setState(() {
      _isBulkQuestionsUploading = true;
      _bulkQuestionMessages = const [];
    });
    try {
      final result = await _adminService.uploadQuestionsBatch(
        chapterId: chapter.id,
        files: picked.files,
        kind: _questionKind,
        marks: marks,
        defaultYear: year,
      );
      setState(() {
        _bulkQuestionMessages = result.messages;
      });
      _show(
        'Imported ${result.uploaded} question(s), skipped ${result.skipped} file(s).',
      );
    } catch (error) {
      _show('Bulk upload failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBulkQuestionsUploading = false;
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

  Future<void> _approveCommunityQuestion(
    AdminCommunityQuestion question,
  ) async {
    if (_reviewingCommunityQuestionId == question.id) return;
    setState(() {
      _reviewingCommunityQuestionId = question.id;
    });
    try {
      await _adminService.approveCommunityQuestion(question);
      await _loadPendingCommunityQuestions();
      if (!mounted) return;
      _show('Question approved.');
    } catch (error) {
      if (!mounted) return;
      _show('Approve failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _reviewingCommunityQuestionId = null;
        });
      }
    }
  }

  Future<void> _rejectCommunityQuestion(
    AdminCommunityQuestion question,
  ) async {
    final feedbackController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject question?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will keep the question hidden.'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Admin reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      feedbackController.dispose();
      return;
    }
    if (_reviewingCommunityQuestionId == question.id) return;
    setState(() {
      _reviewingCommunityQuestionId = question.id;
    });
    try {
      await _adminService.rejectCommunityQuestion(
        question,
        adminReason: feedbackController.text.trim(),
      );
      await _loadPendingCommunityQuestions();
      if (!mounted) return;
      _show('Question rejected.');
    } catch (error) {
      if (!mounted) return;
      _show('Reject failed: $error');
    } finally {
      feedbackController.dispose();
      if (mounted) {
        setState(() {
          _reviewingCommunityQuestionId = null;
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

  Semester? _matchSemester(List<Semester> semesters, Semester? selected) {
    if (selected == null) return null;
    for (final semester in semesters) {
      if (semester.id == selected.id) {
        return semester;
      }
    }
    return null;
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

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = widget.title ?? 'Admin';
    final appBar = AppBar(
      title: Text(
        resolvedTitle,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
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
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Color(0xFF38BDF8),
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

    final scaffold = GameZoneScaffold(
      appBar: appBar,
      body: body,
      useSafeArea: true,
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
    final syllabusSemesterValue = _matchSemester(_semesters, _syllabusSemester);
    final chapterSubjects = _subjectSemester?.subjects ?? const <Subject>[];
    final chapterSubjectValue = _matchSubject(
      chapterSubjects,
      _chapterSubject,
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bulk Upload Syllabus',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Semester>(
                key: ValueKey(
                  'syllabus_semester_${syllabusSemesterValue?.id ?? 'none'}',
                ),
                initialValue: syllabusSemesterValue,
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
        _AdminCard(
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
        _AdminCard(
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
        _AdminCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Manage Colleges',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              TextField(
                controller: _collegeName,
                decoration: const InputDecoration(labelText: 'College name'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCollege,
                      child: Text(
                        _editingCollege == null
                            ? 'Add College'
                            : 'Update College',
                      ),
                    ),
                  ),
                  if (_editingCollege != null) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _clearCollegeForm,
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (_isCollegeLoading)
                const LinearProgressIndicator(minHeight: 2),
              if (!_isCollegeLoading && _colleges.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No colleges added yet.'),
                ),
              if (_colleges.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._colleges.map(
                  (college) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(college.name),
                    subtitle: Text(
                      college.isActive ? 'Active' : 'Hidden',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip:
                              college.isActive ? 'Hide' : 'Activate',
                          onPressed: () => _toggleCollege(college),
                          icon: Icon(
                            college.isActive
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => _editCollege(college),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => _deleteCollege(college),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AdminCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Add Subject',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<Semester>(
                key: ValueKey(
                  'subject_semester_${_subjectSemester?.id ?? 'none'}',
                ),
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
        _AdminCard(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Add Chapter',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<Subject>(
                key: ValueKey(
                  'chapter_subject_${chapterSubjectValue?.id ?? 'none'}',
                ),
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
                    controller: _chapterSubtopics,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Subtopics (one per line)',
                      hintText: 'e.g. CPU | ALU, CU, Registers',
                    ),
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
    final noteSemesterValue = _matchSemester(_semesters, _noteSemester);
    final noteSubjects = _noteSemester?.subjects ?? const <Subject>[];
    final noteSubjectValue = _matchSubject(noteSubjects, _noteSubject);
    final noteChapterValue = _matchChapter(_noteChapters, _noteChapter);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminCard(
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
                        : Text(
                            _noteTitle.text.trim().isNotEmpty ||
                                    _noteDetailed.text.trim().isNotEmpty
                                ? 'Regenerate'
                                : 'AI Draft',
                          ),
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
                    ?.copyWith(color: Colors.white70),
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
                  key: ValueKey(
                    'note_semester_${noteSemesterValue?.id ?? 'none'}',
                  ),
                  initialValue: noteSemesterValue,
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
                  key: ValueKey(
                    'note_subject_${noteSubjectValue?.id ?? 'none'}',
                  ),
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
                    key: ValueKey(
                      'note_chapter_${noteChapterValue?.id ?? 'none'}',
                    ),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBulkNotesUploading
                            ? null
                            : _bulkUploadNotes,
                        icon: _isBulkNotesUploading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: const Text('Bulk Upload Files'),
                      ),
                    ),
                  ],
                ),
                if (_bulkNotesMessages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _bulkNotesMessages.take(3).join('\n'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
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
            (note) {
              final previewText = note.detailedAnswer.trim().isNotEmpty
                  ? note.detailedAnswer.trim()
                  : note.shortAnswer.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showAdminNoteDetails(note),
                    child: _AdminCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: MathText(
                                  text: note.title,
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.12),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
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
                          if ((note.fileUrl ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.attach_file_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Attachment available',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (previewText.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            MathText(
                              text: previewText,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
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
              );
            },
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
              child: _AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MathText(
                            text: submission.title,
                            textStyle: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
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
                          ?.copyWith(color: Colors.white70),
                    ),
                    if ((submission.userName ?? '').isNotEmpty ||
                        (submission.collegeName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if ((submission.userName ?? '').isNotEmpty)
                            submission.userName!,
                          if ((submission.collegeName ?? '').isNotEmpty)
                            submission.collegeName!,
                        ].join(' • '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white60),
                      ),
                    ],
                    if (submission.shortAnswer.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MathText(
                        text: submission.shortAnswer,
                        textStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
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
                    if ((submission.fileUrl ?? '').isNotEmpty) ...[
                      if (_isImageUrl(submission.fileUrl!)) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            submission.fileUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 160,
                                alignment: Alignment.center,
                                color: const Color(0xFF0B1220),
                                child: const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 160,
                              alignment: Alignment.center,
                              color: const Color(0xFF0B1220),
                              child: Text(
                                'Image unavailable',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_file,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Attachment submitted',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _copyToClipboard(submission.fileUrl!),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                            ),
                            child: const Text('Copy link'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Pending Community Questions',
          actionLabel:
              _isCommunityPendingLoading ? null : 'Refresh',
          onAction: _isCommunityPendingLoading
              ? null
              : _loadPendingCommunityQuestions,
        ),
        const SizedBox(height: 12),
        if (_isCommunityPendingLoading)
          const Center(child: CircularProgressIndicator())
        else if (_communityPendingError != null)
          Text(
            _communityPendingError!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.danger),
          )
        else if (_pendingCommunityQuestions.isEmpty)
          const Text('No pending community questions.')
        else
          ..._pendingCommunityQuestions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AdminCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MathText(
                            text: question.question,
                            textStyle: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        if (_reviewingCommunityQuestionId == question.id)
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          TextButton(
                            onPressed: () =>
                                _approveCommunityQuestion(question),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _rejectCommunityQuestion(question),
                            child: const Text('Reject'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      question.subjectName,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    if ((question.aiReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MathText(
                        text: 'AI: ${question.aiReason}',
                        textStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
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
    final qaSemesterValue = _matchSemester(_semesters, _qaSemester);
    final qaSubjects = _qaSemester?.subjects ?? const <Subject>[];
    final qaSubjectValue = _matchSubject(qaSubjects, _qaSubject);
    final qaChapterValue = _matchChapter(_qaChapters, _qaChapter);
    final qaQuizValue = _matchQuiz(_qaQuizzes, _qaSelectedQuiz);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _AdminCard(
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
                key: ValueKey(
                  'qa_semester_${qaSemesterValue?.id ?? 'none'}',
                ),
                initialValue: qaSemesterValue,
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
                key: ValueKey(
                  'qa_subject_${qaSubjectValue?.id ?? 'none'}',
                ),
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
                key: ValueKey(
                  'qa_chapter_${qaChapterValue?.id ?? 'none'}',
                ),
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
        _AdminCard(
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
                      : Text(
                          _questionPrompt.text.trim().isNotEmpty
                              ? 'Regenerate'
                              : 'AI Suggest',
                        ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('question_kind_$_questionKind'),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isBulkQuestionsUploading
                          ? null
                          : _bulkUploadQuestions,
                      icon: _isBulkQuestionsUploading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: const Text('Bulk Upload Questions'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Upload .txt/.csv (one question per line) or PDF/DOCX/PPTX for AI extraction. '
                'Optional format: prompt | marks | year.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              if (_bulkQuestionMessages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _bulkQuestionMessages.take(3).join('\n'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AdminCard(
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
        _AdminCard(
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
                key: ValueKey('quiz_type_$_quizType'),
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
                key: ValueKey('quiz_difficulty_$_quizDifficulty'),
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
        _AdminCard(
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
                      : Text(
                          _quizQuestionPrompt.text.trim().isNotEmpty
                              ? 'Regenerate'
                              : 'AI Generate',
                        ),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [
              if (_qaQuizzes.isEmpty)
                const Text('Create a quiz first for this chapter.')
              else
                DropdownButtonFormField<Quiz>(
                  key: ValueKey('qa_quiz_${qaQuizValue?.id ?? 'none'}'),
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

class _AdminCard extends StatelessWidget {
  final Widget child;

  const _AdminCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.4),
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
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
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
