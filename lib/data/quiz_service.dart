import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizQuestionItem {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? topic;
  final String? difficulty;
  final String? explanation;

  const QuizQuestionItem({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.topic,
    this.difficulty,
    this.explanation,
  });
}

class QuizContext {
  final Quiz quiz;
  final Subject subject;
  final Chapter chapter;

  const QuizContext({
    required this.quiz,
    required this.subject,
    required this.chapter,
  });
}

class QuizService {
  final SupabaseClient _client;

  QuizService(this._client);

  Future<List<QuizCardItem>> fetchQuizCardsForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }

    final profile = await _client
        .from('profiles')
        .select('semester_id')
        .eq('id', user.id)
        .maybeSingle();
    final semesterId = profile?['semester_id']?.toString() ?? '';
    if (semesterId.isEmpty) {
      return [];
    }

    final subjectRows = await _client
        .from('subjects')
        .select('id,name,code,accent_color')
        .eq('semester_id', semesterId)
        .order('sort_order');

    final subjectById = <String, Subject>{};
    for (final row in subjectRows as List<dynamic>) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      subjectById[id] = Subject(
        id: id,
        name: row['name']?.toString() ?? 'Subject',
        code: row['code']?.toString() ?? '',
        accentColor: parseAccentColor(row['accent_color']?.toString()),
        pastPapers: const [],
        chapters: const [],
      );
    }

    final subjectIds = subjectById.keys.toList();
    if (subjectIds.isEmpty) {
      return [];
    }

    final chapterRows = await _client
        .from('chapters')
        .select('id, subject_id')
        .inFilter('subject_id', subjectIds);

    final subjectByChapter = <String, Subject>{};
    for (final row in chapterRows as List<dynamic>) {
      final chapterId = row['id']?.toString() ?? '';
      final subjectId = row['subject_id']?.toString() ?? '';
      final subject = subjectById[subjectId];
      if (chapterId.isEmpty || subject == null) {
        continue;
      }
      subjectByChapter[chapterId] = subject;
    }

    final chapterIds = subjectByChapter.keys.toList();
    if (chapterIds.isEmpty) {
      return [];
    }

    final quizRows = await _client
        .from('quizzes')
        .select(
          'id,title,quiz_type,difficulty,question_count,duration_minutes,chapter_id',
        )
        .inFilter('chapter_id', chapterIds);

    final items = <QuizCardItem>[];
    for (final row in quizRows as List<dynamic>) {
      final chapterId = row['chapter_id']?.toString() ?? '';
      final subject = subjectByChapter[chapterId];
      if (subject == null) {
        continue;
      }
      final quiz = Quiz(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Quiz',
        type: parseQuizType(row['quiz_type']?.toString()),
        difficulty: parseQuizDifficulty(row['difficulty']?.toString()),
        questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
        duration: Duration(
          minutes: (row['duration_minutes'] as num?)?.toInt() ?? 10,
        ),
      );
      items.add(QuizCardItem(quiz: quiz, subject: subject));
    }
    return items;
  }

  Future<List<QuizQuestionItem>> fetchQuestions(String quizId) async {
    final data = await _client
        .from('quiz_questions')
        .select('id,prompt,options,correct_index,topic,explanation')
        .eq('quiz_id', quizId)
        .order('created_at');

    return (data as List<dynamic>).map((row) {
      final optionsRaw = row['options'] as List<dynamic>? ?? [];
      return QuizQuestionItem(
        id: row['id']?.toString() ?? '',
        prompt: row['prompt']?.toString() ?? '',
        options: optionsRaw.map((option) => option.toString()).toList(),
        correctIndex: (row['correct_index'] as num?)?.toInt() ?? -1,
        topic: row['topic']?.toString(),
        difficulty: null,
        explanation: row['explanation']?.toString(),
      );
    }).toList();
  }

  Future<QuizContext?> fetchQuizContext(String quizId) async {
    if (quizId.isEmpty) return null;
    final data = await _client
        .from('quizzes')
        .select(
          'id,title,quiz_type,difficulty,question_count,duration_minutes,'
          'chapter:chapters(id,title,subject:subjects(id,name,code,accent_color))',
        )
        .eq('id', quizId)
        .maybeSingle();

    if (data == null) {
      return null;
    }
    final chapterMap = data['chapter'] as Map<String, dynamic>?;
    if (chapterMap == null) {
      return null;
    }
    final subjectMap = chapterMap['subject'] as Map<String, dynamic>?;
    if (subjectMap == null) {
      return null;
    }

    final subject = Subject(
      id: subjectMap['id']?.toString() ?? '',
      name: subjectMap['name']?.toString() ?? 'Subject',
      code: subjectMap['code']?.toString() ?? '',
      accentColor: parseAccentColor(subjectMap['accent_color']?.toString()),
      pastPapers: const [],
      chapters: const [],
    );
    final chapter = Chapter(
      id: chapterMap['id']?.toString() ?? '',
      title: chapterMap['title']?.toString() ?? 'Chapter',
      notes: const [],
      importantQuestions: const [],
      pastQuestions: const [],
      quizzes: const [],
    );
    final quiz = Quiz(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Quiz',
      type: parseQuizType(data['quiz_type']?.toString()),
      difficulty: parseQuizDifficulty(data['difficulty']?.toString()),
      questionCount: (data['question_count'] as num?)?.toInt() ?? 0,
      duration: Duration(
        minutes: (data['duration_minutes'] as num?)?.toInt() ?? 10,
      ),
    );

    return QuizContext(quiz: quiz, subject: subject, chapter: chapter);
  }

  Future<String> startAttempt(String quizId) async {
    final data = await _client.rpc('start_quiz_attempt', params: {
      'p_quiz_id': quizId,
    });
    return data.toString();
  }

  Future<QuizAttemptResult> finishAttempt({
    required String attemptId,
    required int score,
    required int durationSeconds,
    required List<Map<String, dynamic>> answers,
  }) async {
    final data = await _client.rpc('finish_quiz_attempt', params: {
      'p_attempt_id': attemptId,
      'p_score': score,
      'p_duration_seconds': durationSeconds,
      'p_answers': answers,
    });

    final result = (data as List<dynamic>).isNotEmpty
        ? data.first as Map<String, dynamic>
        : <String, dynamic>{};

    final passed = result['passed'] as bool? ?? false;
    final xp = (result['xp_earned'] as num?)?.toInt() ?? 0;
    final topics = (result['weak_topics'] as List<dynamic>? ?? [])
        .map((topic) => topic.toString())
        .toList();

    return QuizAttemptResult(passed: passed, xpEarned: xp, weakTopics: topics);
  }

  Future<List<Note>> fetchRecommendedNotes() async {
    final data = await _client
        .from('recommendations')
        .select('note:notes(id,title,short_answer,detailed_answer,file_url)')
        .order('created_at', ascending: false)
        .limit(5);

    return (data as List<dynamic>)
        .map((row) => row['note'])
        .where((note) => note != null)
        .map((note) {
          final map = note as Map<String, dynamic>;
          return Note(
            id: map['id']?.toString() ?? '',
            title: map['title']?.toString() ?? '',
            shortAnswer: map['short_answer']?.toString() ?? '',
            detailedAnswer: map['detailed_answer']?.toString() ?? '',
            fileUrl: map['file_url']?.toString(),
          );
        })
        .toList();
  }

  Future<List<Question>> fetchImportantQuestionsForQuiz(String quizId) async {
    final quiz = await _client
        .from('quizzes')
        .select('chapter_id')
        .eq('id', quizId)
        .maybeSingle();

    final chapterId = quiz?['chapter_id']?.toString();
    if (chapterId == null || chapterId.isEmpty) {
      return [];
    }

    final questions = await _client
        .from('questions')
        .select('id,prompt,marks,kind,year')
        .eq('chapter_id', chapterId)
        .eq('kind', 'important')
        .order('created_at');

    return (questions as List<dynamic>)
        .map((row) => Question(
              id: row['id']?.toString() ?? '',
              prompt: row['prompt']?.toString() ?? '',
              marks: (row['marks'] as num?)?.toInt() ?? 5,
              kind: row['kind']?.toString() ?? 'important',
              year: (row['year'] as num?)?.toInt(),
            ))
        .toList();
  }
}

class QuizAttemptResult {
  final bool passed;
  final int xpEarned;
  final List<String> weakTopics;

  const QuizAttemptResult({
    required this.passed,
    required this.xpEarned,
    required this.weakTopics,
  });
}
