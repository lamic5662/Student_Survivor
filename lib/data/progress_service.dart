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

  Future<ProgressSnapshot> fetchProgressSnapshot(
    List<Subject> subjects,
  ) async {
    final syllabus = await _fetchSyllabusProgress(subjects);
    final planner = await _fetchPlannerProgress();
    final practice = await _fetchPracticeProgress();
    final community = await _fetchCommunityProgress();
    final ai = await _fetchAiProgress();
    final overall = _weightedOverall(
      syllabus: syllabus,
      planner: planner,
      practice: practice,
      community: community,
      ai: ai,
    );

    return ProgressSnapshot(
      overall: overall,
      syllabus: syllabus,
      planner: planner,
      practice: practice,
      community: community,
      ai: ai,
    );
  }

  Future<double> fetchOverallProgress(List<Subject> subjects) async {
    final snapshot = await fetchProgressSnapshot(subjects);
    return snapshot.overall;
  }

  Future<Map<String, double>> fetchSubjectProgress(
    List<Subject> subjects,
  ) async {
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

    final totalsBySubject = <String, double>{};
    final countsBySubject = <String, int>{};

    for (final entry in chapterToSubject.entries) {
      countsBySubject[entry.value] =
          (countsBySubject[entry.value] ?? 0) + 1;
    }

    for (final row in rows as List<dynamic>) {
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

    return progressBySubject;
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
      final quizRows = await _client
          .from('quiz_attempts')
          .select('id')
          .eq('user_id', user.id);
      final quizCount = (quizRows as List<dynamic>).length;

      final battleRows = await _client
          .from('battle_answers')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_correct', true);
      final battleCorrect = (battleRows as List<dynamic>).length;

      final noteRows = await _client
          .from('note_generated_questions')
          .select('id')
          .eq('user_id', user.id);
      final noteCount = (noteRows as List<dynamic>).length;

      var activityCount = 0;
      try {
        final activityRows = await _client
            .from('user_activity_log')
            .select('id,activity_type')
            .eq('user_id', user.id)
            .inFilter('activity_type', [
          'survival_quiz_correct',
          'survival_quiz_wrong',
          'code_fix_answer',
          'flashcard_review',
        ]);
        activityCount = (activityRows as List<dynamic>).length;
      } catch (_) {
        activityCount = 0;
      }

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
      final questionRows = await _client
          .from('community_questions')
          .select('id')
          .eq('user_id', user.id);
      final answerRows = await _client
          .from('community_answers')
          .select('id')
          .eq('user_id', user.id);

      final count = (questionRows as List<dynamic>).length +
          (answerRows as List<dynamic>).length;
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
}

class _ProgressTotals {
  final double totalPercent;
  final int totalChapters;

  const _ProgressTotals(this.totalPercent, this.totalChapters);
}
