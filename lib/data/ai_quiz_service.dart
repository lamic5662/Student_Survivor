import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class AiQuizService {
  final SupabaseClient _client;

  AiQuizService(this._client);

  Future<List<WrittenQuestion>> generateWrittenQuestions({
    required Subject subject,
    Chapter? chapter,
    required int count,
    required QuizDifficulty baseDifficulty,
    List<int>? marksPattern,
    String? nonce,
  }) async {
    final mode = SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (mode != 'ollama' && !_isLmStudio(mode) && mode != 'backend') {
      return [];
    }
    try {
      final context = await _buildContext('exam', subject, chapter);
      final systemPrompt =
          'You are an expert examiner for BCA students. Return ONLY valid JSON.\n'
          'Schema: {"questions":[{"prompt":"...","marks":5,"topic":"...","difficulty":"easy|medium|hard"}]}\n'
          'Rules: Provide clear written/subjective questions. Use marks 2,4,6,8,10. '
          'No markdown, no extra text.';
      final nonceLine = nonce == null
          ? ''
          : 'Unique seed: $nonce. Do not repeat previous questions.\n';
      final patternLine = marksPattern == null || marksPattern.isEmpty
          ? ''
          : 'Marks pattern: ${marksPattern.join(", ")}. ';
      final userPrompt =
          'Generate $count written questions. Base difficulty: ${baseDifficulty.name}. '
          '$nonceLine'
          '$patternLine'
          'Cover different chapters and subtopics when available. '
          'Use the context below.\n\n$context';

      final raw = mode == 'backend'
          ? await _requestWithBackend(systemPrompt, userPrompt)
          : await _requestWithLocalAi(
              mode,
              systemPrompt,
              userPrompt,
              ollamaModel: SupabaseConfig.ollamaModelExam,
            );
      if (raw.trim().isEmpty) return [];

      final jsonText = _extractJson(raw);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final list = decoded['questions'] as List<dynamic>? ?? [];
      final questions = <WrittenQuestion>[];
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final prompt = entry['prompt']?.toString().trim() ?? '';
        if (prompt.isEmpty) continue;
        final marks = (entry['marks'] as num?)?.toInt() ?? 5;
        questions.add(
          WrittenQuestion(
            prompt: prompt,
            marks: marks.clamp(2, 10),
            topic: entry['topic']?.toString(),
            difficulty: entry['difficulty']?.toString(),
          ),
        );
      }
      if (marksPattern != null && marksPattern.isNotEmpty) {
        final takeCount = marksPattern.length < questions.length
            ? marksPattern.length
            : questions.length;
        for (var i = 0; i < takeCount; i += 1) {
          questions[i] = WrittenQuestion(
            prompt: questions[i].prompt,
            marks: marksPattern[i].clamp(2, 10),
            topic: questions[i].topic,
            difficulty: questions[i].difficulty,
          );
        }
        if (questions.length > marksPattern.length) {
          questions.removeRange(marksPattern.length, questions.length);
        }
      }
      return questions;
    } catch (_) {
      return [];
    }
  }

  Future<List<WrittenGrade>> gradeWrittenAnswers({
    required Subject subject,
    Chapter? chapter,
    required List<WrittenQuestion> questions,
    required List<String> answers,
  }) async {
    if (questions.isEmpty) return [];
    final mode = SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (mode != 'ollama' && !_isLmStudio(mode) && mode != 'backend') {
      return [];
    }
    try {
      final context = await _buildContext('exam', subject, chapter);
      final payload = [
        for (var i = 0; i < questions.length; i += 1)
          {
            'prompt': questions[i].prompt,
            'marks': questions[i].marks,
            'answer': i < answers.length ? answers[i] : '',
          },
      ];
      final systemPrompt =
          'You are an expert examiner. Return ONLY valid JSON.\n'
          'Schema: {"grades":[{"score":4,"max_score":10,"feedback":"...","model_answer":"...","format_tips":"..."}]}\n'
          'Rules: score must be integer between 0 and max_score. '
          'Give concise feedback, a model answer, and formatting tips.';
      final userPrompt =
          'Evaluate the student answers and grade them. Use the context below.\n'
          'Context:\\n$context\\n\\n'
          'Questions and answers JSON:\\n${jsonEncode(payload)}';

      final raw = mode == 'backend'
          ? await _requestWithBackend(systemPrompt, userPrompt)
          : await _requestWithLocalAi(
              mode,
              systemPrompt,
              userPrompt,
              ollamaModel: SupabaseConfig.ollamaModelExam,
            );
      if (raw.trim().isEmpty) return [];

      final jsonText = _extractJson(raw);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final list = decoded['grades'] as List<dynamic>? ?? [];
      final grades = <WrittenGrade>[];
      for (var i = 0; i < list.length; i += 1) {
        final entry = list[i];
        if (entry is! Map<String, dynamic>) continue;
        final maxScore = (entry['max_score'] as num?)?.toInt() ??
            (i < questions.length ? questions[i].marks : 10);
        final score =
            (entry['score'] as num?)?.toInt().clamp(0, maxScore) ?? 0;
        grades.add(
          WrittenGrade(
            score: score,
            maxScore: maxScore,
            feedback: entry['feedback']?.toString() ?? '',
            modelAnswer: entry['model_answer']?.toString() ?? '',
            formatTips: entry['format_tips']?.toString() ?? '',
          ),
        );
      }
      return grades;
    } catch (_) {
      return [];
    }
  }

  Future<List<QuizQuestionItem>> generateQuestions({
    required String quizId,
    required Subject subject,
    Chapter? chapter,
    required int count,
    required QuizDifficulty baseDifficulty,
    String? nonce,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (mode == 'ollama' || _isLmStudio(mode) || mode == 'backend') {
      try {
        final context = await _buildContext(quizId, subject, chapter);
        final questions = mode == 'backend'
            ? await _generateWithBackend(
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
              )
            : await _generateWithLocalAi(
                mode: mode,
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
                ollamaModel: SupabaseConfig.ollamaModelQuiz,
              );
        if (questions.isNotEmpty) {
          return questions;
        }
      } catch (_) {
        // Fall back to stored quiz questions.
      }
    }
    return _fallbackFromDb(quizId, count);
  }

  Future<List<QuizQuestionItem>> generateRevisionQuestions({
    required Subject subject,
    Chapter? chapter,
    required List<RevisionItem> items,
    required int count,
    required QuizDifficulty baseDifficulty,
    String? nonce,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (mode == 'ollama' || _isLmStudio(mode) || mode == 'backend') {
      try {
        final context = await _buildRevisionContext(
          subject: subject,
          chapter: chapter,
          items: items,
        );
        final questions = mode == 'backend'
            ? await _generateWithBackend(
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
              )
            : await _generateWithLocalAi(
                mode: mode,
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
                ollamaModel: SupabaseConfig.ollamaModelQuiz,
              );
        if (questions.isNotEmpty) {
          return questions;
        }
      } catch (_) {
        // fall through
      }
    }
    return _fallbackExamFromDb(
      subject: subject,
      chapter: chapter,
      count: count,
    );
  }

  Future<List<QuizQuestionItem>> generateExamQuestions({
    required Subject subject,
    Chapter? chapter,
    required int count,
    required QuizDifficulty baseDifficulty,
    String? nonce,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (mode == 'ollama' || _isLmStudio(mode) || mode == 'backend') {
      try {
        final context = await _buildContext('exam', subject, chapter);
        final questions = mode == 'backend'
            ? await _generateWithBackend(
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
              )
            : await _generateWithLocalAi(
                mode: mode,
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
                nonce: nonce,
                ollamaModel: SupabaseConfig.ollamaModelExam,
              );
        if (questions.isNotEmpty) {
          return questions;
        }
      } catch (_) {
        // fall through
      }
    }
    return _fallbackExamFromDb(subject: subject, chapter: chapter, count: count);
  }

  Future<String> _buildContext(
    String quizId,
    Subject subject,
    Chapter? chapter,
  ) async {
    Chapter? resolvedChapter = chapter;
    if (resolvedChapter == null && _looksLikeUuid(quizId)) {
      try {
        final row = await _client
            .from('quizzes')
            .select('chapter:chapters(id,title)')
            .eq('id', quizId)
            .maybeSingle();
        final chapterMap = row?['chapter'] as Map<String, dynamic>?;
        if (chapterMap != null) {
          resolvedChapter = Chapter(
            id: chapterMap['id']?.toString() ?? '',
            title: chapterMap['title']?.toString() ?? 'Chapter',
            notes: const [],
            importantQuestions: const [],
            pastQuestions: const [],
            quizzes: const [],
          );
        }
      } catch (_) {
        // Ignore invalid quiz id lookups for non-UUIDs (e.g. exam).
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Subject: ${subject.name} (${subject.code})');
    if (resolvedChapter != null) {
      buffer.writeln('Chapter: ${resolvedChapter.title}');
    }

    final subtopics = <ChapterTopic>[];
    final seenSubtopics = <String>{};

    void addSubtopic(ChapterTopic topic) {
      final title = topic.title.trim();
      if (title.isEmpty) return;
      final key = title.toLowerCase();
      if (seenSubtopics.contains(key)) return;
      seenSubtopics.add(key);
      subtopics.add(topic);
    }

    if (resolvedChapter != null) {
      for (final topic in resolvedChapter.subtopics) {
        addSubtopic(topic);
      }
    }
    for (final chapter in subject.chapters) {
      for (final topic in chapter.subtopics) {
        addSubtopic(topic);
      }
    }

    final noteSnippets = <String>[];
    final seenTitles = <String>{};

    void addNoteSnippet(String title, String body) {
      final cleanedTitle = title.trim();
      final cleanedBody = body.trim();
      if (cleanedTitle.isEmpty || cleanedBody.isEmpty) return;
      final key = cleanedTitle.toLowerCase();
      if (seenTitles.contains(key)) return;
      seenTitles.add(key);
      noteSnippets.add('$cleanedTitle: ${_trim(cleanedBody, 120)}');
    }

    final notes = resolvedChapter?.notes ?? const <Note>[];
    for (final note in notes.take(4)) {
      final text = note.shortAnswer.isNotEmpty
          ? note.shortAnswer
          : note.detailedAnswer;
      addNoteSnippet(note.title, text);
    }
    if (notes.isEmpty) {
      for (final chapter in subject.chapters) {
        for (final note in chapter.notes.take(2)) {
          final text = note.shortAnswer.isNotEmpty
              ? note.shortAnswer
              : note.detailedAnswer;
          addNoteSnippet(note.title, text);
        }
      }
    }

    if (resolvedChapter != null && resolvedChapter.id.isNotEmpty) {
      final dbNotes = await _fetchNotesForChapter(resolvedChapter.id);
      for (final note in dbNotes.take(4)) {
        final text = note.shortAnswer.isNotEmpty
            ? note.shortAnswer
            : note.detailedAnswer;
        addNoteSnippet(note.title, text);
      }

      final dbSubtopics =
          await _fetchSubtopicsForChapter(resolvedChapter.id);
      for (final topic in dbSubtopics) {
        addSubtopic(topic);
      }

      final userNotes = await _fetchUserNotesForChapter(resolvedChapter.id);
      for (final note in userNotes.take(4)) {
        final text = note.shortAnswer.isNotEmpty
            ? note.shortAnswer
            : note.detailedAnswer;
        addNoteSnippet(note.title, text);
      }
    }

    if (subtopics.isEmpty && subject.id.isNotEmpty) {
      final subjectSubtopics = await _fetchSubtopicsForSubject(subject.id);
      for (final topic in subjectSubtopics) {
        addSubtopic(topic);
      }
    }
    if (noteSnippets.isEmpty && subject.id.isNotEmpty) {
      final subjectNotes = await _fetchNotesForSubject(subject.id);
      for (final note in subjectNotes.take(6)) {
        final text = note.shortAnswer.isNotEmpty
            ? note.shortAnswer
            : note.detailedAnswer;
        addNoteSnippet(note.title, text);
      }
    }

    if (noteSnippets.isNotEmpty) {
      buffer.writeln('Key notes:');
      for (final snippet in noteSnippets.take(8)) {
        buffer.writeln('- $snippet');
      }
    }

    if (subtopics.isNotEmpty) {
      buffer.writeln('Subtopics:');
      for (final topic in subtopics.take(12)) {
        buffer.writeln('- ${_trim(topic.title, 120)}');
      }
    }

    final questions = [
      ...?resolvedChapter?.importantQuestions,
      ...?resolvedChapter?.pastQuestions,
    ];
    if (questions.isNotEmpty) {
      buffer.writeln('Existing questions:');
      for (final q in questions.take(6)) {
        buffer.writeln('- ${_trim(q.prompt, 120)}');
      }
    }

    return _trim(buffer.toString(), 1800);
  }

  Future<String> _buildRevisionContext({
    required Subject subject,
    Chapter? chapter,
    required List<RevisionItem> items,
  }) async {
    final base = await _buildContext('revision', subject, chapter);
    final focus = StringBuffer();
    focus.writeln('Revision focus items:');
    for (final item in items.take(8)) {
      final label = item.type.name;
      final detail = item.detail.trim().isEmpty ? item.title : item.detail;
      focus.writeln('- [$label] ${_trim(item.title, 120)}: ${_trim(detail, 160)}');
    }
    return _trim('$base\n${focus.toString()}', 1800);
  }

  Future<List<Note>> _fetchNotesForChapter(String chapterId) async {
    if (chapterId.isEmpty) return [];
    try {
      final rows = await _client
          .from('notes')
          .select('id,title,short_answer,detailed_answer')
          .eq('chapter_id', chapterId)
          .order('created_at', ascending: false)
          .limit(6);
      return (rows as List<dynamic>)
          .map(
            (row) => Note(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              shortAnswer: row['short_answer']?.toString() ?? '',
              detailedAnswer: row['detailed_answer']?.toString() ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UserNote>> _fetchUserNotesForChapter(String chapterId) async {
    final user = _client.auth.currentUser;
    if (user == null || chapterId.isEmpty) return [];
    try {
      final rows = await _client
          .from('user_notes')
          .select('id,title,short_answer,detailed_answer')
          .eq('user_id', user.id)
          .eq('chapter_id', chapterId)
          .order('created_at', ascending: false)
          .limit(6);
      return (rows as List<dynamic>)
          .map(
            (row) => UserNote(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              shortAnswer: row['short_answer']?.toString() ?? '',
              detailedAnswer: row['detailed_answer']?.toString() ?? '',
              chapterId: chapterId,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ChapterTopic>> _fetchSubtopicsForChapter(
    String chapterId,
  ) async {
    if (chapterId.isEmpty) return [];
    try {
      final rows = await _client
          .from('chapter_subtopics')
          .select('id,title,summary,sort_order')
          .eq('chapter_id', chapterId)
          .order('sort_order', ascending: true)
          .limit(24);
      return (rows as List<dynamic>)
          .map(
            (row) => ChapterTopic(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              summary: row['summary']?.toString() ?? '',
              sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _fetchChapterIdsForSubject(String subjectId) async {
    if (subjectId.isEmpty) return [];
    try {
      final rows = await _client
          .from('chapters')
          .select('id')
          .eq('subject_id', subjectId)
          .order('sort_order', ascending: true)
          .limit(40);
      return (rows as List<dynamic>)
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Note>> _fetchNotesForSubject(String subjectId) async {
    final chapterIds = await _fetchChapterIdsForSubject(subjectId);
    if (chapterIds.isEmpty) return [];
    try {
      final rows = await _client
          .from('notes')
          .select('id,title,short_answer,detailed_answer')
          .inFilter('chapter_id', chapterIds)
          .order('created_at', ascending: false)
          .limit(12);
      return (rows as List<dynamic>)
          .map(
            (row) => Note(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              shortAnswer: row['short_answer']?.toString() ?? '',
              detailedAnswer: row['detailed_answer']?.toString() ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ChapterTopic>> _fetchSubtopicsForSubject(String subjectId) async {
    final chapterIds = await _fetchChapterIdsForSubject(subjectId);
    if (chapterIds.isEmpty) return [];
    try {
      final rows = await _client
          .from('chapter_subtopics')
          .select('id,title,summary,sort_order')
          .inFilter('chapter_id', chapterIds)
          .order('sort_order', ascending: true)
          .limit(40);
      return (rows as List<dynamic>)
          .map(
            (row) => ChapterTopic(
              id: row['id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              summary: row['summary']?.toString() ?? '',
              sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<QuizQuestionItem>> _generateWithOllama({
    required String context,
    required int count,
    required QuizDifficulty baseDifficulty,
    required String model,
    String? nonce,
  }) async {
    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final nonceLine = nonce == null
        ? ''
        : 'Unique seed: $nonce. Do not repeat any previously asked questions.\n';
    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. $nonceLine'
        'Cover different chapters and subtopics when available. '
        'Avoid repeating the same topic.\n'
        'Use the context below.\n\n$context';

    final uri = Uri.parse('${SupabaseConfig.ollamaBaseUrl}/api/chat');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
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
    final raw = (data['message']?['content'] as String?)?.trim() ?? '';
    if (raw.isEmpty) {
      return [];
    }

    final jsonText = _extractJson(raw);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = decoded['questions'] as List<dynamic>? ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;

    final questions = <QuizQuestionItem>[];
    for (var i = 0; i < list.length; i += 1) {
      final item = list[i] as Map<String, dynamic>;
      var options = _normalizeOptions(item);
      if (options.length < 2) {
        continue;
      }
      var correctIndex = _normalizeCorrectIndex(item, options);
      if (options.length > 4) {
        options = options.take(4).toList();
        if (correctIndex >= options.length) {
          correctIndex = 0;
        }
      }
      questions.add(
        QuizQuestionItem(
          id: 'ai_${now}_$i',
          prompt: item['prompt']?.toString() ?? 'Question',
          options: options,
          correctIndex: correctIndex,
          topic: item['topic']?.toString(),
          difficulty: item['difficulty']?.toString().toLowerCase(),
          explanation: item['explanation']?.toString(),
        ),
      );
    }
    return questions;
  }

  Future<List<QuizQuestionItem>> _generateWithLocalAi({
    required String mode,
    required String context,
    required int count,
    required QuizDifficulty baseDifficulty,
    String? ollamaModel,
    String? nonce,
  }) async {
    if (mode == 'ollama') {
      return _generateWithOllama(
        context: context,
        count: count,
        baseDifficulty: baseDifficulty,
        model: ollamaModel ?? SupabaseConfig.ollamaModelQuiz,
        nonce: nonce,
      );
    }

    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final nonceLine = nonce == null
        ? ''
        : 'Unique seed: $nonce. Do not repeat any previously asked questions.\n';
    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. $nonceLine'
        'Cover different chapters and subtopics when available. '
        'Avoid repeating the same topic.\n'
        'Use the context below.\n\n$context';

    final uri =
        Uri.parse('${SupabaseConfig.lmStudioBaseUrl}/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
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
    String raw = '';
    if (choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          raw = content?.toString() ?? '';
        }
      }
    }
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      return [];
    }

    final jsonText = _extractJson(cleaned);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = decoded['questions'] as List<dynamic>? ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;

    final questions = <QuizQuestionItem>[];
    for (var i = 0; i < list.length; i += 1) {
      final item = list[i] as Map<String, dynamic>;
      var options = _normalizeOptions(item);
      if (options.length < 2) {
        continue;
      }
      var correctIndex = _normalizeCorrectIndex(item, options);
      if (options.length > 4) {
        options = options.take(4).toList();
        if (correctIndex >= options.length) {
          correctIndex = 0;
        }
      }
      questions.add(
        QuizQuestionItem(
          id: 'ai_${now}_$i',
          prompt: item['prompt']?.toString() ?? 'Question',
          options: options,
          correctIndex: correctIndex,
          topic: item['topic']?.toString(),
          difficulty: item['difficulty']?.toString().toLowerCase(),
          explanation: item['explanation']?.toString(),
        ),
      );
    }
    return questions;
  }

  Future<List<QuizQuestionItem>> _generateWithBackend({
    required String context,
    required int count,
    required QuizDifficulty baseDifficulty,
    String? nonce,
  }) async {
    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final nonceLine = nonce == null
        ? ''
        : 'Unique seed: $nonce. Do not repeat any previously asked questions.\n';
    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. $nonceLine'
        'Cover different chapters and subtopics when available. '
        'Avoid repeating the same topic.\n'
        'Use the context below.\n\n$context';

    final response = await _client.functions.invoke(
      'ai-generate',
      body: {
        'system_prompt': systemPrompt,
        'user_prompt': userPrompt,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final raw = data['reply']?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return [];
    }

    final jsonText = _extractJson(raw);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    final list = decoded['questions'] as List<dynamic>? ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;

    final questions = <QuizQuestionItem>[];
    for (var i = 0; i < list.length; i += 1) {
      final item = list[i] as Map<String, dynamic>;
      var options = _normalizeOptions(item);
      if (options.length < 2) {
        continue;
      }
      var correctIndex = _normalizeCorrectIndex(item, options);
      if (options.length > 4) {
        options = options.take(4).toList();
        if (correctIndex >= options.length) {
          correctIndex = 0;
        }
      }
      questions.add(
        QuizQuestionItem(
          id: 'ai_${now}_$i',
          prompt: item['prompt']?.toString() ?? 'Question',
          options: options,
          correctIndex: correctIndex,
          topic: item['topic']?.toString(),
          difficulty: item['difficulty']?.toString().toLowerCase(),
          explanation: item['explanation']?.toString(),
        ),
      );
    }
    return questions;
  }

  bool _isLmStudio(String mode) =>
      mode == 'lmstudio' || mode == 'lm-studio' || mode == 'lm_studio';

  bool _looksLikeUuid(String value) =>
      RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(value);

  Future<String> _requestWithBackend(
    String systemPrompt,
    String userPrompt,
  ) async {
    final response = await _client.functions.invoke(
      'ai-generate',
      body: {
        'system_prompt': systemPrompt,
        'user_prompt': userPrompt,
      },
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    return data['reply']?.toString() ?? '';
  }

  Future<String> _requestWithLocalAi(
    String mode,
    String systemPrompt,
    String userPrompt,
    {String? ollamaModel}
  ) async {
    if (mode == 'ollama') {
      final uri =
          Uri.parse('${SupabaseConfig.ollamaBaseUrl}/api/chat');
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': ollamaModel ?? SupabaseConfig.ollamaModelQuiz,
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
      return (data['message']?['content'] as String?)?.trim() ?? '';
    }

    final uri =
        Uri.parse('${SupabaseConfig.lmStudioBaseUrl}/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
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
    if (choices.isEmpty) return '';
    final first = choices.first;
    if (first is Map<String, dynamic>) {
      final message = first['message'];
      if (message is Map<String, dynamic>) {
        return message['content']?.toString().trim() ?? '';
      }
    }
    return '';
  }

  Future<List<QuizQuestionItem>> _fallbackFromDb(
    String quizId,
    int count,
  ) async {
    final data = await _client
        .from('quiz_questions')
        .select('id,prompt,options,correct_index,topic,explanation')
        .eq('quiz_id', quizId)
        .limit(count);

    return (data as List<dynamic>).map((row) {
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
  }

  Future<List<QuizQuestionItem>> _fallbackExamFromDb({
    required Subject subject,
    Chapter? chapter,
    required int count,
  }) async {
    final chapterIds = chapter != null
        ? [chapter.id]
        : await _fetchChapterIdsForSubject(subject.id);
    if (chapterIds.isEmpty) return [];

    final quizRows = await _client
        .from('quizzes')
        .select('id')
        .inFilter('chapter_id', chapterIds)
        .limit(40);
    final quizIds = (quizRows as List<dynamic>)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (quizIds.isEmpty) return [];

    final data = await _client
        .from('quiz_questions')
        .select('id,prompt,options,correct_index,topic,explanation')
        .inFilter('quiz_id', quizIds)
        .order('created_at', ascending: false)
        .limit(count);

    return (data as List<dynamic>).map((row) {
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
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return text;
    }
    return text.substring(start, end + 1);
  }

  String _trim(String value, int max) {
    if (value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }

  String _difficultyMix(QuizDifficulty base) {
    switch (base) {
      case QuizDifficulty.easy:
        return '60% easy, 30% medium, 10% hard';
      case QuizDifficulty.medium:
        return '30% easy, 40% medium, 30% hard';
      case QuizDifficulty.hard:
        return '10% easy, 30% medium, 60% hard';
    }
  }

  List<String> _normalizeOptions(Map<String, dynamic> item) {
    final raw = item['options'] ?? item['choices'] ?? item['answers'];
    final parsed = _parseOptions(raw);
    final cleaned = parsed
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    if (_looksLikeLabelsOnly(cleaned)) {
      final prompt = item['prompt']?.toString();
      if (prompt != null) {
        final fromPrompt = _splitOptions(prompt)
            .map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList();
        if (fromPrompt.length >= 2 && !_looksLikeLabelsOnly(fromPrompt)) {
          return fromPrompt;
        }
      }
      return [];
    }
    return cleaned;
  }

  List<String> _parseOptions(dynamic raw) {
    if (raw == null) {
      return [];
    }
    if (raw is List) {
      final options =
          raw.map((entry) => _optionValue(entry)).whereType<String>().toList();
      if (options.length == 1) {
        final split = _splitOptions(options.first);
        return split.isNotEmpty ? split : options;
      }
      return options;
    }
    if (raw is Map) {
      final ordered = <String>[];
      for (final label in const ['A', 'B', 'C', 'D', '1', '2', '3', '4']) {
        if (raw.containsKey(label)) {
          final value = _optionValue(raw[label]);
          if (value != null) {
            ordered.add(value);
          }
        }
      }
      if (ordered.isNotEmpty) {
        return ordered;
      }
      return raw.values
          .map((value) => _optionValue(value))
          .whereType<String>()
          .toList();
    }
    if (raw is String) {
      return _splitOptions(raw);
    }
    return [];
  }

  String? _optionValue(dynamic entry) {
    if (entry == null) {
      return null;
    }
    if (entry is String) {
      return _stripLabel(entry);
    }
    if (entry is Map) {
      final text = entry['text'] ??
          entry['option'] ??
          entry['answer'] ??
          entry['value'];
      if (text != null) {
        return _stripLabel(text.toString());
      }
      if (entry.isNotEmpty) {
        return _stripLabel(entry.values.first.toString());
      }
      return null;
    }
    return _stripLabel(entry.toString());
  }

  String _stripLabel(String value) {
    return value.replaceFirst(RegExp(r'^[A-Da-d1-4][\).:\-]\s*'), '');
  }

  List<String> _splitOptions(String text) {
    final cleaned = text.replaceAll('\r', '').trim();
    if (cleaned.isEmpty) {
      return [];
    }
    final labelPattern = RegExp(r'([A-Da-d1-4])[\).:\-]\s*');
    final matches = labelPattern.allMatches(cleaned).toList();
    if (matches.length >= 2) {
      final options = <String>[];
      for (var i = 0; i < matches.length; i += 1) {
        final start = matches[i].end;
        final end = i + 1 < matches.length ? matches[i + 1].start : cleaned.length;
        final part = cleaned.substring(start, end).trim();
        if (part.isNotEmpty) {
          options.add(part);
        }
      }
      return options;
    }
    final parts = cleaned.split(RegExp(r'\n+|;|\s+\|\s+'));
    final trimmed = parts.map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (trimmed.length > 1) {
      return trimmed;
    }
    return trimmed;
  }

  bool _looksLikeLabelsOnly(List<String> options) {
    if (options.isEmpty) {
      return true;
    }
    final normalized = options
        .map((option) =>
            option.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase())
        .where((option) => option.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return true;
    }
    const labels = {'A', 'B', 'C', 'D', '1', '2', '3', '4'};
    if (normalized.length <= 4 && normalized.every(labels.contains)) {
      return true;
    }
    return false;
  }

  int _normalizeCorrectIndex(
    Map<String, dynamic> item,
    List<String> options,
  ) {
    final raw = item['correct_index'] ??
        item['correct'] ??
        item['correct_option'] ??
        item['answer'];
    if (raw is num) {
      final idx = raw.toInt();
      if (idx >= 0 && idx < options.length) {
        return idx;
      }
      if (idx > 0 && idx <= options.length) {
        return idx - 1;
      }
    }
    if (raw is String) {
      final value = raw.trim();
      if (RegExp(r'^[A-Da-d]$').hasMatch(value)) {
        final letter = value.toUpperCase();
        return letter.codeUnitAt(0) - 'A'.codeUnitAt(0);
      }
      if (RegExp(r'^\d+$').hasMatch(value)) {
        final idx = int.tryParse(value) ?? 0;
        if (idx >= 0 && idx < options.length) {
          return idx;
        }
        if (idx > 0 && idx <= options.length) {
          return idx - 1;
        }
      }
      final match = options.indexWhere(
        (option) => option.toLowerCase() == value.toLowerCase(),
      );
      if (match >= 0) {
        return match;
      }
    }
    return 0;
  }
}

class WrittenQuestion {
  final String prompt;
  final int marks;
  final String? topic;
  final String? difficulty;

  const WrittenQuestion({
    required this.prompt,
    required this.marks,
    this.topic,
    this.difficulty,
  });
}

class WrittenGrade {
  final int score;
  final int maxScore;
  final String feedback;
  final String modelAnswer;
  final String formatTips;

  const WrittenGrade({
    required this.score,
    required this.maxScore,
    required this.feedback,
    required this.modelAnswer,
    required this.formatTips,
  });
}
