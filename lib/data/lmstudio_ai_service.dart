import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:student_survivor/data/supabase_config.dart';

class LmStudioAiService {
  Future<String> answer(String message, {String? mode}) async {
    final baseUrl = SupabaseConfig.lmStudioBaseUrl;
    final model = SupabaseConfig.lmStudioModel;
    final apiKey = SupabaseConfig.lmStudioApiKey;
    final systemPrompt = _buildSystemPrompt(mode);

    final uri = Uri.parse('$baseUrl/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'model': model,
        'temperature': 0.4,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': message},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('LM Studio error: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      return 'No response from model.';
    }
    final content = (choices.first as Map<String, dynamic>)['message']
            ?['content']
        as String?;
    final reply = content?.trim() ?? '';
    return reply.isEmpty ? 'No response from model.' : reply;
  }

  String _buildSystemPrompt(String? mode) {
    const base =
        'You are a concise study assistant for BCA TU students. Answer clearly.';
    if (mode == null) {
      return base;
    }
    final normalized = mode.toLowerCase();
    if (normalized.contains('short')) {
      return '$base Provide a short 5-mark style answer.';
    }
    if (normalized.contains('long')) {
      return '$base Provide a detailed 10-mark style answer.';
    }
    if (normalized.contains('simple')) {
      return '$base Explain in very simple language.';
    }
    if (normalized.contains('exam')) {
      return '$base Suggest important exam questions related to the topic.';
    }
    return base;
  }
}
