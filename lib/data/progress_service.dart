import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class ProgressService {
  final SupabaseClient _client;

  ProgressService(this._client);

  Future<double> fetchOverallProgress(List<Subject> subjects) async {
    final totals = await _fetchProgressTotals(subjects);
    if (totals.totalChapters == 0) {
      return 0;
    }
    return (totals.totalPercent / (totals.totalChapters * 100))
        .clamp(0, 1);
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
