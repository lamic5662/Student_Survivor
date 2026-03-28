import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class AiQuizService {
  final SupabaseClient _client;

  AiQuizService(this._client);

  Future<List<QuizQuestionItem>> generateQuestions({
    required String quizId,
    required Subject subject,
    Chapter? chapter,
    required int count,
    required QuizDifficulty baseDifficulty,
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
              )
            : await _generateWithLocalAi(
                mode: mode,
                context: context,
                count: count,
                baseDifficulty: baseDifficulty,
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

  Future<String> _buildContext(
    String quizId,
    Subject subject,
    Chapter? chapter,
  ) async {
    Chapter? resolvedChapter = chapter;
    if (resolvedChapter == null) {
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
    }

    final buffer = StringBuffer();
    buffer.writeln('Subject: ${subject.name} (${subject.code})');
    if (resolvedChapter != null) {
      buffer.writeln('Chapter: ${resolvedChapter.title}');
    }

    final notes = resolvedChapter?.notes ?? const <Note>[];
    if (notes.isNotEmpty) {
      buffer.writeln('Key notes:');
      for (final note in notes.take(4)) {
        final text = note.shortAnswer.isNotEmpty
            ? note.shortAnswer
            : note.detailedAnswer;
        buffer.writeln('- ${note.title}: ${_trim(text, 120)}');
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

  Future<List<QuizQuestionItem>> _generateWithOllama({
    required String context,
    required int count,
    required QuizDifficulty baseDifficulty,
  }) async {
    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. Use the context below.\n\n$context';

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
  }) async {
    if (mode == 'ollama') {
      return _generateWithOllama(
        context: context,
        count: count,
        baseDifficulty: baseDifficulty,
      );
    }

    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. Use the context below.\n\n$context';

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
  }) async {
    final base = baseDifficulty.name;
    final mix = _difficultyMix(baseDifficulty);
    final systemPrompt =
        'You are an expert quiz generator for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"questions":[{"prompt":"...","options":["A","B","C","D"],"correct_index":0,"explanation":"...","topic":"...","difficulty":"easy|medium|hard"}]}\n'
        'Rules: 4 options per question, correct_index is 0-based, no markdown. '
        'Options must be full answer text, not just labels like A/B/C/D.';

    final userPrompt =
        'Generate $count unique MCQ questions. Base difficulty: $base. '
        'Use this mix: $mix. Use the context below.\n\n$context';

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
