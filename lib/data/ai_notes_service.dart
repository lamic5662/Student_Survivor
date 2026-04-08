import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/notes_cache_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class AiFlashcard {
  final String front;
  final String back;

  const AiFlashcard({required this.front, required this.back});
}

class AiNotesService {
  final NotesCacheService _cache;
  final AiRouterService _aiRouter;

  AiNotesService(SupabaseClient client)
      : _cache = NotesCacheService(),
        _aiRouter = AiRouterService(client);

  Future<NoteDraft?> generateNote({
    required Subject subject,
    required Chapter chapter,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.notes).toLowerCase();
    final cached = await _cache.loadAiDraft(
      subjectId: subject.id,
      chapterId: chapter.id,
    );
    if (!_isSupportedAi(mode)) {
      return cached;
    }

    final context = _buildContext(subject, chapter);
    final systemPrompt =
        'You are an expert study assistant for BCA students. Return ONLY valid JSON.\n'
        'Schema: {"title":"...","short_answer":"...","detailed_answer":"..."}\n'
        'Rules: short_answer is 8-12 lines, detailed_answer is 22-32 lines. '
        'Use \\n to separate each line. No markdown or bullet symbols. '
        'Each line must be a complete sentence. Use simple labels like '
        '"Definition:", "Key Idea:", "Core Concept:", "Example:", "Why it matters:" '
        'to improve readability. Include key points, definitions, and 2 simple examples. '
        'Use clear, simple language.';

    final userPrompt =
        'Create a concise study note for the chapter below. Use the context to be accurate.\n\n$context';

    try {
      final raw = await _aiRouter.send(
        AiRequest(
          feature: AiFeature.notes,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          temperature: 0.3,
          expectsJson: true,
          metadata: {
            'subject': subject.name,
            'chapter': chapter.title,
          },
        ),
      );
      if (raw.isEmpty) {
        return cached;
      }

      Map<String, dynamic>? decoded;
      try {
        final jsonText = _extractJson(raw);
        decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      } catch (_) {
        decoded = _attemptLooseParse(raw);
      }

      if (decoded == null) {
        return cached;
      }

      final title = decoded['title']?.toString().trim();
      var shortAnswer = decoded['short_answer']?.toString().trim();
      var detailedAnswer = decoded['detailed_answer']?.toString().trim();

      if (title == null ||
          title.isEmpty ||
          shortAnswer == null ||
          shortAnswer.isEmpty ||
          detailedAnswer == null ||
          detailedAnswer.isEmpty) {
        return cached;
      }

      final draft = NoteDraft(
        title: title,
        shortAnswer: _normalizeLines(shortAnswer, minLines: 8, maxLines: 12),
        detailedAnswer:
            _normalizeLines(detailedAnswer, minLines: 22, maxLines: 32),
      );
      await _cache.cacheAiDraft(
        subjectId: subject.id,
        chapterId: chapter.id,
        draft: draft,
      );
      return draft;
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<String> defineWord({
    required String word,
    required String context,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.notes).toLowerCase();
    if (!_isSupportedAi(mode)) {
      throw Exception('AI unavailable. Check AI settings.');
    }

    final systemPrompt =
        'You are a concise dictionary assistant for BCA students. '
        'Return ONLY valid JSON.\n'
        'Schema: {"meaning":"...","example":"..."}\n'
        'Rules: meaning is 1-2 sentences. example is 1 simple sentence. '
        'No markdown.';

    final safeContext = _trim(context.replaceAll(RegExp(r'\s+'), ' '), 600);
    final userPrompt =
        'Define the word in simple terms for this context.\n'
        'Word: "$word"\n'
        'Context:\n$safeContext';

    final raw = await _aiRouter.send(
      AiRequest(
        feature: AiFeature.notes,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.2,
        fastModel: true,
        expectsJson: true,
        metadata: {
          'word': word,
        },
      ),
    );
    if (raw.isEmpty) {
      throw Exception('AI returned empty definition.');
    }

    try {
      final jsonText = _extractJson(raw);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final meaning = decoded['meaning']?.toString().trim();
      final example = decoded['example']?.toString().trim();
      if (meaning != null && meaning.isNotEmpty) {
        if (example != null && example.isNotEmpty) {
          return '$meaning\nExample: $example';
        }
        return meaning;
      }
    } catch (_) {
      // Fall back to raw text below.
    }

    return raw;
  }

  Future<List<AiFlashcard>> generateFlashcards({
    required Subject subject,
    required Chapter chapter,
    int count = 8,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.game).toLowerCase();
    if (!_isSupportedAi(mode)) {
      throw Exception('AI unavailable. Check AI settings.');
    }

    final context = _buildContext(subject, chapter);
    final systemPrompt =
        'You are an expert study assistant for BCA students. Return ONLY valid JSON.\n'
        'Schema: [{"front":"...","back":"..."}]\n'
        'Rules: Return a JSON array only (not an object). '
        'front is a short question or key term, back is 1-3 sentences. '
        'No markdown, no code fences, no bullet symbols, no extra text.';

    final userPrompt =
        'Create $count flashcards for the chapter below. Use the context to be accurate.\n\n$context';

    final raw = await _aiRouter.send(
      AiRequest(
        feature: AiFeature.game,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        expectsJson: true,
        metadata: {
          'subject': subject.name,
          'chapter': chapter.title,
        },
      ),
    );
    if (raw.isEmpty) {
      throw Exception('AI returned empty flashcards.');
    }

    final cards = _parseFlashcards(raw);
    if (cards.isEmpty) {
      throw Exception('AI flashcards format invalid. Try again.');
    }
    return cards;
  }

  Future<String> generateAnswerFromNotes({
    required String question,
    required String content,
    int points = 5,
  }) async {
    final mode =
        SupabaseConfig.aiProviderFor(AiFeature.notes).toLowerCase();
    if (!_isSupportedAi(mode)) {
      throw Exception('AI unavailable. Check AI settings.');
    }
    final safeQuestion = question.trim();
    final safeContent = _trim(content.replaceAll(RegExp(r'\s+'), ' '), 2000);
    final systemPrompt =
        'You are a study coach for BCA students. Use ONLY the provided notes. '
        'Return a point-wise answer with marks per point. No markdown.';
    final userPrompt =
        'Question:\n$safeQuestion\n\n'
        'Notes:\n$safeContent\n\n'
        'Write $points concise points, each ending with "(2 marks)" unless the question '
        'already specifies marks. Keep each point 1-2 sentences.';

    final raw = await _aiRouter.send(
      AiRequest(
        feature: AiFeature.notes,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: 0.3,
        metadata: {
          'question': safeQuestion,
          'points': points,
        },
      ),
    );
    if (raw.isEmpty) {
      throw Exception('AI returned empty answer.');
    }
    return raw.trim();
  }

  String _buildContext(Subject subject, Chapter chapter) {
    final buffer = StringBuffer();
    buffer.writeln('Subject: ${subject.name} (${subject.code})');
    buffer.writeln('Chapter: ${chapter.title}');
    if (chapter.subtopics.isNotEmpty) {
      buffer.writeln('Subtopics:');
      for (final subtopic in chapter.subtopics.take(12)) {
        buffer.writeln('- ${_trim(subtopic.title, 120)}');
      }
    }

    if (chapter.notes.isNotEmpty) {
      buffer.writeln('Existing notes:');
      for (final note in chapter.notes.take(3)) {
        final text = note.shortAnswer.isNotEmpty
            ? note.shortAnswer
            : note.detailedAnswer;
        buffer.writeln('- ${note.title}: ${_trim(text, 120)}');
      }
    }

    if (chapter.importantQuestions.isNotEmpty) {
      buffer.writeln('Important questions:');
      for (final q in chapter.importantQuestions.take(3)) {
        buffer.writeln('- ${_trim(q.prompt, 120)}');
      }
    }

    return _trim(buffer.toString(), 2500);
  }

  String _extractJson(String text) {
    final fenceStart = text.indexOf('```');
    if (fenceStart != -1) {
      final fenceEnd = text.indexOf('```', fenceStart + 3);
      if (fenceEnd != -1) {
        var fenced = text.substring(fenceStart + 3, fenceEnd).trim();
        if (fenced.toLowerCase().startsWith('json')) {
          fenced = fenced.substring(4).trim();
        }
        if (fenced.isNotEmpty) {
          return fenced;
        }
      }
    }
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    final bracketStart = text.indexOf('[');
    final bracketEnd = text.lastIndexOf(']');

    if (bracketStart != -1 &&
        bracketEnd != -1 &&
        bracketEnd > bracketStart &&
        (braceStart == -1 || bracketStart < braceStart)) {
      return text.substring(bracketStart, bracketEnd + 1);
    }

    if (braceStart != -1 && braceEnd != -1 && braceEnd > braceStart) {
      return text.substring(braceStart, braceEnd + 1);
    }

    return text;
  }

  List<AiFlashcard> _parseFlashcards(String raw) {
    try {
      final jsonText = _extractJson(raw);
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(_mapToFlashcard)
            .whereType<AiFlashcard>()
            .toList();
      }
      if (decoded is Map<String, dynamic>) {
        final list = decoded['cards'];
        if (list is List) {
          return list
              .whereType<Map<String, dynamic>>()
              .map(_mapToFlashcard)
              .whereType<AiFlashcard>()
              .toList();
        }
      }
    } catch (_) {
      // fallthrough to loose parse
    }

    return _parseFlashcardsLoose(raw);
  }

  AiFlashcard? _mapToFlashcard(Map<String, dynamic> item) {
    final front = item['front']?.toString().trim();
    final back = item['back']?.toString().trim();
    if (front == null || front.isEmpty || back == null || back.isEmpty) {
      return null;
    }
    return AiFlashcard(front: front, back: back);
  }

  List<AiFlashcard> _parseFlashcardsLoose(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return [];
    }

    final cards = <AiFlashcard>[];
    String? pendingFront;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('front:') || lower.startsWith('term:')) {
        pendingFront = line.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('back:') || lower.startsWith('definition:')) {
        final back = line.split(':').skip(1).join(':').trim();
        final front = pendingFront;
        if (front != null && front.isNotEmpty && back.isNotEmpty) {
          cards.add(AiFlashcard(front: front, back: back));
        }
        pendingFront = null;
        continue;
      }
      if (lower.startsWith('q:') || lower.startsWith('question:')) {
        pendingFront = line.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('a:') || lower.startsWith('answer:')) {
        final back = line.split(':').skip(1).join(':').trim();
        final front = pendingFront;
        if (front != null && front.isNotEmpty && back.isNotEmpty) {
          cards.add(AiFlashcard(front: front, back: back));
        }
        pendingFront = null;
        continue;
      }

