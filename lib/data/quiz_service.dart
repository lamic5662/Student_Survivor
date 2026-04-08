import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
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

  static const String _quizCardsKey = 'quiz_cards_v1';
  static const String _quizQuestionsPrefix = 'quiz_questions_v1_';
  static const String _quizContextPrefix = 'quiz_context_v1_';

  Future<List<QuizCardItem>> fetchQuizCardsForUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    final userId = user.id;

    try {
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
      await _cacheQuizCards(userId, items);
      return items;
    } catch (_) {
      final cached = await _loadCachedQuizCards(userId);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<QuizQuestionItem>> fetchQuestions(String quizId) async {
    if (quizId.isEmpty) return [];
    try {
      final data = await _client
          .from('quiz_questions')
          .select('id,prompt,options,correct_index,topic,explanation')
          .eq('quiz_id', quizId)
          .order('created_at');

      final items = (data as List<dynamic>).map((row) {
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
      await _cacheQuizQuestions(quizId, items);
      return items;
    } catch (_) {
      final cached = await _loadCachedQuizQuestions(quizId);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<QuizContext?> fetchQuizContext(String quizId) async {
    if (quizId.isEmpty) return null;
    try {
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

      final context = QuizContext(quiz: quiz, subject: subject, chapter: chapter);
      await _cacheQuizContext(quizId, context);
      return context;
    } catch (_) {
      final cached = await _loadCachedQuizContext(quizId);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
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

    unawaited(
      _updateChapterProgress(
        attemptId: attemptId,
        score: score,
        durationSeconds: durationSeconds,
      ),
    );

    return QuizAttemptResult(passed: passed, xpEarned: xp, weakTopics: topics);
  }

  Future<void> _updateChapterProgress({
    required String attemptId,
    required int score,
    required int durationSeconds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final attempt = await _client
        .from('quiz_attempts')
        .select('quiz_id,total')
        .eq('id', attemptId)
        .maybeSingle();
    final quizId = attempt?['quiz_id']?.toString();
    if (quizId == null || quizId.isEmpty) return;
    final total = (attempt?['total'] as num?)?.toInt() ?? 0;

    final quiz = await _client
        .from('quizzes')
        .select('chapter_id,difficulty,duration_minutes')
        .eq('id', quizId)
        .maybeSingle();
    final chapterId = quiz?['chapter_id']?.toString();
    if (chapterId == null || chapterId.isEmpty) return;

    final difficulty = quiz?['difficulty']?.toString() ?? 'medium';
    final durationMinutes = (quiz?['duration_minutes'] as num?)?.toInt();
    final delta = _ruleBasedProgressDelta(
      score: score,
      total: total,
      durationSeconds: durationSeconds,
      difficulty: difficulty,
      durationMinutes: durationMinutes,
    );
    if (delta <= 0) return;

    final existing = await _client
        .from('user_chapter_progress')
        .select('completion_percent')
        .eq('chapter_id', chapterId)
        .maybeSingle();
    final current = (existing?['completion_percent'] as num?)?.toDouble() ?? 0;
    final updated = (current + delta).clamp(0, 100);

    await _client.from('user_chapter_progress').upsert({
      'user_id': user.id,
      'chapter_id': chapterId,
      'completion_percent': updated,
      'last_activity_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,chapter_id');
  }

  Future<void> _cacheQuizCards(
    String userId,
    List<QuizCardItem> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items
          .map(
            (item) => {
              'quiz': _quizToMap(item.quiz),
              'subject': _subjectToMap(item.subject),
            },
          )
          .toList();
      await prefs.setString(
        '${userId}_$_quizCardsKey',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<List<QuizCardItem>> _loadCachedQuizCards(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${userId}_$_quizCardsKey');
      if (raw == null || raw.isEmpty) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map>()
          .map((entry) {
            final map = Map<String, dynamic>.from(entry);
            final quizMap = map['quiz'] as Map<String, dynamic>?;
            final subjectMap = map['subject'] as Map<String, dynamic>?;
            if (quizMap == null || subjectMap == null) return null;
            return QuizCardItem(
              quiz: _quizFromMap(Map<String, dynamic>.from(quizMap)),
              subject:
                  _subjectFromMap(Map<String, dynamic>.from(subjectMap)),
            );
          })
          .whereType<QuizCardItem>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheQuizQuestions(
    String quizId,
    List<QuizQuestionItem> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = items
          .map(
            (item) => {
              'id': item.id,
              'prompt': item.prompt,
              'options': item.options,
              'correct_index': item.correctIndex,
              'topic': item.topic,
              'explanation': item.explanation,
            },
          )
          .toList();
      await prefs.setString(
        '$_quizQuestionsPrefix$quizId',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<List<QuizQuestionItem>> _loadCachedQuizQuestions(
    String quizId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_quizQuestionsPrefix$quizId');
      if (raw == null || raw.isEmpty) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map>()
          .map((entry) {
            final map = Map<String, dynamic>.from(entry);
            final optionsRaw = map['options'] as List<dynamic>? ?? [];
            return QuizQuestionItem(
              id: map['id']?.toString() ?? '',
              prompt: map['prompt']?.toString() ?? '',
              options: optionsRaw.map((option) => option.toString()).toList(),
              correctIndex: (map['correct_index'] as num?)?.toInt() ?? -1,
              topic: map['topic']?.toString(),
              difficulty: null,
              explanation: map['explanation']?.toString(),
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheQuizContext(String quizId, QuizContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'quiz': _quizToMap(context.quiz),
        'subject': _subjectToMap(context.subject),
        'chapter': _chapterToMap(context.chapter),
      };
      await prefs.setString(
        '$_quizContextPrefix$quizId',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<QuizContext?> _loadCachedQuizContext(String quizId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_quizContextPrefix$quizId');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final quizMap = map['quiz'] as Map<String, dynamic>?;
      final subjectMap = map['subject'] as Map<String, dynamic>?;
      final chapterMap = map['chapter'] as Map<String, dynamic>?;
      if (quizMap == null || subjectMap == null || chapterMap == null) {
        return null;
      }
      return QuizContext(
        quiz: _quizFromMap(Map<String, dynamic>.from(quizMap)),
        subject: _subjectFromMap(Map<String, dynamic>.from(subjectMap)),
        chapter: _chapterFromMap(Map<String, dynamic>.from(chapterMap)),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _quizToMap(Quiz quiz) {
    return {
      'id': quiz.id,
      'title': quiz.title,
      'quiz_type': quiz.type.name,
      'difficulty': quiz.difficulty.name,
      'question_count': quiz.questionCount,
      'duration_minutes': quiz.duration.inMinutes,
    };
  }

  Quiz _quizFromMap(Map<String, dynamic> map) {
    return Quiz(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Quiz',
      type: parseQuizType(map['quiz_type']?.toString()),
      difficulty: parseQuizDifficulty(map['difficulty']?.toString()),
      questionCount: (map['question_count'] as num?)?.toInt() ?? 0,
      duration: Duration(
        minutes: (map['duration_minutes'] as num?)?.toInt() ?? 10,
      ),
    );
  }

  Map<String, dynamic> _subjectToMap(Subject subject) {
    return {
      'id': subject.id,
      'name': subject.name,
      'code': subject.code,
      'accent_color': _colorToHex(subject.accentColor.toARGB32()),
    };
  }

  Subject _subjectFromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Subject',
      code: map['code']?.toString() ?? '',
      accentColor: parseAccentColor(map['accent_color']?.toString()),
      pastPapers: const [],
      chapters: const [],
    );
  }

  Map<String, dynamic> _chapterToMap(Chapter chapter) {
    return {
      'id': chapter.id,
      'title': chapter.title,
    };
  }

  Chapter _chapterFromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Chapter',
      notes: const [],
      importantQuestions: const [],
      pastQuestions: const [],
      quizzes: const [],
    );
  }

  String _colorToHex(int value) {
    final rgb = value & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  double _ruleBasedProgressDelta({
    required int score,
    required int total,
    required int durationSeconds,
    required String difficulty,
    int? durationMinutes,
  }) {
    if (total <= 0) return 0;
    final accuracy = (score / total).clamp(0, 1);
    var delta = 0.0;

    // Base effort for completing an attempt.
    delta += 2;

    // Accuracy bonus (up to 20).
    delta += accuracy * 20;

    // Difficulty bonus.
    switch (difficulty.toLowerCase()) {
      case 'hard':
        delta += 9;
        break;
      case 'medium':
        delta += 6;
        break;
      case 'easy':
        delta += 3;
        break;
      default:
        delta += 5;
    }

    // Speed bonus.
    if (durationMinutes != null &&
        durationMinutes > 0 &&
        durationSeconds > 0) {
      final expected = durationMinutes * 60;
      final ratio = durationSeconds / expected;
      if (ratio <= 0.6) {
        delta += 4;
      } else if (ratio <= 0.8) {
        delta += 2;
      }
    }

    // Mastery streak bonus.
    if (accuracy >= 0.9) {
      delta += 4;
    } else if (accuracy >= 0.75) {
      delta += 2;
    }

    // Low score penalty.
    if (accuracy < 0.4) {
      delta -= 4;
    }

    if (delta < 0) {
      return 0;
    }
    return delta.clamp(0, 25);
  }

  Future<List<Note>> fetchRecommendedNotes() async {
    final data = await _client
        .from('recommendations')
        .select('note:notes(id,title,short_answer,detailed_answer,file_url)')
        .order('created_at', ascending: false)
        .limit(5);

    final notes = (data as List<dynamic>)
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
    if (notes.isNotEmpty) {
      return notes;
    }

    return _fallbackRecommendations();
  }

  Future<List<Note>> _fallbackRecommendations() async {
    final results = <Note>[];
    final seen = <String>{};

    final weak = await _client
        .from('weak_topics')
        .select('topic')
        .order('severity', ascending: false)
        .limit(5);
    final topics = (weak as List<dynamic>)
        .map((row) => row['topic']?.toString() ?? '')
        .where((topic) => topic.trim().isNotEmpty)
        .toList();
    if (topics.isNotEmpty) {
      final orFilters = topics
          .map(_sanitizeTopic)
          .where((topic) => topic.isNotEmpty)
          .expand((topic) => [
                'title.ilike.%$topic%',
                'short_answer.ilike.%$topic%',
                'detailed_answer.ilike.%$topic%',
              ])
          .join(',');
      if (orFilters.isNotEmpty) {
        final rows = await _client
            .from('notes')
            .select('id,title,short_answer,detailed_answer,file_url')
            .or(orFilters)
            .limit(5);
        for (final row in rows as List<dynamic>) {
          final map = row as Map<String, dynamic>;
          final note = Note(
            id: map['id']?.toString() ?? '',
            title: map['title']?.toString() ?? '',
            shortAnswer: map['short_answer']?.toString() ?? '',
            detailedAnswer: map['detailed_answer']?.toString() ?? '',
            fileUrl: map['file_url']?.toString(),
          );
          if (note.id.isEmpty || seen.contains(note.id)) continue;
          seen.add(note.id);
          results.add(note);
        }
      }
    }

    if (results.isEmpty) {
      final rows = await _client
          .from('notes')
          .select('id,title,short_answer,detailed_answer,file_url')
          .order('created_at', ascending: false)
          .limit(5);
      for (final row in rows as List<dynamic>) {
        final map = row as Map<String, dynamic>;
        final note = Note(
          id: map['id']?.toString() ?? '',
          title: map['title']?.toString() ?? '',
          shortAnswer: map['short_answer']?.toString() ?? '',
          detailedAnswer: map['detailed_answer']?.toString() ?? '',
          fileUrl: map['file_url']?.toString(),
        );
        if (note.id.isEmpty || seen.contains(note.id)) continue;
        seen.add(note.id);
        results.add(note);
      }
    }

    return results;
  }

  String _sanitizeTopic(String raw) {
    return raw
        .replaceAll('%', '')
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .trim();
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
