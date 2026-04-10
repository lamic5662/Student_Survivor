import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/supabase_config.dart';

class AiTeacherLesson {
  final String title;
  final String objective;
  final String introduction;
  final List<String> mainPoints;
  final String example;
  final String summary;

  const AiTeacherLesson({
    required this.title,
    required this.objective,
    required this.introduction,
    required this.mainPoints,
    required this.example,
    required this.summary,
  });
}

class AiTeacherQuestion {
  final String? id;
  final String type;
  final String prompt;
  final List<String> options;
  final int? answerIndex;
  final String answer;

  const AiTeacherQuestion({
    this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.answer,
  });
}

class AiTeacherSession {
  final String? id;
  final AiTeacherLesson lesson;
  final List<AiTeacherQuestion> questions;

  const AiTeacherSession({
    this.id,
    required this.lesson,
    required this.questions,
  });
}

class AiTeacherEvaluation {
  final String verdict;
  final int score;
  final String feedback;
  final String improvedAnswer;

  const AiTeacherEvaluation({
    required this.verdict,
    required this.score,
    required this.feedback,
    required this.improvedAnswer,
  });
}

class AiTeacherHomework {
  final List<String> tasks;
  final String target;

  const AiTeacherHomework({
    required this.tasks,
    required this.target,
  });
}

class TeacherSessionSummary {
  final String id;
  final String? subjectId;
  final String subjectName;
  final String topic;
  final String level;
  final String style;
  final String lessonTitle;
  final String lessonSummary;
  final DateTime createdAt;

  const TeacherSessionSummary({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.topic,
    required this.level,
    required this.style,
    required this.lessonTitle,
    required this.lessonSummary,
    required this.createdAt,
  });
}

class TeacherSessionDetail {
  final TeacherSessionSummary summary;
  final AiTeacherLesson lesson;
  final List<AiTeacherQuestion> questions;
  final AiTeacherHomework? homework;

  const TeacherSessionDetail({
    required this.summary,
    required this.lesson,
    required this.questions,
    required this.homework,
  });
}

class AiTeacherService {
  final SupabaseClient _client;
  final AiRouterService _router;

  AiTeacherService(SupabaseClient client)
      : _client = client,
        _router = AiRouterService(client);