      final pair = _splitPairLine(line);
      if (pair != null) {
        cards.add(pair);
        pendingFront = null;
      }
    }

    return cards;
  }

  AiFlashcard? _splitPairLine(String line) {
    final match = RegExp(r'^(.*?)\s*[-–:]\s+(.*)$').firstMatch(line);
    if (match == null) {
      return null;
    }
    final front = match.group(1)?.trim() ?? '';
    final back = match.group(2)?.trim() ?? '';
    if (front.length < 2 || back.length < 3) {
      return null;
    }
    return AiFlashcard(front: front, back: back);
  }

  Map<String, dynamic>? _attemptLooseParse(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_stripBullet)
        .toList();
    if (lines.isEmpty) {
      return null;
    }

    String? title;
    final shortLines = <String>[];
    final detailedLines = <String>[];
    String section = 'short';

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('title:') || lower.startsWith('topic:')) {
        title = line.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('short') || lower.startsWith('summary:')) {
        section = 'short';
        final content = line.split(':').skip(1).join(':').trim();
        if (content.isNotEmpty) {
          shortLines.add(content);
        }
        continue;
      }
      if (lower.startsWith('detailed') ||
          lower.startsWith('explanation') ||
          lower.startsWith('long')) {
        section = 'detailed';
        final content = line.split(':').skip(1).join(':').trim();
        if (content.isNotEmpty) {
          detailedLines.add(content);
        }
        continue;
      }

      if (section == 'short') {
        shortLines.add(line);
      } else {
        detailedLines.add(line);
      }
    }

    title ??= lines.first;
    if (shortLines.isEmpty && lines.length > 1) {
      shortLines.addAll(lines.skip(1).take(5));
    }
    if (detailedLines.isEmpty && lines.length > 3) {
      detailedLines.addAll(lines.skip(3));
    }

    if (title.isEmpty || shortLines.isEmpty || detailedLines.isEmpty) {
      return null;
    }

    return {
      'title': title,
      'short_answer': shortLines.join('\n'),
      'detailed_answer': detailedLines.join('\n'),
    };
  }

  String _stripBullet(String line) {
    return line.replaceFirst(RegExp(r'^\s*[-*•\d\)\.]+\s+'), '');
  }

  String _normalizeLines(String text,
      {required int minLines, required int maxLines}) {
    var lines = _splitLines(text);
    if (lines.length < minLines) {
      lines = _splitMore(lines);
    }
    if (lines.length > maxLines) {
      lines = lines.take(maxLines).toList();
    }
    return lines.join('\n');
  }

  List<String> _splitLines(String text) {
    final rawLines = text.split('\n');
    final cleaned = rawLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (cleaned.length >= 2) {
      return cleaned;
    }
    return _splitSentences(text);
  }

  List<String> _splitSentences(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (sentences.isNotEmpty) {
      return sentences;
    }
    return [text.trim()];
  }

  List<String> _splitMore(List<String> lines) {
    final expanded = <String>[];
    for (final line in lines) {
      final parts = line
          .split(RegExp(r'(?<=[;:])\s+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
      expanded.addAll(parts);
    }
    return expanded.isEmpty ? lines : expanded;
  }

  bool _isSupportedAi(String mode) =>
      mode == 'ollama' ||
      _isLmStudio(mode) ||
      mode == 'backend' ||
      mode == 'openrouter' ||
      mode == 'groq' ||
      mode == 'gemini' ||
      mode == 'cloud' ||
      mode == 'auto';

  bool _isLmStudio(String mode) {
    return mode == 'lmstudio' || mode == 'lm-studio' || mode == 'lm_studio';
  }

  // AiRequestHelper handles provider routing and fallbacks.

  String _trim(String value, int max) {
    if (value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }
}
