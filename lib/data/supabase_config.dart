import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AiFeature {
  game,
  notes,
  tutor,
  studyPlan,
  weaknessAnalysis,
  quizExplanation,
  topicSummary,
  promptTesting,
  modelTesting,
  debugging,
}

class SupabaseConfig {
  static String get url {
    final value = _safeDotenv('SUPABASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('SUPABASE_URL');
  }

  static String get anonKey {
    final value = _safeDotenv('SUPABASE_ANON_KEY');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('SUPABASE_ANON_KEY');
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static String get aiMode {
    final value = _safeDotenv('AI_MODE');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('AI_MODE', defaultValue: 'free');
  }

  static String aiProviderFor(AiFeature feature,
      {String? message, String? mode}) {
    final override = aiMode.toLowerCase();
    final isDebug = _isDebugPrompt(message, mode);
    final isLmStudioFeature = feature == AiFeature.promptTesting ||
        feature == AiFeature.modelTesting ||
        feature == AiFeature.debugging;

    if (override == 'free') {
      return 'free';
    }
    if (override == 'lmstudio') {
      return 'lmstudio';
    }
    if (override == 'ollama') {
      if (isLmStudioFeature || (feature == AiFeature.tutor && isDebug)) {
        return 'lmstudio';
      }
      return 'ollama';
    }
    if (override == 'backend') {
      if (isLmStudioFeature || (feature == AiFeature.tutor && isDebug)) {
        return 'lmstudio';
      }
      return 'backend';
    }

    switch (feature) {
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return 'lmstudio';
      case AiFeature.tutor:
        if (_isDebugPrompt(message, mode)) {
          return 'lmstudio';
        }
        return 'backend';
      case AiFeature.game:
      case AiFeature.notes:
      case AiFeature.studyPlan:
      case AiFeature.weaknessAnalysis:
      case AiFeature.quizExplanation:
      case AiFeature.topicSummary:
        return 'backend';
    }
  }

  static String get ollamaBaseUrl {
    final value = _safeDotenv('OLLAMA_BASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'OLLAMA_BASE_URL',
            defaultValue: 'http://192.168.1.81:11434',
          );
  }

  static String get ollamaModel {
    final value = _safeDotenv('OLLAMA_MODEL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('OLLAMA_MODEL', defaultValue: 'llama3');
  }

  static String get lmStudioBaseUrl {
    final value = _safeDotenv('LMSTUDIO_BASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'LMSTUDIO_BASE_URL',
            defaultValue: 'http://127.0.0.1:1234/v1',
          );
  }

  static String get lmStudioModel {
    final value = _safeDotenv('LMSTUDIO_MODEL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'LMSTUDIO_MODEL',
            defaultValue: 'local-model',
          );
  }

  static String get lmStudioApiKey {
    final value = _safeDotenv('LMSTUDIO_API_KEY');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('LMSTUDIO_API_KEY', defaultValue: '');
  }

  static Future<void> initialize() async {
    if (!isConfigured) {
      return;
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static String _safeDotenv(String key) {
    try {
      if (!dotenv.isInitialized) {
        return '';
      }
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool _isDebugPrompt(String? message, String? mode) {
    final normalizedMode = mode?.toLowerCase() ?? '';
    if (_debugTokens.any(normalizedMode.contains)) {
      return true;
    }
    final normalized = message?.toLowerCase() ?? '';
    return _debugTokens.any(normalized.contains);
  }

  static const List<String> _debugTokens = [
    'debug',
    'prompt test',
    'prompt testing',
    'model test',
    'model testing',
    'diagnose',
    'trace',
  ];
}
