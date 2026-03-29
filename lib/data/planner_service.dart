import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/data/supabase_config.dart';

class PlannerService {
  final SupabaseClient _client;

  PlannerService(this._client);

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
  }) async {
    final planId = await _ensurePlanId();
    if (replaceExisting) {
      await _client.from('study_tasks').delete().eq('plan_id', planId);
    }

    final today = DateTime.now();
    final dateList = List.generate(
      days,
      (i) => today.add(Duration(days: i)),
    ).map((d) => d.toIso8601String().substring(0, 10)).toList();

    final subjectNames = subjects.map((s) => s.name).toList();
    final subjectMap = {
      for (final s in subjects) s.name.toLowerCase(): s.id,
    };

    final systemPrompt =
        'You are a study planner. Return ONLY valid JSON.\n'
        'Schema: {"tasks":[{"title":"...","subject":"...","due_date":"YYYY-MM-DD"}]}\n'
        'Rules: Provide 2-4 tasks per day. Use the provided dates only. '
        'Subject must match one from the list or use "General".';

    final userPrompt =
        'Create a $days-day study plan starting today.\n'
        'Dates: ${dateList.join(', ')}\n'
        'Subjects: ${subjectNames.join(', ')}\n'
        'Focus on balanced coverage and upcoming exams.';

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
    final provider =
        SupabaseConfig.aiProviderFor(AiFeature.studyPlan).toLowerCase();
    if (provider == 'backend') {
      final response = await _client.functions.invoke(
        'ai-generate',
        body: {
          'system_prompt': systemPrompt,
          'user_prompt': userPrompt,
        },
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final reply = data['reply']?.toString().trim() ?? '';
      if (reply.isEmpty) {
        throw Exception('AI backend returned empty response.');
      }
      return reply;
    }

    if (provider == 'ollama') {
      final uri = Uri.parse('${SupabaseConfig.ollamaBaseUrl}/api/chat');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': SupabaseConfig.ollamaModel,
          'stream': false,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Ollama error: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = data['message']?['content']?.toString().trim() ?? '';
      if (reply.isEmpty) {
        throw Exception('AI returned empty response.');
      }
      return reply;
    }

    if (provider == 'lmstudio') {
      final uri =
          Uri.parse('${SupabaseConfig.lmStudioBaseUrl}/chat/completions');
      final headers = <String, String>{'Content-Type': 'application/json'};
      final apiKey = SupabaseConfig.lmStudioApiKey;
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'model': SupabaseConfig.lmStudioModel,
          'temperature': 0.4,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('LM Studio error: ${response.body}');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) {
        throw Exception('LM Studio returned empty response.');
      }
      final message = choices.first as Map<String, dynamic>;
      final content =
          (message['message']?['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) {
        throw Exception('LM Studio returned empty response.');
      }
      return content;
    }

    throw Exception('AI unavailable.');
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
