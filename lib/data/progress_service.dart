import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class ProgressSnapshot {
  final double overall;
  final double syllabus;
  final double planner;
  final double practice;
  final double community;
  final double ai;

  const ProgressSnapshot({
    required this.overall,
    required this.syllabus,
    required this.planner,
    required this.practice,
    required this.community,
    required this.ai,
  });
}

class ProgressService {
  final SupabaseClient _client;

  ProgressService(this._client);

  static const String _snapshotKey = 'progress_snapshot_v1';
  static const String _subjectProgressKey = 'progress_subject_v1';

  Future<ProgressSnapshot> fetchProgressSnapshot(
    List<Subject> subjects,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const ProgressSnapshot(
        overall: 0,
        syllabus: 0,
        planner: 0,
        practice: 0,
        community: 0,
        ai: 0,
      );
    }
    try {
      final results = await Future.wait<double>([
        _fetchSyllabusProgress(subjects),
        _fetchPlannerProgress(),
        _fetchPracticeProgress(),
        _fetchCommunityProgress(),
        _fetchAiProgress(),
      ]);
      final syllabus = results[0];
      final planner = results[1];
      final practice = results[2];
      final community = results[3];
      final ai = results[4];
      final overall = _weightedOverall(
        syllabus: syllabus,
        planner: planner,
        practice: practice,
        community: community,
        ai: ai,
      );

      final snapshot = ProgressSnapshot(
        overall: overall,
        syllabus: syllabus,
        planner: planner,
        practice: practice,
        community: community,
        ai: ai,
      );
      await _cacheSnapshot(user.id, snapshot);
      return snapshot;
    } catch (_) {
      final cached = await _loadSnapshot(user.id);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<double> fetchOverallProgress(List<Subject> subjects) async {
    final snapshot = await fetchProgressSnapshot(subjects);
    return snapshot.overall;
  }

  Future<Map<String, double>> fetchSubjectProgress(
    List<Subject> subjects,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    try {
      final chapterToSubject = <String, String>{};
      for (final subject in subjects) {
        for (final chapter in subject.chapters) {
          chapterToSubject[chapter.id] = subject.id;
        }
      }
      if (chapterToSubject.isEmpty) {
        return {};
      }

      final rows = await _client
          .from('user_chapter_progress')
          .select('chapter_id, completion_percent')
          .inFilter('chapter_id', chapterToSubject.keys.toList());
      final rowList = rows as List<dynamic>;
      if (rowList.isEmpty) {
        final fallback =
            await _fallbackSubjectProgressFromAttempts(subjects);
        if (fallback.isNotEmpty) {
          await _cacheSubjectProgress(user.id, fallback);
          return fallback;
        }
      }

      final totalsBySubject = <String, double>{};
      final countsBySubject = <String, int>{};

      for (final entry in chapterToSubject.entries) {
        countsBySubject[entry.value] =
            (countsBySubject[entry.value] ?? 0) + 1;
      }

      for (final row in rowList) {
        final chapterId = row['chapter_id']?.toString();
        final subjectId = chapterToSubject[chapterId];
        if (subjectId == null) continue;
        totalsBySubject[subjectId] =
            (totalsBySubject[subjectId] ?? 0) +
                ((row['completion_percent'] as num?)?.toDouble() ?? 0);
      }

      final progressBySubject = <String, double>{};
      for (final subjectId in countsBySubject.keys) {
        final totalPercent = totalsBySubject[subjectId] ?? 0;
        final chapters = countsBySubject[subjectId] ?? 0;
        if (chapters == 0) {
          progressBySubject[subjectId] = 0;
        } else {
          progressBySubject[subjectId] =
              (totalPercent / (chapters * 100)).clamp(0, 1);
        }
      }
      await _cacheSubjectProgress(user.id, progressBySubject);
      return progressBySubject;
    } catch (_) {
      final cached = await _loadSubjectProgress(user.id);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<Map<String, double>> _fallbackSubjectProgressFromAttempts(
    List<Subject> subjects,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    final chapterToSubject = <String, String>{};
    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        chapterToSubject[chapter.id] = subject.id;
      }
    }
    if (chapterToSubject.isEmpty) return {};
    try {
      final rows = await _client
          .from('quiz_attempts')
          .select('score,total,quiz:quizzes(chapter_id)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(200);
      if ((rows as List<dynamic>).isEmpty) return {};

      final bestByChapter = <String, double>{};
      for (final row in rows) {
        final quizMap = row['quiz'] as Map<String, dynamic>?;
        final chapterId = quizMap?['chapter_id']?.toString();
        if (chapterId == null || chapterId.isEmpty) continue;
        final total = (row['total'] as num?)?.toDouble() ?? 0;
        final score = (row['score'] as num?)?.toDouble() ?? 0;
        if (total <= 0) continue;
        final ratio = (score / total).clamp(0, 1).toDouble();
        final current = bestByChapter[chapterId] ?? 0;
        if (ratio > current) {
          bestByChapter[chapterId] = ratio;
        }
      }
      if (bestByChapter.isEmpty) return {};

      final totalsBySubject = <String, double>{};
      final countsBySubject = <String, int>{};
      for (final entry in chapterToSubject.entries) {
        countsBySubject[entry.value] =
            (countsBySubject[entry.value] ?? 0) + 1;
      }
      for (final entry in bestByChapter.entries) {
        final subjectId = chapterToSubject[entry.key];
        if (subjectId == null) continue;
        totalsBySubject[subjectId] =
            (totalsBySubject[subjectId] ?? 0) + entry.value;
      }
      final progressBySubject = <String, double>{};
      for (final subjectId in countsBySubject.keys) {
        final total = totalsBySubject[subjectId] ?? 0;
        final chapters = countsBySubject[subjectId] ?? 0;
        progressBySubject[subjectId] =
            chapters == 0 ? 0 : (total / chapters).clamp(0, 1);
      }
      return progressBySubject;
    } catch (_) {
      return {};
    }
  }

  Future<double> _fetchSyllabusProgress(List<Subject> subjects) async {
    final totals = await _fetchProgressTotals(subjects);
    if (totals.totalChapters == 0) {
      return 0;
    }
    return (totals.totalPercent / (totals.totalChapters * 100))
        .clamp(0, 1);
  }

  Future<double> _fetchPlannerProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final planRows = await _client
          .from('study_plans')
          .select('id')
          .eq('user_id', user.id);
      final planIds = (planRows as List<dynamic>)
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (planIds.isEmpty) return 0;

      final taskRows = await _client
          .from('study_tasks')
          .select('id,is_done')
          .inFilter('plan_id', planIds);
      if ((taskRows as List<dynamic>).isEmpty) return 0;

      var total = 0;
      var done = 0;
      for (final row in taskRows) {
        total += 1;
        if (row['is_done'] == true) {
          done += 1;
        }
      }
      if (total == 0) return 0;
      return (done / total).clamp(0, 1);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _fetchPracticeProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final quizFuture = _client
          .from('quiz_attempts')
          .select('id')
          .eq('user_id', user.id);
      final battleFuture = _client
          .from('battle_answers')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_correct', true);
      final noteFuture = _client
          .from('note_generated_questions')
          .select('id')
          .eq('user_id', user.id);
      final activityFuture = _client
          .from('user_activity_log')
          .select('id,activity_type')
          .eq('user_id', user.id)
          .inFilter('activity_type', [
        'survival_quiz_correct',
        'survival_quiz_wrong',
        'code_fix_answer',
        'flashcard_review',
      ]).catchError((_) => <dynamic>[]);

      final results = await Future.wait<dynamic>([
        quizFuture,
        battleFuture,
        noteFuture,
        activityFuture,
      ]);
      final quizCount = (results[0] as List<dynamic>).length;
      final battleCorrect = (results[1] as List<dynamic>).length;
      final noteCount = (results[2] as List<dynamic>).length;
      final activityCount = (results[3] as List<dynamic>).length;

      final quizScore = _normalizeCount(quizCount, 8);
      final battleScore = _normalizeCount(battleCorrect, 20);
      final noteScore = _normalizeCount(noteCount, 5);
      final activityScore = _normalizeCount(activityCount, 30);

      return _average([quizScore, battleScore, noteScore, activityScore]);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _fetchCommunityProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final questionFuture = _client
          .from('community_questions')
          .select('id')
          .eq('user_id', user.id);
      final answerFuture = _client
          .from('community_answers')
          .select('id')
          .eq('user_id', user.id);

      final results =
          await Future.wait<dynamic>([questionFuture, answerFuture]);
      final count = (results[0] as List<dynamic>).length +
          (results[1] as List<dynamic>).length;
      return _normalizeCount(count, 4);
    } catch (_) {
      return 0;
    }
  }

