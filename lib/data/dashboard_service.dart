import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class DashboardData {
  final double progress;
  final int xp;
  final int gamesPlayed;
  final List<WeakTopic> weakTopics;
  final List<Note> recommendedNotes;
  final QuizAttempt? latestAttempt;

  const DashboardData({
    required this.progress,
    required this.xp,
    required this.gamesPlayed,
    required this.weakTopics,
    required this.recommendedNotes,
    required this.latestAttempt,
  });
}

class DashboardService {
  final SupabaseClient _client;

  DashboardService(this._client);

  Future<DashboardData> fetchDashboard({
    required List<Subject> subjects,
  }) async {
    final stats = await _client
        .from('user_stats')
        .select('xp, games_played')
        .maybeSingle();

    final xp = (stats?['xp'] as num?)?.toInt() ?? 0;
    final gamesPlayed = (stats?['games_played'] as num?)?.toInt() ?? 0;

    final weakData = await _client
        .from('weak_topics')
        .select('topic, reason')
        .order('last_seen_at', ascending: false)
        .limit(5);
    final weakTopics = (weakData as List<dynamic>)
        .map(
          (row) => WeakTopic(
            name: row['topic']?.toString() ?? '',
            reason: row['reason']?.toString() ?? 'Needs review',
          ),
        )
        .toList();

    final recData = await _client
        .from('recommendations')
        .select('note:notes(id,title,short_answer,detailed_answer,file_url)')
        .order('created_at', ascending: false)
        .limit(5);
    final recommendedNotes = (recData as List<dynamic>)
        .map((row) => row['note'])
        .where((note) => note != null)
        .map(_noteFromMap)
        .toList();
    final resolvedRecommendations = recommendedNotes.isNotEmpty
        ? recommendedNotes
        : await _fallbackRecommendations(
            subjects: subjects,
            weakTopics: weakTopics,
          );

    final attemptData = await _client
        .from('quiz_attempts')
        .select(
          'score,total,xp_earned,passed,'
          'quiz:quizzes(id,title,quiz_type,difficulty,question_count,duration_minutes)',
        )
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    QuizAttempt? latestAttempt;
    if (attemptData != null) {
      final quizMap = attemptData['quiz'] as Map<String, dynamic>?;
      if (quizMap != null) {
        final quiz = Quiz(
          id: quizMap['id']?.toString() ?? '',
          title: quizMap['title']?.toString() ?? 'Quiz',
          type: parseQuizType(quizMap['quiz_type']?.toString()),
          difficulty: parseQuizDifficulty(quizMap['difficulty']?.toString()),
          questionCount: (quizMap['question_count'] as num?)?.toInt() ?? 0,
          duration: Duration(
            minutes: (quizMap['duration_minutes'] as num?)?.toInt() ?? 10,
          ),
        );
        latestAttempt = QuizAttempt(
          quiz: quiz,
          score: (attemptData['score'] as num?)?.toInt() ?? 0,
          total: (attemptData['total'] as num?)?.toInt() ?? 0,
          xpEarned: (attemptData['xp_earned'] as num?)?.toInt() ?? 0,
          weakTopics: const [],
          durationSeconds: null,
        );
      }
    }

    final progress = await _computeProgress(subjects);

    return DashboardData(
      progress: progress,
      xp: xp,
      gamesPlayed: gamesPlayed,
      weakTopics: weakTopics,
      recommendedNotes: resolvedRecommendations,
      latestAttempt: latestAttempt,
    );
  }

  Future<List<Note>> _fallbackRecommendations({
    required List<Subject> subjects,
    required List<WeakTopic> weakTopics,
  }) async {
    final results = <Note>[];
    final seen = <String>{};
    final chapterIds = _chapterIdsFromSubjects(subjects);

    if (weakTopics.isNotEmpty && chapterIds.isNotEmpty) {
      final orFilters = weakTopics
          .map((topic) => _sanitizeTopic(topic.name))
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
            .inFilter('chapter_id', chapterIds)
            .or(orFilters)
            .limit(5);
        for (final row in rows as List<dynamic>) {
          final note = _noteFromMap(row);
          if (note.id.isEmpty || seen.contains(note.id)) continue;
          seen.add(note.id);
          results.add(note);
        }
      }
    }

    if (results.length < 5 && chapterIds.isNotEmpty) {
      final focusChapters = await _lowestProgressChapters(chapterIds);
      if (focusChapters.isNotEmpty) {
        final rows = await _client
            .from('notes')
            .select('id,title,short_answer,detailed_answer,file_url')
            .inFilter('chapter_id', focusChapters)
            .order('created_at', ascending: false)
            .limit(5 - results.length);
        for (final row in rows as List<dynamic>) {
          final note = _noteFromMap(row);
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
        final note = _noteFromMap(row);
        if (note.id.isEmpty || seen.contains(note.id)) continue;
        seen.add(note.id);
        results.add(note);
      }
    }

    return results;
  }

  List<String> _chapterIdsFromSubjects(List<Subject> subjects) {
    final chapterIds = <String>{};
    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        if (chapter.id.isNotEmpty) {
          chapterIds.add(chapter.id);
        }
      }
    }
    return chapterIds.toList();
  }

  Future<List<String>> _lowestProgressChapters(List<String> chapterIds) async {
    final rows = await _client
        .from('user_chapter_progress')
        .select('chapter_id, completion_percent')
        .inFilter('chapter_id', chapterIds)
        .order('completion_percent', ascending: true)
        .limit(3);
    return (rows as List<dynamic>)
        .map((row) => row['chapter_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  String _sanitizeTopic(String raw) {
    return raw
        .replaceAll('%', '')
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .trim();
  }

  Future<double> _computeProgress(List<Subject> subjects) async {
    final chapterIds = <String>{};
    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        chapterIds.add(chapter.id);
      }
    }

    if (chapterIds.isEmpty) {
      return 0;
    }

    final rows = await _client
        .from('user_chapter_progress')
        .select('chapter_id, completion_percent')
        .inFilter('chapter_id', chapterIds.toList());

    double total = 0;
    for (final row in rows as List<dynamic>) {
      total += (row['completion_percent'] as num?)?.toDouble() ?? 0;
    }

    final maxTotal = chapterIds.length * 100.0;
    if (maxTotal == 0) {
      return 0;
    }
    return (total / maxTotal).clamp(0, 1);
  }

  Note _noteFromMap(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    return Note(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      fileUrl: map['file_url']?.toString(),
    );
  }
}
