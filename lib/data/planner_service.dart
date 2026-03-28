import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class PlannerService {
  final SupabaseClient _client;

  PlannerService(this._client);

  Future<List<StudyPlanDay>> fetchPlan() async {
    final data = await _client
        .from('study_tasks')
        .select('id,title,is_done,due_date,subject:subjects(name)')
        .order('due_date', ascending: true);

    final tasks = (data as List<dynamic>).map((row) {
      final subject = row['subject'] as Map<String, dynamic>?;
      return _PlannerTask(
        id: row['id']?.toString() ?? '',
        title: row['title']?.toString() ?? '',
        subject: subject?['name']?.toString() ?? 'General',
        isDone: row['is_done'] as bool? ?? false,
        dueDate: row['due_date']?.toString(),
      );
    }).toList();

    final byLabel = <String, List<StudyTask>>{};
    for (final task in tasks) {
      final label = _labelForDate(task.dueDate);
      byLabel.putIfAbsent(label, () => []).add(
            StudyTask(
              id: task.id,
              title: task.title,
              subject: task.subject,
              isDone: task.isDone,
            ),
          );
    }

    return byLabel.entries
        .map((entry) => StudyPlanDay(label: entry.key, tasks: entry.value))
        .toList();
  }

  Future<void> setTaskDone({
    required String taskId,
    required bool isDone,
  }) async {
    await _client.from('study_tasks').update({
      'is_done': isDone,
      'completed_at': isDone ? DateTime.now().toIso8601String() : null,
    }).eq('id', taskId);
  }

  String _labelForDate(String? dateIso) {
    if (dateIso == null || dateIso.isEmpty) {
      return 'Upcoming';
    }
    final date = DateTime.tryParse(dateIso);
    if (date == null) {
      return 'Upcoming';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Tomorrow';
    }
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }
}

class _PlannerTask {
  final String id;
  final String title;
  final String subject;
  final bool isDone;
  final String? dueDate;

  const _PlannerTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.isDone,
    required this.dueDate,
  });
}
