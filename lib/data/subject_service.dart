import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectService {
  final SupabaseClient _client;

  SubjectService(this._client);

  Future<List<Semester>> fetchSemesters() async {
    final data = await _client
        .from('semesters')
        .select('id, name, code, subjects(id,name,code,accent_color,syllabus_url)')
        .order('sort_order');

    return (data as List<dynamic>).map(_semesterFromMap).toList();
  }

  Future<List<Subject>> fetchUserSubjects({bool includeContent = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }

    final select = includeContent
        ? 'subject:subjects(id,name,code,accent_color,syllabus_url,'
            'past_papers(id,title,year,file_url),'
            'chapters(id,title,'
            'notes(id,title,short_answer,detailed_answer,file_url),'
            'questions(id,prompt,marks,kind,year),'
            'quizzes(id,title,quiz_type,difficulty,question_count,duration_minutes)'
            '))'
        : 'subject:subjects(id,name,code,accent_color,syllabus_url)';

    final data = await _client
        .from('user_subjects')
        .select(select)
        .eq('user_id', user.id);

    return (data as List<dynamic>)
        .map((row) => row['subject'])
        .where((value) => value != null)
        .map(_subjectFromMap)
        .toList();
  }

  Future<List<Subject>> fetchSubjectsForSemester(
    String semesterId, {
    bool includeContent = false,
  }) async {
    if (semesterId.isEmpty) {
      return [];
    }

    final select = includeContent
        ? 'id,name,code,accent_color,syllabus_url,'
            'past_papers(id,title,year,file_url),'
            'chapters(id,title,'
            'notes(id,title,short_answer,detailed_answer,file_url),'
            'questions(id,prompt,marks,kind,year),'
            'quizzes(id,title,quiz_type,difficulty,question_count,duration_minutes)'
            ')'
        : 'id,name,code,accent_color,syllabus_url';

    final data = await _client
        .from('subjects')
        .select(select)
        .eq('semester_id', semesterId)
        .order('sort_order');

    return (data as List<dynamic>).map(_subjectFromMap).toList();
  }

  Semester _semesterFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final subjects = (map['subjects'] as List<dynamic>? ?? [])
        .map(_subjectFromMap)
        .toList();

    return Semester(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Semester',
      subjects: subjects,
    );
  }

  Subject _subjectFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final chapters = (map['chapters'] as List<dynamic>? ?? [])
        .map(_chapterFromMap)
        .toList();
    final pastPapers = (map['past_papers'] as List<dynamic>? ?? [])
        .map(_pastPaperFromMap)
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

  Chapter _chapterFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final notes = (map['notes'] as List<dynamic>? ?? [])
        .map(_noteFromMap)
        .toList();
    final quizzes = (map['quizzes'] as List<dynamic>? ?? [])
        .map(_quizFromMap)
        .toList();
    final questions = (map['questions'] as List<dynamic>? ?? [])
        .map(_questionFromMap)
        .toList();
    final important = <Question>[];
    final past = <Question>[];
    for (final question in questions) {
      if (question.kind == 'past') {
        past.add(question);
      } else {
        important.add(question);
      }
    }

    return Chapter(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Chapter',
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: quizzes,
    );
  }

  Note _noteFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return Note(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Note',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      fileUrl: map['file_url']?.toString(),
    );
  }

  Question _questionFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return Question(
      id: map['id']?.toString() ?? '',
      prompt: map['prompt']?.toString() ?? '',
      marks: (map['marks'] as num?)?.toInt() ?? 5,
      kind: map['kind']?.toString() ?? 'important',
      year: (map['year'] as num?)?.toInt(),
    );
  }

  PastPaper _pastPaperFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return PastPaper(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Past Paper',
      year: (map['year'] as num?)?.toInt(),
      fileUrl: map['file_url']?.toString() ?? '',
    );
  }

  Quiz _quizFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return Quiz(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Quiz',
      type: parseQuizType(map['quiz_type']?.toString()),
      difficulty: parseQuizDifficulty(map['difficulty']?.toString()),
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      duration:
          Duration(minutes: (map['duration_minutes'] as num?)?.toInt() ?? 10),
    );
  }
}