  Future<AiTeacherSession> generateLesson({
    required String subject,
    String? subjectId,
    required String topic,
    required String level,
    required String style,
  }) async {
    final systemPrompt =
        'You are a classroom teacher for BCA students. Return ONLY valid JSON.\n'
        'Schema: {\n'
        '  "lesson": {\n'
        '    "title": "...",\n'
        '    "objective": "...",\n'
        '    "introduction": "...",\n'
        '    "main_points": ["...","...","..."],\n'
        '    "example": "...",\n'
        '    "summary": "..."\n'
        '  },\n'
        '  "questions": [\n'
        '    {"type":"short","prompt":"...","answer":"..."},\n'
        '    {"type":"mcq","prompt":"...","options":["A","B","C","D"],"answer_index":1},\n'
        '    {"type":"viva","prompt":"...","answer":"..."}\n'
        '  ]\n'
        '}\n'
        'Rules: Use simple sentences. Keep introduction 2-3 lines, '
        'main_points 4-6 items, summary 2-3 lines. '
        'Questions should match the topic and be BCA level.';

    final userPrompt =
        'Subject: $subject\nTopic: $topic\nClass level: $level\nTeacher style: $style\n'
        'Teach step-by-step and ask 3 questions.';

    final raw = await _router.send(
      AiRequest(
        feature: AiFeature.tutor,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        timeout: const Duration(seconds: 28),
        expectsJson: true,
        metadata: {
          'subject': subject,
          'topic': topic,
          'style': style,
        },
      ),
    );

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final lessonMap = decoded['lesson'] as Map<String, dynamic>? ?? {};
    final questionsRaw = decoded['questions'] as List<dynamic>? ?? [];

    final lesson = AiTeacherLesson(
      title: lessonMap['title']?.toString().trim() ?? topic,
      objective: lessonMap['objective']?.toString().trim() ?? '',
      introduction: lessonMap['introduction']?.toString().trim() ?? '',
      mainPoints: (lessonMap['main_points'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      example: lessonMap['example']?.toString().trim() ?? '',
      summary: lessonMap['summary']?.toString().trim() ?? '',
    );

    final questions = questionsRaw
        .map((q) => q as Map<String, dynamic>)
        .map(
          (q) => AiTeacherQuestion(
            type: q['type']?.toString().trim().toLowerCase() ?? 'short',
            prompt: q['prompt']?.toString().trim() ?? '',
            options: (q['options'] as List<dynamic>? ?? [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList(),
            answerIndex: q['answer_index'] is int
                ? q['answer_index'] as int
                : int.tryParse(q['answer_index']?.toString() ?? ''),
            answer: q['answer']?.toString().trim() ?? '',
          ),
        )
        .where((q) => q.prompt.isNotEmpty)
        .toList();

    if (questions.isEmpty) {
      throw Exception('AI returned no questions.');
    }

    final session = AiTeacherSession(lesson: lesson, questions: questions);
    return _persistSession(
      session: session,
      subjectId: subjectId,
      subjectName: subject,
      topic: topic,
      level: level,
      style: style,
    );
  }

  Future<AiTeacherSession> _persistSession({
    required AiTeacherSession session,
    required String? subjectId,
    required String subjectName,
    required String topic,
    required String level,
    required String style,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return session;
    if (subjectId == null || subjectId.isEmpty) return session;
    final inserted = await _client
        .from('teacher_sessions')
        .insert({
          'user_id': user.id,
          'subject_id': subjectId,
          'subject_name': subjectName,
          'topic': topic,
          'level': level,
          'style': style,
          'lesson_title': session.lesson.title,
          'lesson_objective': session.lesson.objective,
          'lesson_introduction': session.lesson.introduction,
          'lesson_main_points': session.lesson.mainPoints,
          'lesson_example': session.lesson.example,
          'lesson_summary': session.lesson.summary,
        })
        .select()
        .maybeSingle();
    if (inserted == null) return session;
    final sessionId = inserted['id']?.toString();
    if (sessionId == null || sessionId.isEmpty) {
      return session;
    }
    final questionRows = await _client
        .from('teacher_questions')
        .insert(
          [
            for (var i = 0; i < session.questions.length; i += 1)
              {
                'session_id': sessionId,
                'type': session.questions[i].type,
                'prompt': session.questions[i].prompt,
                'options': session.questions[i].options,
                'answer_index': session.questions[i].answerIndex,
                'answer': session.questions[i].answer,
                'position': i,
              }
          ],
        )
        .select();
    final idByPosition = <int, String>{};
    for (final row in questionRows) {
      final pos = (row['position'] as num?)?.toInt();
      final id = row['id']?.toString();
      if (pos != null && id != null) {
        idByPosition[pos] = id;
      }
    }
    final savedQuestions = <AiTeacherQuestion>[];
    for (var i = 0; i < session.questions.length; i += 1) {
      final q = session.questions[i];
      savedQuestions.add(AiTeacherQuestion(
        id: idByPosition[i],
        type: q.type,
        prompt: q.prompt,
        options: q.options,
        answerIndex: q.answerIndex,
        answer: q.answer,
      ));
    }
    return AiTeacherSession(
      id: sessionId,
      lesson: session.lesson,
      questions: savedQuestions,
    );
  }

  Future<List<TeacherSessionSummary>> fetchSessions({int limit = 10}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('teacher_sessions')
        .select(
          'id,subject_id,subject_name,topic,level,style,'
          'lesson_title,lesson_summary,created_at',
        )
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final createdAt = DateTime.tryParse(
                row['created_at']?.toString() ?? '',
              ) ??
              DateTime.now();
          return TeacherSessionSummary(
            id: row['id']?.toString() ?? '',
            subjectId: row['subject_id']?.toString(),
            subjectName: row['subject_name']?.toString() ?? 'Subject',
            topic: row['topic']?.toString() ?? '',
            level: row['level']?.toString() ?? '',
            style: row['style']?.toString() ?? '',
            lessonTitle: row['lesson_title']?.toString() ?? '',
            lessonSummary: row['lesson_summary']?.toString() ?? '',
            createdAt: createdAt,
          );
        })
        .where((row) => row.id.isNotEmpty)
        .toList();
  }

  Future<TeacherSessionDetail?> fetchSessionDetail(String sessionId) async {
    if (sessionId.isEmpty) return null;
    final row = await _client
        .from('teacher_sessions')
        .select(
          'id,subject_id,subject_name,topic,level,style,'
          'lesson_title,lesson_objective,lesson_introduction,lesson_main_points,'
          'lesson_example,lesson_summary,homework_tasks,homework_target,'
          'created_at',
        )
        .eq('id', sessionId)
        .maybeSingle();
    if (row == null) return null;
    final summary = TeacherSessionSummary(
      id: row['id']?.toString() ?? '',
      subjectId: row['subject_id']?.toString(),
      subjectName: row['subject_name']?.toString() ?? 'Subject',
      topic: row['topic']?.toString() ?? '',
      level: row['level']?.toString() ?? '',
      style: row['style']?.toString() ?? '',
      lessonTitle: row['lesson_title']?.toString() ?? '',
      lessonSummary: row['lesson_summary']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
    final lesson = AiTeacherLesson(
      title: row['lesson_title']?.toString() ?? summary.lessonTitle,
      objective: row['lesson_objective']?.toString() ?? '',
      introduction: row['lesson_introduction']?.toString() ?? '',
      mainPoints: (row['lesson_main_points'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      example: row['lesson_example']?.toString() ?? '',
      summary: row['lesson_summary']?.toString() ?? '',
    );
    final homeworkTasks = (row['homework_tasks'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final homeworkTarget = row['homework_target']?.toString() ?? '';
    final homework = homeworkTasks.isEmpty && homeworkTarget.isEmpty
        ? null
        : AiTeacherHomework(tasks: homeworkTasks, target: homeworkTarget);
    final questionRows = await _client
        .from('teacher_questions')
        .select('id,type,prompt,options,answer_index,answer,position')
        .eq('session_id', sessionId)
        .order('position', ascending: true);
    final questions = <AiTeacherQuestion>[];
    for (final row in questionRows) {
      questions.add(
        AiTeacherQuestion(
          id: row['id']?.toString(),
          type: row['type']?.toString().trim().toLowerCase() ?? 'short',
          prompt: row['prompt']?.toString().trim() ?? '',
          options: (row['options'] as List<dynamic>? ?? [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          answerIndex: row['answer_index'] is int
              ? row['answer_index'] as int
              : int.tryParse(row['answer_index']?.toString() ?? ''),
          answer: row['answer']?.toString().trim() ?? '',
        ),
      );
    }
    return TeacherSessionDetail(
      summary: summary,
      lesson: lesson,
      questions: questions,
      homework: homework,
    );
  }

  Future<void> deleteSession(String sessionId) async {
    if (sessionId.isEmpty) return;
    await _client.from('teacher_sessions').delete().eq('id', sessionId);
  }

  Future<void> saveAnswer({
    required String? sessionId,
    required String? questionId,
    required String answer,
    required int score,
    required String verdict,
    required String feedback,
    required String improvedAnswer,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || sessionId == null || sessionId.isEmpty) return;
    if (answer.trim().isEmpty) return;
    await _client.from('teacher_answers').insert({
      'session_id': sessionId,
      'question_id': questionId,
      'user_id': user.id,
      'answer': answer,
      'score': score,
      'verdict': verdict,
      'feedback': feedback,
      'improved_answer': improvedAnswer,
    });
  }

  Future<void> saveHomework({
    required String? sessionId,
    required List<String> tasks,
    required String target,
  }) async {
    if (sessionId == null || sessionId.isEmpty) return;
    await _client.from('teacher_sessions').update({
      'homework_tasks': tasks,
      'homework_target': target,
    }).eq('id', sessionId);
  }

  Future<AiTeacherEvaluation> evaluateAnswer({
    required String question,
    required String expectedAnswer,
    required String studentAnswer,
    required String style,
    required String level,
  }) async {
    final systemPrompt =
        'You are a strict but helpful exam checker. Return ONLY valid JSON.\n'
        'Schema: {"verdict":"correct|partial|wrong","score":0-100,'
        '"feedback":"...","improved_answer":"..."}\n'
        'Rules: feedback 2-3 sentences, improved_answer 3-5 lines.';
    final userPrompt =
        'Class level: $level\nTeacher style: $style\nQuestion: $question\n'
        'Expected answer: $expectedAnswer\nStudent answer: $studentAnswer\n'
        'Evaluate and score.';

    final raw = await _router.send(
      AiRequest(
        feature: AiFeature.tutor,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.2,
        timeout: const Duration(seconds: 16),
        expectsJson: true,
      ),
    );

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final verdict = decoded['verdict']?.toString().trim().toLowerCase() ?? 'wrong';
    final score = int.tryParse(decoded['score']?.toString() ?? '') ?? 0;
    final feedback = decoded['feedback']?.toString().trim() ?? '';
    final improved = decoded['improved_answer']?.toString().trim() ?? '';

    return AiTeacherEvaluation(
      verdict: verdict,
      score: score,
      feedback: feedback,
      improvedAnswer: improved,
    );
  }

  Future<String> reteachSimpler({
    required String subject,
    required String topic,
    required String style,
  }) async {
    final systemPrompt =
        'You are a patient teacher. Explain the topic in very simple language. '
        'Return 6-8 short lines, no markdown or bullets.';
    final userPrompt =
        'Subject: $subject\nTopic: $topic\nTeacher style: $style\n'
        'Reteach in simpler words.';

    return _router.send(
      AiRequest(
        feature: AiFeature.tutor,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        timeout: const Duration(seconds: 18),
      ),
    );
  }

  Future<AiTeacherHomework> generateHomework({
    required String subject,
    required String topic,
    required String style,
    required String level,
  }) async {
    final systemPrompt =
        'You are a classroom teacher. Return ONLY valid JSON.\n'
        'Schema: {"tasks":["...","..."],"target":"..."}\n'
        'Rules: tasks length 4-6, each task 1 line. target is 1 short sentence. '
        'Use simple student-friendly language. No markdown.';
    final userPrompt =
        'Subject: $subject\nTopic: $topic\nClass level: $level\n'
        'Teacher style: $style\n'
        'Create homework tasks for tomorrow plus a target.';

    final raw = await _router.send(
      AiRequest(
        feature: AiFeature.studyPlan,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        timeout: const Duration(seconds: 22),
        expectsJson: true,
      ),
    );

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final tasks = (decoded['tasks'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final target = decoded['target']?.toString().trim() ?? '';
    if (tasks.isEmpty) {
      throw Exception('AI returned no homework tasks.');
    }
    return AiTeacherHomework(tasks: tasks, target: target);
  }

  Future<String> answerQuestion({
    required String subject,
    required String topic,
    required String level,
    required String style,
    required String question,
    String? lessonSummary,
    List<String>? keyPoints,
  }) async {
    final systemPrompt =
        'You are a classroom teacher helping a BCA student. '
        'Answer clearly in 3-6 short sentences. '
        'Use simple language, give one short example if helpful. '
        'No markdown, no bullet points.';
    final contextBuffer = StringBuffer()
      ..writeln('Subject: $subject')
      ..writeln('Topic: $topic')
      ..writeln('Class level: $level')
      ..writeln('Teacher style: $style');
    if ((lessonSummary ?? '').trim().isNotEmpty) {
      contextBuffer.writeln('Lesson summary: ${lessonSummary!.trim()}');
    }
    if (keyPoints != null && keyPoints.isNotEmpty) {
      contextBuffer.writeln('Key points: ${keyPoints.join('; ')}');
    }
    contextBuffer.writeln('Student question: $question');

    return _router.send(
      AiRequest(
        feature: AiFeature.tutor,
        systemPrompt: systemPrompt,
        userPrompt: contextBuffer.toString(),
        temperature: 0.3,
        timeout: const Duration(seconds: 18),
      ),
    );
  }
}
