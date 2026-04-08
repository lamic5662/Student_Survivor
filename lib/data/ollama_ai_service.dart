import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:student_survivor/data/supabase_config.dart';

class OllamaAiService {
  Future<String> answer(String message, {String? mode}) async {
    final baseUrl = SupabaseConfig.ollamaBaseUrl;
    final model = SupabaseConfig.ollamaModelChat;
    final systemPrompt = _buildSystemPrompt(mode);

    final uri = Uri.parse('$baseUrl/api/chat');
    final response = await http.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'stream': false,
        'keep_alive': SupabaseConfig.ollamaKeepAlive,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': message},
        ],
      }),
    ).timeout(SupabaseConfig.ollamaTimeoutChat);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ollama error: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reply =
        (data['message']?['content'] as String?)?.trim() ?? '';
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
