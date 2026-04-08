import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/progress_service.dart';
import 'package:student_survivor/data/revision_queue_service.dart';
import 'package:student_survivor/data/supabase_mappers.dart';
import 'package:student_survivor/models/app_models.dart';

class DashboardData {
  final double progress;
  final int xp;
  final int gamesPlayed;
  final List<WeakTopic> weakTopics;
  final List<Note> recommendedNotes;
  final List<RevisionItem> revisionQueue;
  final QuizAttempt? latestAttempt;

  const DashboardData({
    required this.progress,
    required this.xp,
    required this.gamesPlayed,
    required this.weakTopics,
    required this.recommendedNotes,
    required this.revisionQueue,
    required this.latestAttempt,
  });
}

class DashboardService {
  final SupabaseClient _client;

  DashboardService(this._client);

  static const String _cacheKey = 'dashboard_cache_v1';

  Future<_StatsFallback> _fallbackStats() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const _StatsFallback(xp: 0, gamesPlayed: 0);
    }
    try {
      final activityRows = await _client
          .from('user_activity_log')
          .select('points,activity_type,created_at')
          .eq('user_id', user.id);
      var xp = 0;
      final gameDays = <String>{};
      const gameTypes = {
        'survival_quiz_correct',
        'survival_quiz_wrong',
        'code_fix_answer',
        'battle_answer',
        'flashcard_review',
        'revision_quiz_complete',
        'exam_simulator_complete',
      };
      for (final row in activityRows as List<dynamic>) {
        xp += (row['points'] as num?)?.toInt() ?? 0;
        final type = row['activity_type']?.toString();
        if (type != null && gameTypes.contains(type)) {
          final createdAt = row['created_at']?.toString();
          if (createdAt != null && createdAt.isNotEmpty) {
            gameDays.add(createdAt.split('T').first);
          }
        }
      }

      final quizRows = await _client
          .from('quiz_attempts')
          .select('xp_earned,created_at')
          .eq('user_id', user.id);
      var quizXp = 0;
      final quizDays = <String>{};
      for (final row in quizRows as List<dynamic>) {
        quizXp += (row['xp_earned'] as num?)?.toInt() ?? 0;
        final createdAt = row['created_at']?.toString();
        if (createdAt != null && createdAt.isNotEmpty) {
          quizDays.add(createdAt.split('T').first);
        }
      }

      final totalXp = xp + quizXp;
      final gamesPlayed = (gameDays..addAll(quizDays)).length;
      return _StatsFallback(
        xp: totalXp,
        gamesPlayed: gamesPlayed,
      );
    } catch (_) {
      return const _StatsFallback(xp: 0, gamesPlayed: 0);
    }
  }

  Future<DashboardData> fetchDashboard({
    required List<Subject> subjects,
  }) async {
    try {
      final statsFuture = _client
          .from('user_stats')
          .select('xp, games_played')
          .maybeSingle();
      final weakFuture = _client
          .from('weak_topics')
          .select('topic, reason')
          .order('last_seen_at', ascending: false)
          .limit(5);
      final recFuture = _client
          .from('recommendations')
          .select('note:notes(id,title,short_answer,detailed_answer,file_url)')
          .order('created_at', ascending: false)
          .limit(5);
      final attemptFuture = _client
          .from('quiz_attempts')
          .select(
            'score,total,xp_earned,passed,'
            'quiz:quizzes(id,title,quiz_type,difficulty,question_count,duration_minutes)',
          )
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final revisionFuture = RevisionQueueService(_client)
          .fetchQueue(subjects: subjects, limit: 4)
          .catchError((_) => <RevisionItem>[]);
      final progressFuture =
          ProgressService(_client).fetchOverallProgress(subjects);

      final stats = await statsFuture;
      final weakData = await weakFuture;
      final recData = await recFuture;
      final attemptData = await attemptFuture;
      final revisionQueue = await revisionFuture;
      final progress = await progressFuture;

      var xp = (stats?['xp'] as num?)?.toInt() ?? 0;
      var gamesPlayed = (stats?['games_played'] as num?)?.toInt() ?? 0;
      if ((xp == 0 && gamesPlayed == 0) || stats == null) {
        final fallback = await _fallbackStats();
        xp = fallback.xp;
        gamesPlayed = fallback.gamesPlayed;
      }

      final weakTopics = (weakData as List<dynamic>)
          .map(
            (row) => WeakTopic(
              name: row['topic']?.toString() ?? '',
              reason: row['reason']?.toString() ?? 'Needs review',
            ),
          )
          .toList();

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

      final data = DashboardData(
        progress: progress,
        xp: xp,
        gamesPlayed: gamesPlayed,
        weakTopics: weakTopics,
        recommendedNotes: resolvedRecommendations,
        revisionQueue: revisionQueue,
        latestAttempt: latestAttempt,
      );
      await _cacheDashboard(data);
      return data;
    } catch (error) {
      final cached = await _loadCachedDashboard(subjects);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
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

  Future<void> _cacheDashboard(DashboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'progress': data.progress,
        'xp': data.xp,
        'games_played': data.gamesPlayed,
        'weak_topics': data.weakTopics
            .map((topic) => {'name': topic.name, 'reason': topic.reason})
            .toList(),
        'recommended_notes':
            data.recommendedNotes.map(_noteToCacheMap).toList(),
        'revision_queue':
            data.revisionQueue.map(_revisionToCacheMap).toList(),
        'latest_attempt': data.latestAttempt == null
            ? null
            : _attemptToCacheMap(data.latestAttempt!),
        'updated_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<DashboardData?> _loadCachedDashboard(List<Subject> subjects) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final weakTopics = (map['weak_topics'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((entry) {
        final topic = entry['name']?.toString() ?? '';
        final reason = entry['reason']?.toString() ?? 'Needs review';
        if (topic.isEmpty) return null;
        return WeakTopic(name: topic, reason: reason);
      }).whereType<WeakTopic>().toList();
      final notes = (map['recommended_notes'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((entry) => _noteFromCacheMap(Map<String, dynamic>.from(entry)))
          .toList();
      final revision = (map['revision_queue'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((entry) =>
              _revisionFromCacheMap(Map<String, dynamic>.from(entry), subjects))
          .whereType<RevisionItem>()
          .toList();
      final attemptRaw = map['latest_attempt'];
      final latestAttempt = attemptRaw is Map
          ? _attemptFromCacheMap(Map<String, dynamic>.from(attemptRaw))
          : null;
      return DashboardData(
        progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
        xp: (map['xp'] as num?)?.toInt() ?? 0,
        gamesPlayed: (map['games_played'] as num?)?.toInt() ?? 0,
        weakTopics: weakTopics,
        recommendedNotes: notes,
        revisionQueue: revision,
        latestAttempt: latestAttempt,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _revisionToCacheMap(RevisionItem item) {
    return {
      'id': item.id,
      'type': item.type.name,
      'priority': item.priority.name,
      'title': item.title,
      'detail': item.detail,
      'due_at': item.dueAt.toIso8601String(),
      'subject_id': item.subject?.id,
      'chapter_id': item.chapter?.id,
    };
  }

  RevisionItem? _revisionFromCacheMap(
    Map<String, dynamic> map,
    List<Subject> subjects,
  ) {
    final typeRaw = map['type']?.toString();
    final priorityRaw = map['priority']?.toString();
    final type =
        RevisionItemType.values.firstWhere((e) => e.name == typeRaw,
            orElse: () => RevisionItemType.topic);
    final priority = RevisionPriority.values.firstWhere(
      (e) => e.name == priorityRaw,
      orElse: () => RevisionPriority.low,
    );
    final dueAt = DateTime.tryParse(map['due_at']?.toString() ?? '');
    if (dueAt == null) return null;

    final chapterId = map['chapter_id']?.toString();
    final subjectId = map['subject_id']?.toString();
    Chapter? chapter;
    Subject? subject;
    for (final subj in subjects) {
      if (subj.id == subjectId) {
        subject = subj;
      }
      for (final ch in subj.chapters) {
        if (ch.id == chapterId) {
          chapter = ch;
          subject ??= subj;
        }
      }
    }

    return RevisionItem(
      id: map['id']?.toString() ?? '',
      type: type,
      priority: priority,
      title: map['title']?.toString() ?? '',
      detail: map['detail']?.toString() ?? '',
      dueAt: dueAt,
      subject: subject,
      chapter: chapter,
    );
  }

  Map<String, dynamic> _noteToCacheMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'short_answer': note.shortAnswer,
      'detailed_answer': note.detailedAnswer,
      'file_url': note.fileUrl,
    };
  }

  Note _noteFromCacheMap(Map<String, dynamic> map) {
    return Note(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Note',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      fileUrl: map['file_url']?.toString(),
    );
  }

  Map<String, dynamic> _attemptToCacheMap(QuizAttempt attempt) {
    return {
      'score': attempt.score,
      'total': attempt.total,
      'xp_earned': attempt.xpEarned,
      'quiz': _quizToCacheMap(attempt.quiz),
    };
  }

  QuizAttempt? _attemptFromCacheMap(Map<String, dynamic> map) {
    final quizRaw = map['quiz'];
    if (quizRaw is! Map) return null;
    final quiz = _quizFromCacheMap(Map<String, dynamic>.from(quizRaw));
    return QuizAttempt(
      quiz: quiz,
      score: (map['score'] as num?)?.toInt() ?? 0,
      total: (map['total'] as num?)?.toInt() ?? 0,
      xpEarned: (map['xp_earned'] as num?)?.toInt() ?? 0,
      weakTopics: const [],
      durationSeconds: null,
    );
  }

  Map<String, dynamic> _quizToCacheMap(Quiz quiz) {
    return {
      'id': quiz.id,
      'title': quiz.title,
      'quiz_type': quiz.type.name,
      'difficulty': quiz.difficulty.name,
      'question_count': quiz.questionCount,
      'duration_minutes': quiz.duration.inMinutes,
    };
  }

  Quiz _quizFromCacheMap(Map<String, dynamic> map) {
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
}

class _StatsFallback {
  final int xp;
  final int gamesPlayed;

  const _StatsFallback({
    required this.xp,
    required this.gamesPlayed,
  });
}
