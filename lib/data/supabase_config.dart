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
