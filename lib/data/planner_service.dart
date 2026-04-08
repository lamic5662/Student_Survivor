import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/supabase_config.dart';

class PlannerService {
  final SupabaseClient _client;
  final AiRouterService _aiRouter;

  PlannerService(this._client) : _aiRouter = AiRouterService(_client);

  Future<List<StudyPlanDay>> fetchPlan() async {
    final planId = await _ensurePlanId();
    final data = await _client
        .from('study_tasks')
        .select('id,title,is_done,due_date,subject:subjects(name)')
        .eq('plan_id', planId)
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
              dueDate: task.dueDate,
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

  Future<String> addTask({
    required String title,
    String? subjectId,
    DateTime? dueDate,
  }) async {
    final planId = await _ensurePlanId();
    final inserted = await _client.from('study_tasks').insert({
      'plan_id': planId,
      'subject_id': subjectId,
      'title': title,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
    }).select('id').single();
    return inserted['id']?.toString() ?? '';
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('study_tasks').delete().eq('id', taskId);
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    String? subjectId,
    DateTime? dueDate,
  }) async {
    await _client.from('study_tasks').update({
      'title': title,
      'subject_id': subjectId,
      'due_date': dueDate?.toIso8601String().substring(0, 10),
    }).eq('id', taskId);
  }

  Future<List<StudyPlanDay>> generatePlan({
    required List<Subject> subjects,
    int days = 7,
    bool replaceExisting = true,
    DateTime? startDate,
    DateTime? endDate,
    List<WeakTopic> weakTopics = const [],
    Map<String, DateTime> subjectExamDates = const {},
  }) async {
    final planId = await _ensurePlanId();
    if (replaceExisting) {
      await _client.from('study_tasks').delete().eq('plan_id', planId);
    }

    final start = startDate ?? DateTime.now();
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = endDate == null
        ? null
        : DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = normalizedEnd == null
        ? days
        : normalizedEnd.difference(normalizedStart).inDays + 1;
    final planDays = totalDays <= 0 ? days : totalDays;
    final dateList = List.generate(
      planDays,
      (i) => normalizedStart.add(Duration(days: i)),
    ).map((d) => d.toIso8601String().substring(0, 10)).toList();

    final subjectNames = subjects.map((s) => s.name).toList();
    final subjectMap = {
      for (final s in subjects) s.name.toLowerCase(): s.id,
    };

    final systemPrompt =
        'You are a study planner. Return ONLY valid JSON.\n'
        'Schema: {"tasks":[{"title":"...","subject":"...","due_date":"YYYY-MM-DD"}]}\n'
        'Rules: Provide 2-4 tasks per day. Use the provided dates only. '
        'Subject must match one from the list or use "General". '
        'If subject exam dates are provided, do NOT schedule tasks for a subject after its exam date. '
        'Increase task density for a subject as its exam date approaches.';

    final weakLabels = weakTopics
        .map((topic) => topic.name)
        .where((label) => label.trim().isNotEmpty)
        .toList();
    final subjectNameById = {
      for (final subject in subjects) subject.id: subject.name,
    };
    final subjectExamLines = subjectExamDates.entries
        .map(
          (entry) {
            final name = subjectNameById[entry.key] ?? entry.key;
            final date = entry.value;
            return '$name=${date.toIso8601String().substring(0, 10)}';
          },
        )
        .toList();
    final userPrompt =
        'Create a $planDays-day study plan starting today.\n'
        'Dates: ${dateList.join(', ')}\n'
        'Subjects: ${subjectNames.join(', ')}\n'
        '${normalizedEnd == null ? '' : 'Exam date: ${normalizedEnd.toIso8601String().substring(0, 10)}\\n'}'
        '${subjectExamLines.isEmpty ? '' : 'Exam dates by subject: ${subjectExamLines.join('; ')}\\n'}'
        '${weakLabels.isEmpty ? '' : 'Weak topics to prioritize: ${weakLabels.join(', ')}\\n'}'
        'Focus on balanced coverage and upcoming exams. '
        'When subject exam dates exist, prioritize that subject closer to its exam date.';

    final raw = await _sendAi(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    final jsonText = _extractJson(raw);
    final decoded = jsonDecode(jsonText);
    final list = decoded is Map<String, dynamic>
        ? (decoded['tasks'] as List<dynamic>? ?? [])
        : decoded as List<dynamic>;

    if (list.isEmpty) {
      throw Exception('No tasks generated.');
    }

    final inserts = <Map<String, dynamic>>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final title = item['title']?.toString().trim();
      final subject = item['subject']?.toString().trim();
      final dueDate = item['due_date']?.toString().trim();
      if (title == null || title.isEmpty) continue;
      inserts.add({
        'plan_id': planId,
        'subject_id': subject == null
            ? null
            : subjectMap[subject.toLowerCase()],
        'title': title,
        'due_date': dueDate,
      });
    }

    if (inserts.isEmpty) {
      throw Exception('AI output invalid. Try again.');
    }

    await _client.from('study_tasks').insert(inserts);
    await _client.from('study_plans').update({
      'start_date': dateList.first,
      'end_date': dateList.last,
    }).eq('id', planId);
    return fetchPlan();
  }

  Future<String> _ensurePlanId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final existing = await _client
        .from('study_plans')
        .select('id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final id = existing?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final created = await _client
        .from('study_plans')
        .insert({
          'user_id': user.id,
          'title': 'My Study Plan',
          'start_date': DateTime.now().toIso8601String().substring(0, 10),
        })
        .select('id')
        .single();
    return created['id']?.toString() ?? '';
  }

  Future<String> _sendAi({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    return _aiRouter.send(
      AiRequest(
        feature: AiFeature.studyPlan,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        expectsJson: true,
        metadata: {
          'subjects': userPrompt,
        },
      ),
    );
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

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    final listStart = text.indexOf('[');
    final listEnd = text.lastIndexOf(']');
    if (listStart != -1 && listEnd != -1 && listEnd > listStart) {
      return text.substring(listStart, listEnd + 1);
    }
    return text;
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
