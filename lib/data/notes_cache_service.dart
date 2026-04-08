import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class NotesCacheService {
  static const String _boxName = 'notes_cache';
  static const String _userSubjectsKey = 'user_subjects_full_v1';
  static const String _semestersKey = 'semesters_basic_v1';
  static bool _initialized = false;

  Future<Box> _openBox() async {
    if (!_initialized) {
      await Hive.initFlutter();
      _initialized = true;
    }
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return Hive.openBox(_boxName);
  }

  Future<void> cacheUserSubjects(List<Subject> subjects) async {
    final box = await _openBox();
    final payload = subjects.map(_subjectToMap).toList();
    await box.put(_userSubjectsKey, payload);
    await box.put(
      '${_userSubjectsKey}_updated',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> cacheSemesters(List<Semester> semesters) async {
    final box = await _openBox();
    final payload = semesters.map(_semesterToMap).toList();
    await box.put(_semestersKey, payload);
    await box.put(
      '${_semestersKey}_updated',
      DateTime.now().toIso8601String(),
    );
  }

  Future<List<Semester>> loadSemesters() async {
    final box = await _openBox();
    final raw = box.get(_semestersKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((map) => _semesterFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<List<Subject>> loadUserSubjects() async {
    final box = await _openBox();
    final raw = box.get(_userSubjectsKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((map) => _subjectFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<void> cacheSemesterSubjects(
    String semesterId,
    List<Subject> subjects, {
    bool includeContent = false,
  }) async {
    if (semesterId.isEmpty) return;
    final key = _semesterKey(semesterId, includeContent);
    final box = await _openBox();
    final payload = subjects.map(_subjectToMap).toList();
    await box.put(key, payload);
    await box.put('${key}_updated', DateTime.now().toIso8601String());
  }

  Future<List<Subject>> loadSemesterSubjects(
    String semesterId, {
    bool includeContent = false,
  }) async {
    if (semesterId.isEmpty) return [];
    final key = _semesterKey(semesterId, includeContent);
    final box = await _openBox();
    final raw = box.get(key);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((map) => _subjectFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<void> cacheUserNotes(String chapterId, List<UserNote> notes) async {
    if (chapterId.isEmpty) return;
    final box = await _openBox();
    final payload = notes.map(_userNoteToMap).toList();
    await box.put(_userNotesKey(chapterId), payload);
    await box.put(
      '${_userNotesKey(chapterId)}_updated',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> cacheUserNotesForSubject(List<UserNote> notes) async {
    final grouped = <String, List<UserNote>>{};
    for (final note in notes) {
      final chapterId = note.chapterId;
      if (chapterId == null || chapterId.isEmpty) continue;
      grouped.putIfAbsent(chapterId, () => []).add(note);
    }
    for (final entry in grouped.entries) {
      await cacheUserNotes(entry.key, entry.value);
    }
  }

  Future<List<UserNote>> loadUserNotes(String chapterId) async {
    if (chapterId.isEmpty) return [];
    final box = await _openBox();
    final raw = box.get(_userNotesKey(chapterId));
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((map) => _userNoteFromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  Future<void> cacheAiDraft({
    required String subjectId,
    required String chapterId,
    required NoteDraft draft,
  }) async {
    if (subjectId.isEmpty || chapterId.isEmpty) return;
    final box = await _openBox();
    await box.put(_aiDraftKey(subjectId, chapterId), {
      'title': draft.title,
      'short_answer': draft.shortAnswer,
      'detailed_answer': draft.detailedAnswer,
    });
    await box.put(
      '${_aiDraftKey(subjectId, chapterId)}_updated',
      DateTime.now().toIso8601String(),
    );
  }

  Future<NoteDraft?> loadAiDraft({
    required String subjectId,
    required String chapterId,
  }) async {
    if (subjectId.isEmpty || chapterId.isEmpty) return null;
    final box = await _openBox();
    final raw = box.get(_aiDraftKey(subjectId, chapterId));
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final title = map['title']?.toString() ?? '';
    final shortAnswer = map['short_answer']?.toString() ?? '';
    final detailedAnswer = map['detailed_answer']?.toString() ?? '';
    if (title.isEmpty || shortAnswer.isEmpty || detailedAnswer.isEmpty) {
      return null;
    }
    return NoteDraft(
      title: title,
      shortAnswer: shortAnswer,
      detailedAnswer: detailedAnswer,
    );
  }

  String _semesterKey(String semesterId, bool includeContent) {
    return 'semester_${semesterId}_${includeContent ? 'full' : 'basic'}_v1';
  }

  String _userNotesKey(String chapterId) => 'user_notes_$chapterId';

  String _aiDraftKey(String subjectId, String chapterId) =>
      'ai_draft_${subjectId}_$chapterId';

  Map<String, dynamic> _semesterToMap(Semester semester) {
    return {
      'id': semester.id,
      'name': semester.name,
      'subjects': semester.subjects.map(_subjectToMap).toList(),
    };
  }

  Semester _semesterFromMap(Map<String, dynamic> map) {
    final subjects = (map['subjects'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _subjectFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    return Semester(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Semester',
      subjects: subjects,
    );
  }

  Map<String, dynamic> _subjectToMap(Subject subject) {
    return {
      'id': subject.id,
      'name': subject.name,
      'code': subject.code,
      'accent_color': _colorToHex(subject.accentColor),
      'syllabus_url': subject.syllabusUrl,
      'past_papers': subject.pastPapers.map(_pastPaperToMap).toList(),
      'chapters': subject.chapters.map(_chapterToMap).toList(),
    };
  }

  Subject _subjectFromMap(Map<String, dynamic> map) {
    final chapters = (map['chapters'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _chapterFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    final pastPapers = (map['past_papers'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _pastPaperFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    return Subject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Subject',
      code: map['code']?.toString() ?? '',
      accentColor: parseAccentColor(map['accent_color']?.toString()),
      syllabusUrl: map['syllabus_url']?.toString(),
      pastPapers: pastPapers,
      chapters: chapters,
    );
  }

  Map<String, dynamic> _chapterToMap(Chapter chapter) {
    return {
      'id': chapter.id,
      'title': chapter.title,
      'notes': chapter.notes.map(_noteToMap).toList(),
      'important_questions':
          chapter.importantQuestions.map(_questionToMap).toList(),
      'past_questions': chapter.pastQuestions.map(_questionToMap).toList(),
      'quizzes': chapter.quizzes.map(_quizToMap).toList(),
      'subtopics': chapter.subtopics.map(_chapterTopicToMap).toList(),
    };
  }

  Chapter _chapterFromMap(Map<String, dynamic> map) {
    final subtopics = (map['subtopics'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _chapterTopicFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    final notes = (map['notes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _noteFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    final important = (map['important_questions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _questionFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    final past = (map['past_questions'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _questionFromMap(Map<String, dynamic>.from(entry)))
        .toList();
    final quizzes = (map['quizzes'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((entry) => _quizFromMap(Map<String, dynamic>.from(entry)))
        .toList();

    return Chapter(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Chapter',
      subtopics: subtopics,
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: quizzes,
    );
  }

  Map<String, dynamic> _chapterTopicToMap(ChapterTopic topic) {
    return {
      'id': topic.id,
      'title': topic.title,
      'summary': topic.summary,
      'sort_order': topic.sortOrder,
    };
  }

  ChapterTopic _chapterTopicFromMap(Map<String, dynamic> map) {
    return ChapterTopic(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _noteToMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'short_answer': note.shortAnswer,
      'detailed_answer': note.detailedAnswer,
      'file_url': note.fileUrl,
    };
  }

  Note _noteFromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      fileUrl: map['file_url']?.toString(),
    );
  }

  Map<String, dynamic> _userNoteToMap(UserNote note) {
    return {
      'id': note.id,
      'title': note.title,
      'short_answer': note.shortAnswer,
      'detailed_answer': note.detailedAnswer,
      'chapter_id': note.chapterId,
    };
  }

  UserNote _userNoteFromMap(Map<String, dynamic> map) {
    return UserNote(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      chapterId: map['chapter_id']?.toString(),
    );
  }

  Map<String, dynamic> _questionToMap(Question question) {
    return {
      'id': question.id,
      'prompt': question.prompt,
      'marks': question.marks,
      'kind': question.kind,
      'year': question.year,
    };
  }

  Question _questionFromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id']?.toString() ?? '',
      prompt: map['prompt']?.toString() ?? '',
      marks: (map['marks'] as num?)?.toInt() ?? 5,
      kind: map['kind']?.toString() ?? 'important',
      year: (map['year'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> _quizToMap(Quiz quiz) {
    return {
      'id': quiz.id,
      'title': quiz.title,
      'type': quiz.type.name,
      'difficulty': quiz.difficulty.name,
      'question_count': quiz.questionCount,
      'duration_minutes': quiz.duration.inMinutes,
    };
  }

  Quiz _quizFromMap(Map<String, dynamic> map) {
    return Quiz(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      type: parseQuizType(map['type']?.toString()),
      difficulty: parseQuizDifficulty(map['difficulty']?.toString()),
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      duration: Duration(
        minutes: (map['duration_minutes'] as num?)?.toInt() ?? 10,
      ),
    );
  }

  Map<String, dynamic> _pastPaperToMap(PastPaper paper) {
    return {
      'id': paper.id,
      'title': paper.title,
      'year': paper.year,
      'file_url': paper.fileUrl,
    };
  }

  PastPaper _pastPaperFromMap(Map<String, dynamic> map) {
    return PastPaper(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      fileUrl: map['file_url']?.toString() ?? '',
      year: (map['year'] as num?)?.toInt(),
    );
  }

  String _colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).substring(2).padLeft(6, '0')}';
  }
}
