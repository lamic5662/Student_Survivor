import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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
  List<Chapter> _qaChapters = const [];
  List<Quiz> _qaQuizzes = const [];
  Quiz? _qaSelectedQuiz;
  bool _noteChapterWise = true;
  bool _isUploadingSyllabus = false;
  List<String> _syllabusMessages = const [];
  List<String> _syllabusUnmatched = const [];
  List<String> _syllabusAmbiguous = const [];
  PlatformFile? _noteAttachment;
  PlatformFile? _pastPaperFile;
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
      return;
    }
    final chapters = await _adminService.fetchChaptersForSubject(subject.id);
    setState(() {
      _noteChapters = chapters;
      _noteChapter = chapters.isNotEmpty ? chapters.first : null;
    });
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
    await _refreshProfileContent();
    _show('Note added.');
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
              Text(
                'Publish Note',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Only title and content are required. Short answer and tags '
                'are optional.',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _noteChapterWise,
                onChanged: (value) {
                  setState(() {
                    _noteChapterWise = value;
                  });
                },
                title: const Text('Chapter-wise notes'),
                subtitle:
                    const Text('Turn off to add notes directly to subject.'),
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
            title: Text(
              'Publish Question',
              style: Theme.of(context).textTheme.titleMedium,
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
            title: Text(
              'Add Quiz Question',
              style: Theme.of(context).textTheme.titleMedium,
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
