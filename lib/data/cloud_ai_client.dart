import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:student_survivor/data/ai_response.dart';

class CloudAiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isRateLimit;

  CloudAiException(
    this.message, {
    this.statusCode,
    this.isRateLimit = false,
  });

  @override
  String toString() => message;
}

class CloudAiClient {
  static Future<AiResponse> openRouterChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required Duration timeout,
    String baseUrl = 'https://openrouter.ai/api/v1',
    String? appTitle,
    String? appUrl,
    double temperature = 0.3,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw CloudAiException('OpenRouter API key missing.');
    }
    final uri = Uri.parse('$baseUrl/chat/completions');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
    if (appTitle != null && appTitle.trim().isNotEmpty) {
      headers['X-Title'] = appTitle.trim();
    }
    if (appUrl != null && appUrl.trim().isNotEmpty) {
      headers['HTTP-Referer'] = appUrl.trim();
    }
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'model': model,
            'temperature': temperature,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAiException(
        'OpenRouter error: ${response.body}',
        statusCode: response.statusCode,
        isRateLimit: response.statusCode == 429 || response.statusCode == 503,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw CloudAiException('OpenRouter returned empty response.');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>? ?? {};
    final usage = data['usage'] as Map<String, dynamic>?;
    return AiResponse(
      content: message['content']?.toString().trim() ?? '',
      provider: 'openrouter',
      model: data['model']?.toString() ?? model,
      usage: AiUsage.fromJson(usage),
    );
  }

  static Future<AiResponse> groqChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required Duration timeout,
    String baseUrl = 'https://api.groq.com/openai/v1',
    double temperature = 0.3,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw CloudAiException('Groq API key missing.');
    }
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'temperature': temperature,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAiException(
        'Groq error: ${response.body}',
        statusCode: response.statusCode,
        isRateLimit: response.statusCode == 429 || response.statusCode == 503,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw CloudAiException('Groq returned empty response.');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>? ?? {};
    final usage = data['usage'] as Map<String, dynamic>?;
    return AiResponse(
      content: message['content']?.toString().trim() ?? '',
      provider: 'groq',
      model: data['model']?.toString() ?? model,
      usage: AiUsage.fromJson(usage),
    );
  }

  static Future<AiResponse> geminiChat({
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required Duration timeout,
    String baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    double temperature = 0.3,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw CloudAiException('Gemini API key missing.');
    }
    final uri = Uri.parse('$baseUrl/models/$model:generateContent?key=$apiKey');
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': userPrompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': temperature,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudAiException(
        'Gemini error: ${response.body}',
        statusCode: response.statusCode,
        isRateLimit: response.statusCode == 429 || response.statusCode == 503,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? [];
    if (candidates.isEmpty) {
      throw CloudAiException('Gemini returned empty response.');
    }
    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>? ??
            {};
    final parts = content['parts'] as List<dynamic>? ?? [];
    if (parts.isEmpty) {
      throw CloudAiException('Gemini returned empty response.');
    }
    final usage = data['usageMetadata'] as Map<String, dynamic>?;
    final usageMapped = usage == null
        ? null
        : AiUsage(
            promptTokens:
                AiUsage.fromJson({'prompt_tokens': usage['promptTokenCount']})
                    ?.promptTokens,
            completionTokens: AiUsage.fromJson({
              'completion_tokens': usage['candidatesTokenCount']
            })?.completionTokens,
            totalTokens:
                AiUsage.fromJson({'total_tokens': usage['totalTokenCount']})
                    ?.totalTokens,
          );
    return AiResponse(
      content: parts.first['text']?.toString().trim() ?? '',
      provider: 'gemini',
      model: data['model']?.toString() ?? model,
      usage: usageMapped,
    );
  }
}