  Future<double> _fetchAiProgress() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    try {
      final conversations = await _client
          .from('ai_conversations')
          .select('id')
          .eq('user_id', user.id);
      final conversationIds = (conversations as List<dynamic>)
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      if (conversationIds.isEmpty) return 0;

      final messages = await _client
          .from('ai_messages')
          .select('id')
          .eq('role', 'user')
          .inFilter('conversation_id', conversationIds);
      final count = (messages as List<dynamic>).length;
      return _normalizeCount(count, 12);
    } catch (_) {
      return 0;
    }
  }

  double _weightedOverall({
    required double syllabus,
    required double planner,
    required double practice,
    required double community,
    required double ai,
  }) {
    const syllabusWeight = 0.55;
    const plannerWeight = 0.15;
    const practiceWeight = 0.2;
    const communityWeight = 0.05;
    const aiWeight = 0.05;
    final total = (syllabus * syllabusWeight) +
        (planner * plannerWeight) +
        (practice * practiceWeight) +
        (community * communityWeight) +
        (ai * aiWeight);
    return total.clamp(0, 1);
  }

  double _normalizeCount(int count, int target) {
    if (target <= 0) return 0;
    return (count / target).clamp(0, 1);
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    var total = 0.0;
    for (final value in values) {
      total += value;
    }
    return (total / values.length).clamp(0, 1);
  }

  Future<_ProgressTotals> _fetchProgressTotals(List<Subject> subjects) async {
    final chapterIds = <String>{};
    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        chapterIds.add(chapter.id);
      }
    }
    if (chapterIds.isEmpty) {
      return const _ProgressTotals(0, 0);
    }
    final rows = await _client
        .from('user_chapter_progress')
        .select('chapter_id, completion_percent')
        .inFilter('chapter_id', chapterIds.toList());

    double totalPercent = 0;
    for (final row in rows as List<dynamic>) {
      totalPercent += (row['completion_percent'] as num?)?.toDouble() ?? 0;
    }
    return _ProgressTotals(totalPercent, chapterIds.length);
  }

  Future<void> _cacheSnapshot(
    String userId,
    ProgressSnapshot snapshot,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'overall': snapshot.overall,
        'syllabus': snapshot.syllabus,
        'planner': snapshot.planner,
        'practice': snapshot.practice,
        'community': snapshot.community,
        'ai': snapshot.ai,
      };
      await prefs.setString(
        '${userId}_$_snapshotKey',
        jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<ProgressSnapshot?> _loadSnapshot(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${userId}_$_snapshotKey');
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return ProgressSnapshot(
        overall: (map['overall'] as num?)?.toDouble() ?? 0,
        syllabus: (map['syllabus'] as num?)?.toDouble() ?? 0,
        planner: (map['planner'] as num?)?.toDouble() ?? 0,
        practice: (map['practice'] as num?)?.toDouble() ?? 0,
        community: (map['community'] as num?)?.toDouble() ?? 0,
        ai: (map['ai'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheSubjectProgress(
    String userId,
    Map<String, double> progress,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${userId}_$_subjectProgressKey',
        jsonEncode(progress),
      );
    } catch (_) {}
  }

  Future<Map<String, double>> _loadSubjectProgress(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${userId}_$_subjectProgressKey');
      if (raw == null || raw.isEmpty) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, double>{};
      for (final entry in map.entries) {
        result[entry.key] = (entry.value as num?)?.toDouble() ?? 0;
      }
      return result;
    } catch (_) {
      return {};
    }
  }
}

class _ProgressTotals {
  final double totalPercent;
  final int totalChapters;

  const _ProgressTotals(this.totalPercent, this.totalChapters);
}
