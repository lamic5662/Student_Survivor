import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/ai_response.dart';
import 'package:student_survivor/data/cloud_ai_client.dart';
import 'package:student_survivor/data/supabase_config.dart';

class AiRequestHelper {
  AiRequestHelper(this._client);

  final SupabaseClient _client;

  Future<AiResponse> sendChat({
    required AiFeature feature,
    required String systemPrompt,
    required String userPrompt,
    double temperature = 0.3,
    bool fastModel = false,
    Duration? timeoutOverride,
    List<String>? providersOverride,
  }) async {
    final providers =
        providersOverride ?? SupabaseConfig.aiProviderOrder(feature);
    Exception? lastError;
    for (final provider in providers) {
      try {
        final timeout = timeoutOverride ??
            _timeoutForProvider(
              provider: provider,
              feature: feature,
              fastModel: fastModel,
            );
        switch (provider) {
          case 'openrouter':
            final reply = await CloudAiClient.openRouterChat(
              apiKey: SupabaseConfig.openRouterApiKey,
              baseUrl: SupabaseConfig.openRouterBaseUrl,
              model: fastModel
                  ? SupabaseConfig.openRouterModelFast
                  : SupabaseConfig.openRouterModelForFeature(feature),
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              temperature: temperature,
              timeout: timeout,
              appTitle: SupabaseConfig.openRouterAppTitle,
              appUrl: SupabaseConfig.openRouterAppUrl,
            );
            SupabaseConfig.updateLastAiProvider('openrouter');
            return reply;
          case 'groq':
            final reply = await CloudAiClient.groqChat(
              apiKey: SupabaseConfig.groqApiKey,
              baseUrl: SupabaseConfig.groqBaseUrl,
              model: fastModel
                  ? SupabaseConfig.groqModelFast
                  : SupabaseConfig.groqModelForFeature(feature),
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              temperature: temperature,
              timeout: timeout,
            );
            SupabaseConfig.updateLastAiProvider('groq');
            return reply;
          case 'gemini':
            final reply = await CloudAiClient.geminiChat(
              apiKey: SupabaseConfig.geminiApiKey,
              baseUrl: SupabaseConfig.geminiBaseUrl,
              model: fastModel
                  ? SupabaseConfig.geminiModelFast
                  : SupabaseConfig.geminiModelForFeature(feature),
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              temperature: temperature,
              timeout: timeout,
            );
            SupabaseConfig.updateLastAiProvider('gemini');
            return reply;
          case 'ollama':
            final reply = await _sendWithOllama(
              feature: feature,
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              timeout: timeout,
              fastModel: fastModel,
            );
            SupabaseConfig.updateLastAiProvider('ollama');
            return reply;
          case 'lmstudio':
            final reply = await _sendWithLmStudio(
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
              temperature: temperature,
            );
            SupabaseConfig.updateLastAiProvider('lmstudio');
            return reply;
          case 'backend':
            final reply = await _sendWithBackend(
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
            );
            SupabaseConfig.updateLastAiProvider('backend');
            return reply;
        }
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());
        continue;
      }
    }
    throw lastError ?? Exception('AI unavailable.');
  }

  Duration _timeoutForProvider({
    required String provider,
    required AiFeature feature,
    required bool fastModel,
  }) {
    final normalized = provider.toLowerCase();
    final isCloud = normalized == 'groq' ||
        normalized == 'gemini' ||
        normalized == 'openrouter' ||
        normalized == 'backend';
    if (isCloud) {
      return fastModel
          ? SupabaseConfig.cloudTimeoutFast
          : SupabaseConfig.cloudTimeoutForFeature(feature);
    }
    return fastModel
        ? SupabaseConfig.ollamaTimeoutFast
        : SupabaseConfig.ollamaTimeoutForFeature(feature);
  }

  Future<AiResponse> _sendWithBackend({
    required String systemPrompt,
    required String userPrompt,
  }) async {
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
    return AiResponse(
      content: reply,
      provider: 'backend',
      model: data['model']?.toString(),
      usage: AiUsage.fromJson(data['usage'] as Map<String, dynamic>?),
    );
  }

  Future<AiResponse> _sendWithLmStudio({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
  }) async {
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
        'temperature': temperature,
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
    return AiResponse(
      content: (message['message']?['content'] as String?)?.trim() ?? '',
      provider: 'lmstudio',
      model: data['model']?.toString() ?? SupabaseConfig.lmStudioModel,
      usage: AiUsage.fromJson(data['usage'] as Map<String, dynamic>?),
    );
  }

  Future<AiResponse> _sendWithOllama({
    required AiFeature feature,
    required String systemPrompt,
    required String userPrompt,
    required Duration timeout,
    bool fastModel = false,
  }) async {
    Exception? lastError;
    for (final baseUrl in SupabaseConfig.ollamaBaseUrls) {
      final uri = Uri.parse('$baseUrl/api/chat');
      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'model': fastModel
                    ? SupabaseConfig.ollamaModelFast
                    : SupabaseConfig.ollamaModelForFeature(feature),
                'stream': false,
                'keep_alive': SupabaseConfig.ollamaKeepAlive,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userPrompt},
                ],
              }),
            )
            .timeout(timeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = Exception('Ollama error: ${response.body}');
          continue;
        }
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AiResponse(
          content: (data['message']?['content'] as String?)?.trim() ?? '',
          provider: 'ollama',
          model: data['model']?.toString() ??
              (fastModel
                  ? SupabaseConfig.ollamaModelFast
                  : SupabaseConfig.ollamaModelForFeature(feature)),
          usage: AiUsage.fromJson(data['usage'] as Map<String, dynamic>?),
        );
      } catch (error) {
        lastError = Exception('Ollama not reachable at $baseUrl');
      }
    }
    throw lastError ?? Exception('Ollama not reachable.');
  }
}
