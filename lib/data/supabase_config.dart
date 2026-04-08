import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AiFeature {
  game,
  notes,
  tutor,
  studyPlan,
  weaknessAnalysis,
  quizExplanation,
  topicSummary,
  exam,
  promptTesting,
  modelTesting,
  debugging,
}

class SupabaseConfig {
  static const String _aiProviderOverrideKey = 'ai_provider_override';
  static const String _aiFreeTierOnlyKey = 'ai_free_tier_only';
  static String? _aiProviderOverride;
  static String? _lastAiProvider;
  static bool _aiFreeTierOnly = false;
  static final ValueNotifier<String?> aiProviderNotifier =
      ValueNotifier<String?>(null);
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
        : const String.fromEnvironment('AI_MODE', defaultValue: 'cloud');
  }

  static String? get aiProviderOverride => _aiProviderOverride;
  static String? get lastAiProvider => _lastAiProvider;
  static bool get aiFreeTierOnly => _aiFreeTierOnly;

  static void updateLastAiProvider(String provider) {
    final normalized = provider.trim();
    if (normalized.isEmpty) return;
    _lastAiProvider = normalized;
    aiProviderNotifier.value = normalized;
  }

  static Future<void> setAiProviderOverride(String? value) async {
    final trimmed = value?.trim();
    _aiProviderOverride = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_aiProviderOverride == null) {
        await prefs.remove(_aiProviderOverrideKey);
      } else {
        await prefs.setString(_aiProviderOverrideKey, _aiProviderOverride!);
      }
    } catch (_) {}
  }

  static Future<void> setAiFreeTierOnly(bool value) async {
    _aiFreeTierOnly = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_aiFreeTierOnlyKey, value);
    } catch (_) {}
  }

  static String aiProviderFor(AiFeature feature,
      {String? message, String? mode}) {
    final override = (_aiProviderOverride ?? aiMode).toLowerCase();
    final isDebug = _isDebugPrompt(message, mode);
    final isLmStudioFeature = feature == AiFeature.promptTesting ||
        feature == AiFeature.modelTesting ||
        feature == AiFeature.debugging;

    if (override == 'free') {
      return 'free';
    }
    if (override == 'cloud' || override == 'auto') {
      return 'groq';
    }
    if (override == 'groq') {
      return 'groq';
    }
    if (override == 'openrouter') {
      return 'openrouter';
    }
    if (override == 'gemini') {
      return 'gemini';
    }
    if (override == 'lmstudio') {
      return 'lmstudio';
    }
    if (override == 'ollama') {
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
      case AiFeature.exam:
      case AiFeature.game:
      case AiFeature.notes:
      case AiFeature.studyPlan:
      case AiFeature.weaknessAnalysis:
      case AiFeature.quizExplanation:
      case AiFeature.topicSummary:
        return 'backend';
    }
  }

  static List<String> aiProviderOrder(
    AiFeature feature, {
    String? message,
    String? mode,
  }) {
    final override = (_aiProviderOverride ?? aiMode).toLowerCase();
    final isDebug = _isDebugPrompt(message, mode);
    final isLmStudioFeature = feature == AiFeature.promptTesting ||
        feature == AiFeature.modelTesting ||
        feature == AiFeature.debugging;

    if (override == 'ollama') {
      return ['ollama'];
    }
    if (override == 'gemini') {
      return ['gemini', 'groq', 'openrouter', 'ollama'];
    }
    if (override == 'groq') {
      return ['groq', 'openrouter', 'gemini', 'ollama'];
    }
    if (override == 'openrouter') {
      return ['openrouter', 'groq', 'gemini', 'ollama'];
    }
    if (override == 'cloud' || override == 'auto' || override == 'free') {
      return ['groq', 'openrouter', 'gemini', 'ollama'];
    }
    if (override == 'lmstudio') {
      return ['lmstudio', 'ollama'];
    }
    if (override == 'backend') {
      return ['backend', 'ollama'];
    }
    if (override == 'ollama') {
      return ['ollama'];
    }

    if (isLmStudioFeature || (feature == AiFeature.tutor && isDebug)) {
      return ['lmstudio', 'ollama'];
    }
    return ['backend', 'ollama'];
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

  static List<String> get ollamaBaseUrls {
    final raw = _safeDotenv('OLLAMA_BASE_URLS');
    final urls = <String>[];
    if (ollamaBaseUrl.trim().isNotEmpty) {
      urls.add(ollamaBaseUrl.trim());
    }
    if (raw.trim().isNotEmpty) {
      urls.addAll(
        raw.split(',').map((value) => value.trim()).where((v) => v.isNotEmpty),
      );
    }
    const fallbacks = [
      'http://127.0.0.1:11434',
      'http://localhost:11434',
      'http://10.0.2.2:11434',
      'http://10.0.3.2:11434',
    ];
    for (final fallback in fallbacks) {
      if (!urls.contains(fallback)) {
        urls.add(fallback);
      }
    }
    return urls;
  }

  static String get ollamaModel {
    final value = _safeDotenv('OLLAMA_MODEL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('OLLAMA_MODEL', defaultValue: 'llama3');
  }

  static String get ollamaModelChat =>
      _ollamaModelFromEnv('OLLAMA_MODEL_CHAT', fallback: ollamaModel);

  static String get ollamaModelQuiz =>
      _ollamaModelFromEnv('OLLAMA_MODEL_QUIZ', fallback: ollamaModel);

  static String get ollamaModelExam =>
      _ollamaModelFromEnv('OLLAMA_MODEL_EXAM', fallback: ollamaModel);

  static String get ollamaModelNotes =>
      _ollamaModelFromEnv('OLLAMA_MODEL_NOTES', fallback: ollamaModel);

  static String get ollamaModelFast =>
      _ollamaModelFromEnv('OLLAMA_MODEL_FAST', fallback: ollamaModel);

  static String get groqApiKey {
    final value = _safeDotenv('GROQ_API_KEY');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  }

  static String get groqBaseUrl {
    final value = _safeDotenv('GROQ_BASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'GROQ_BASE_URL',
            defaultValue: 'https://api.groq.com/openai/v1',
          );
  }

  static String get groqModel =>
      _ollamaModelFromEnv('GROQ_MODEL', fallback: 'llama-3.1-8b-instant');

  static String get groqModelChat =>
      _ollamaModelFromEnv('GROQ_MODEL_CHAT', fallback: groqModel);

  static String get groqModelQuiz =>
      _ollamaModelFromEnv('GROQ_MODEL_QUIZ', fallback: groqModel);

  static String get groqModelExam =>
      _ollamaModelFromEnv('GROQ_MODEL_EXAM', fallback: groqModel);

  static String get groqModelNotes =>
      _ollamaModelFromEnv('GROQ_MODEL_NOTES', fallback: groqModel);

  static String get groqModelFast =>
      _ollamaModelFromEnv('GROQ_MODEL_FAST', fallback: groqModel);

  static String get openRouterApiKey {
    final value = _safeDotenv('OPENROUTER_API_KEY');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  }

  static String get openRouterBaseUrl {
    final value = _safeDotenv('OPENROUTER_BASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'OPENROUTER_BASE_URL',
            defaultValue: 'https://openrouter.ai/api/v1',
          );
  }

  static String get openRouterAppTitle {
    final value = _safeDotenv('OPENROUTER_APP_TITLE');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'OPENROUTER_APP_TITLE',
            defaultValue: 'StudentSurge',
          );
  }

  static String get openRouterAppUrl {
    final value = _safeDotenv('OPENROUTER_APP_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('OPENROUTER_APP_URL', defaultValue: '');
  }

  static String get openRouterModel =>
      _ollamaModelFromEnv('OPENROUTER_MODEL', fallback: 'openrouter/auto');

  static String get openRouterModelChat =>
      _ollamaModelFromEnv('OPENROUTER_MODEL_CHAT', fallback: openRouterModel);

  static String get openRouterModelQuiz =>
      _ollamaModelFromEnv('OPENROUTER_MODEL_QUIZ', fallback: openRouterModel);

  static String get openRouterModelExam =>
      _ollamaModelFromEnv('OPENROUTER_MODEL_EXAM', fallback: openRouterModel);

  static String get openRouterModelNotes =>
      _ollamaModelFromEnv('OPENROUTER_MODEL_NOTES', fallback: openRouterModel);

  static String get openRouterModelFast =>
      _ollamaModelFromEnv('OPENROUTER_MODEL_FAST', fallback: openRouterModel);

  static String openRouterModelForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return openRouterModelChat;
      case AiFeature.game:
        return openRouterModelQuiz;
      case AiFeature.notes:
        return openRouterModelNotes;
      case AiFeature.studyPlan:
        return openRouterModelFast;
      case AiFeature.weaknessAnalysis:
      case AiFeature.exam:
        return openRouterModelExam;
      case AiFeature.quizExplanation:
        return openRouterModelChat;
      case AiFeature.topicSummary:
        return openRouterModelNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return openRouterModel;
    }
  }

  static String groqModelForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return groqModelChat;
      case AiFeature.game:
        return groqModelQuiz;
      case AiFeature.notes:
        return groqModelNotes;
      case AiFeature.studyPlan:
        return groqModelFast;
      case AiFeature.weaknessAnalysis:
      case AiFeature.exam:
        return groqModelExam;
      case AiFeature.quizExplanation:
        return groqModelChat;
      case AiFeature.topicSummary:
        return groqModelNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return groqModel;
    }
  }

  static String get geminiApiKey {
    final value = _safeDotenv('GEMINI_API_KEY');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  static String get geminiBaseUrl {
    final value = _safeDotenv('GEMINI_BASE_URL');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'GEMINI_BASE_URL',
            defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
          );
  }

  static String get geminiModel =>
      _ollamaModelFromEnv('GEMINI_MODEL', fallback: 'gemini-1.5-flash');

  static String get geminiModelChat =>
      _ollamaModelFromEnv('GEMINI_MODEL_CHAT', fallback: geminiModel);

  static String get geminiModelQuiz =>
      _ollamaModelFromEnv('GEMINI_MODEL_QUIZ', fallback: geminiModel);

  static String get geminiModelExam =>
      _ollamaModelFromEnv('GEMINI_MODEL_EXAM', fallback: geminiModel);

  static String get geminiModelNotes =>
      _ollamaModelFromEnv('GEMINI_MODEL_NOTES', fallback: geminiModel);

  static String get geminiModelFast =>
      _ollamaModelFromEnv('GEMINI_MODEL_FAST', fallback: geminiModel);

  static String geminiModelForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return geminiModelChat;
      case AiFeature.game:
        return geminiModelQuiz;
      case AiFeature.notes:
        return geminiModelNotes;
      case AiFeature.studyPlan:
        return geminiModelFast;
      case AiFeature.weaknessAnalysis:
      case AiFeature.exam:
        return geminiModelExam;
      case AiFeature.quizExplanation:
        return geminiModelChat;
      case AiFeature.topicSummary:
        return geminiModelNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return geminiModel;
    }
  }

  static String get ollamaKeepAlive {
    final value = _safeDotenv('OLLAMA_KEEP_ALIVE');
    return value.isNotEmpty
        ? value
        : const String.fromEnvironment(
            'OLLAMA_KEEP_ALIVE',
            defaultValue: '30m',
          );
  }

  static Duration get ollamaTimeout {
    return _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_MS', const Duration(milliseconds: 20000));
  }

  static Duration get ollamaTimeoutChat =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_CHAT_MS', ollamaTimeout);

  static Duration get ollamaTimeoutQuiz =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_QUIZ_MS', ollamaTimeout);

  static Duration get ollamaTimeoutExam =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_EXAM_MS', ollamaTimeout);

  static Duration get ollamaTimeoutNotes =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_NOTES_MS', ollamaTimeout);

  static Duration get ollamaTimeoutStudyPlan =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_PLAN_MS', ollamaTimeoutFast);

  static Duration get ollamaTimeoutFast =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_FAST_MS', ollamaTimeout);

  static Duration get ollamaTimeoutGame =>
      _ollamaTimeoutFromEnv('OLLAMA_TIMEOUT_GAME_MS', ollamaTimeout);

  static Duration get cloudTimeout {
    return _ollamaTimeoutFromEnv(
      'CLOUD_TIMEOUT_MS',
      const Duration(milliseconds: 20000),
    );
  }

  static Duration get cloudTimeoutChat =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_CHAT_MS', cloudTimeout);

  static Duration get cloudTimeoutQuiz =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_QUIZ_MS', cloudTimeout);

  static Duration get cloudTimeoutExam =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_EXAM_MS', cloudTimeout);

  static Duration get cloudTimeoutNotes =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_NOTES_MS', cloudTimeout);

  static Duration get cloudTimeoutStudyPlan =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_PLAN_MS', cloudTimeout);

  static Duration get cloudTimeoutFast =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_FAST_MS', cloudTimeout);

  static Duration get cloudTimeoutGame =>
      _ollamaTimeoutFromEnv('CLOUD_TIMEOUT_GAME_MS', cloudTimeout);

  static Duration ollamaTimeoutForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return ollamaTimeoutChat;
      case AiFeature.game:
        return ollamaTimeoutGame;
      case AiFeature.notes:
        return ollamaTimeoutNotes;
      case AiFeature.studyPlan:
        return ollamaTimeoutStudyPlan;
      case AiFeature.weaknessAnalysis:
        return ollamaTimeoutExam;
      case AiFeature.exam:
        return ollamaTimeoutExam;
      case AiFeature.quizExplanation:
        return ollamaTimeoutChat;
      case AiFeature.topicSummary:
        return ollamaTimeoutNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return ollamaTimeout;
    }
  }

  static Duration cloudTimeoutForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return cloudTimeoutChat;
      case AiFeature.game:
        return cloudTimeoutGame;
      case AiFeature.notes:
        return cloudTimeoutNotes;
      case AiFeature.studyPlan:
        return cloudTimeoutStudyPlan;
      case AiFeature.weaknessAnalysis:
        return cloudTimeoutExam;
      case AiFeature.exam:
        return cloudTimeoutExam;
      case AiFeature.quizExplanation:
        return cloudTimeoutChat;
      case AiFeature.topicSummary:
        return cloudTimeoutNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return cloudTimeout;
    }
  }

  static Duration _ollamaTimeoutFromEnv(String key, Duration fallback) {
    final raw = _safeDotenv(key);
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      return fallback;
    }
    return Duration(milliseconds: parsed);
  }

  static String ollamaModelForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.tutor:
        return ollamaModelChat;
      case AiFeature.game:
        return ollamaModelQuiz;
      case AiFeature.notes:
        return ollamaModelNotes;
      case AiFeature.studyPlan:
        return ollamaModelFast;
      case AiFeature.weaknessAnalysis:
        return ollamaModelExam;
      case AiFeature.exam:
        return ollamaModelExam;
      case AiFeature.quizExplanation:
        return ollamaModelChat;
      case AiFeature.topicSummary:
        return ollamaModelNotes;
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return ollamaModel;
    }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      _aiProviderOverride = prefs.getString(_aiProviderOverrideKey);
      _aiFreeTierOnly = prefs.getBool(_aiFreeTierOnlyKey) ?? false;
    } catch (_) {}
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

  static String _ollamaModelFromEnv(
    String key, {
    required String fallback,
  }) {
    final value = _safeDotenv(key);
    return value.isNotEmpty ? value : fallback;
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
