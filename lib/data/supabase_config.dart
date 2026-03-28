import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
}
