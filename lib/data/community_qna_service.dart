import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class CommunityQnaService {
  final SupabaseClient _client;

  CommunityQnaService(this._client);

  Future<List<CommunityQuestion>> fetchQuestionsForSubject(
    String subjectId,
  ) async {
    if (subjectId.isEmpty) return [];
    final data = await _client
        .from('community_questions')
        .select(
          'id,subject_id,user_id,question,status,ai_valid,ai_reason,created_at',
        )
        .eq('subject_id', subjectId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => _questionFromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityAnswer>> fetchAnswers(String questionId) async {
    if (questionId.isEmpty) return [];
    final data = await _client
        .from('community_answers')
        .select('id,question_id,user_id,answer,created_at')
        .eq('question_id', questionId)
        .order('created_at', ascending: true);

    return (data as List<dynamic>)
        .map((row) => _answerFromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityQuestion> submitQuestion({
    required Subject subject,
    required String question,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to ask a question.');
    }

    final verification = await _verifyQuestion(
      subjectName: subject.name,
      question: question,
    );

    final status = verification.isValid ? 'approved' : 'pending';
    final inserted = await _client.from('community_questions').insert({
      'subject_id': subject.id,
      'user_id': user.id,
      'question': question,
      'status': status,
      'ai_valid': verification.isValid,
      'ai_reason': verification.reason,
    }).select(
      'id,subject_id,user_id,question,status,ai_valid,ai_reason,created_at',
    ).single();

    return _questionFromMap(inserted);
  }

  Future<void> addAnswer({
    required String questionId,
    required String answer,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign in to answer.');
    }
    await _client.from('community_answers').insert({
      'question_id': questionId,
      'user_id': user.id,
      'answer': answer,
    });
  }

  Future<void> approveQuestion(String questionId) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('community_questions').update({
      'status': 'approved',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', questionId);
  }

  Future<void> rejectQuestion(
    String questionId, {
    String? adminReason,
  }) async {
    final adminId = _client.auth.currentUser?.id;
    await _client.from('community_questions').update({
      'status': 'rejected',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'admin_reason': adminReason,
    }).eq('id', questionId);
  }

  Future<_VerificationResult> _verifyQuestion({
    required String subjectName,
    required String question,
  }) async {
    if (_looksInvalid(question)) {
      return const _VerificationResult(
        isValid: false,
        reason: 'Question is too short or unclear.',
      );
    }

    final provider =
        SupabaseConfig.aiProviderFor(AiFeature.tutor).toLowerCase();
    if (provider == 'free') {
      return _quickValidate(subjectName, question);
    }

    final systemPrompt =
        'You are an academic content validator. Return ONLY valid JSON.\n'
        'Schema: {"is_valid":true|false,"reason":"..."}\n'
        'Rules: The question must be relevant to the subject, clear, and '
        'appropriate for study. If unclear or unrelated, mark invalid with '
        'a short reason (max 12 words).';
    final userPrompt = 'Subject: $subjectName\nQuestion: $question';

    try {
      final raw = await _requestAi(
        provider: provider,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      final jsonText = _extractJson(raw);
      final decoded = jsonDecode(jsonText) as Map<String, dynamic>;
      final isValid = decoded['is_valid'] == true;
      final reason = decoded['reason']?.toString().trim();
      return _VerificationResult(
        isValid: isValid,
        reason: reason?.isEmpty == false
            ? reason
            : (isValid ? 'Valid question.' : 'Needs review.'),
      );
    } catch (_) {
      return _quickValidate(subjectName, question);
    }
  }

  Future<String> _requestAi({
    required String provider,
    required String systemPrompt,
    required String userPrompt,
  }) async {
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
          'temperature': 0.2,
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

  _VerificationResult _quickValidate(String subject, String question) {
    final normalized = question.toLowerCase();
    if (_looksInvalid(question)) {
      return const _VerificationResult(
        isValid: false,
        reason: 'Question is too short or unclear.',
      );
    }
    if (!normalized.contains('?') && question.split(' ').length < 6) {
      return const _VerificationResult(
        isValid: false,
        reason: 'Add more detail to the question.',
      );
    }
    return _VerificationResult(
      isValid: true,
      reason: 'Looks relevant to $subject.',
    );
  }

  bool _looksInvalid(String question) {
    final trimmed = question.trim();
    return trimmed.length < 10;
  }

  CommunityQuestion _questionFromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at']?.toString();
    return CommunityQuestion(
      id: map['id']?.toString() ?? '',
      subjectId: map['subject_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      question: map['question']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      aiValid: map['ai_valid'] == true,
      aiReason: map['ai_reason']?.toString(),
      createdAt:
          createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    );
  }

  CommunityAnswer _answerFromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['created_at']?.toString();
    return CommunityAnswer(
      id: map['id']?.toString() ?? '',
      questionId: map['question_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      answer: map['answer']?.toString() ?? '',
      createdAt:
          createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    );
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return text;
    }
    return text.substring(start, end + 1);
  }
}

class _VerificationResult {
  final bool isValid;
  final String? reason;

  const _VerificationResult({
    required this.isValid,
    this.reason,
  });
}
