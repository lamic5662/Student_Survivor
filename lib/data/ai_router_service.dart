import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/ai_cache_service.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_request_helper.dart';
import 'package:student_survivor/data/cloud_ai_client.dart';
import 'package:student_survivor/data/supabase_config.dart';

class AiRouterService {
  AiRouterService(SupabaseClient client, {Connectivity? connectivity})
      : _aiHelper = AiRequestHelper(client),
        _cache = AiCacheService(),
        _connectivity = connectivity ?? Connectivity();

  final AiRequestHelper _aiHelper;
  final AiCacheService _cache;
  final Connectivity _connectivity;

  Future<String> send(AiRequest request) async {
    final cached = await _cache.read(request);
    if (cached != null && cached.content.trim().isNotEmpty) {
      SupabaseConfig.updateLastAiProvider(cached.provider);
      return cached.content.trim();
    }
    final results = await _connectivity.checkConnectivity();
    final isOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final mode =
        _normalizeProviderKey(
          (SupabaseConfig.aiProviderOverride ?? SupabaseConfig.aiMode)
              .toLowerCase(),
        );
    final providers = _buildProviderList(
      feature: request.feature,
      mode: mode,
      isOnline: isOnline,
    );
    final freeTierOnly = SupabaseConfig.aiFreeTierOnly;
    final filteredProviders = freeTierOnly && _isCloudDisabled()
        ? providers.where((p) => !_cloudProviders.contains(p)).toList()
        : providers;
    final finalProviders =
        filteredProviders.isEmpty ? _localProviders : filteredProviders;
    final errors = <String>[];

    for (final provider in finalProviders) {
      if (freeTierOnly &&
          _isCloudDisabled() &&
          _cloudProviders.contains(provider)) {
        continue;
      }
      if (!_isProviderReady(provider)) {
        continue;
      }
      if (_isBlocked(provider)) {
        continue;
      }
      try {
        final response = await _aiHelper.sendChat(
          feature: request.feature,
          systemPrompt: request.systemPrompt,
          userPrompt: request.userPrompt,
          temperature: request.temperature,
          fastModel: request.fastModel,
          timeoutOverride: request.timeout,
          providersOverride: [provider],
        );
        final normalized = _normalize(
          response.content,
          expectsJson: request.expectsJson,
        );
        if (normalized.isEmpty) {
          throw Exception('AI returned empty response.');
        }
        _recordSuccess(provider);
        await _cache.write(
          request,
          response.copyWith(content: normalized),
        );
        return normalized;
      } catch (error) {
        _recordFailure(provider, error);
        errors.add('$provider: $error');
        debugPrint('AI provider $provider failed: $error');
        continue;
      }
    }

    throw Exception(_friendlyError(mode, isOnline, errors));
  }

  List<String> _buildProviderList({
    required AiFeature feature,
    required String mode,
    required bool isOnline,
  }) {
    final override = _normalizeProviderKey(mode);
    if (_explicitProviders.contains(override)) {
      if (!isOnline && _cloudProviders.contains(override)) {
        return _localProviders;
      }
      return [override];
    }

    if (!isOnline) {
      return _localProviders;
    }

    if (override == 'local') {
      return _localProviders;
    }
    if (override == 'backend') {
      return ['backend', ..._localProviders];
    }
    if (override == 'hybrid') {
      return [..._cloudPriority(feature), ..._localProviders];
    }
    // cloud/auto/free/default
    return [..._cloudPriority(feature), ..._localProviders];
  }

  List<String> _cloudPriority(AiFeature feature) {
    switch (feature) {
      case AiFeature.exam:
      case AiFeature.weaknessAnalysis:
        return const ['gemini', 'openrouter', 'groq', 'ollama', 'lmstudio'];
      case AiFeature.notes:
      case AiFeature.topicSummary:
        return const ['gemini', 'openrouter', 'ollama', 'lmstudio', 'groq'];
      case AiFeature.studyPlan:
        return const ['gemini', 'openrouter', 'groq', 'ollama', 'lmstudio'];
      case AiFeature.game:
        return const ['groq', 'gemini', 'openrouter', 'ollama', 'lmstudio'];
      case AiFeature.tutor:
      case AiFeature.quizExplanation:
        return const ['groq', 'gemini', 'openrouter', 'ollama', 'lmstudio'];
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return const ['lmstudio', 'ollama'];
    }
  }

  String _normalizeProviderKey(String value) {
    if (value == 'lm-studio' || value == 'lm_studio') {
      return 'lmstudio';
    }
    if (value == 'auto' || value == 'free' || value == 'cloud') {
      return 'cloud';
    }
    return value;
  }

  String _normalize(String text, {required bool expectsJson}) {
    final trimmed = text.trim();
    if (!expectsJson) {
      return trimmed;
    }
    final jsonText = _extractJsonCandidate(trimmed);
    if (jsonText == null) {
      throw Exception('Invalid response format.');
    }
    return jsonText;
  }

  String? _extractJsonCandidate(String text) {
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
    return null;
  }

  bool _isProviderReady(String provider) {
    final normalized = provider.toLowerCase();
    if (normalized == 'groq') {
      return SupabaseConfig.groqApiKey.trim().isNotEmpty;
    }
    if (normalized == 'gemini') {
      return SupabaseConfig.geminiApiKey.trim().isNotEmpty;
    }
    if (normalized == 'openrouter') {
      return SupabaseConfig.openRouterApiKey.trim().isNotEmpty;
    }
    return true;
  }

  String _friendlyError(String mode, bool isOnline, List<String> errors) {
    final base = isOnline
        ? 'AI is not responding right now. Try again in a moment.'
        : 'No internet connection. Please connect or use local AI.';
    if (errors.isEmpty) {
      return base;
    }
    return '$base\n${errors.join('\n')}';
  }

  bool _isBlocked(String provider) {
    final health = _health[provider];
    if (health == null) return false;
    final now = DateTime.now();
    if (health.cooldownUntil != null && now.isBefore(health.cooldownUntil!)) {
      return true;
    }
    if (health.failures >= _maxFailures &&
        health.lastFailure != null &&
        now.difference(health.lastFailure!) < _failureWindow) {
      return true;
    }
    return false;
  }

  void _recordSuccess(String provider) {
    final health = _health.putIfAbsent(provider, () => _ProviderHealth());
    health.failures = 0;
    health.lastFailure = null;
    health.cooldownUntil = null;
  }

  void _recordFailure(String provider, Object error) {
    final health = _health.putIfAbsent(provider, () => _ProviderHealth());
    final now = DateTime.now();
    health.failures += 1;
    health.lastFailure = now;

    final normalized = provider.toLowerCase();
    final isRateLimit = _isRateLimitError(error);
    final isQuota = _isQuotaError(error);
    final isTimeout = _isTimeoutError(error);
    final isLocalDown = _isLocalDownError(error);
    final freeTierOnly = SupabaseConfig.aiFreeTierOnly;

    if (freeTierOnly && _cloudProviders.contains(normalized) && isQuota) {
      _cloudDisabledUntil = now.add(const Duration(hours: 12));
      health.cooldownUntil = _cloudDisabledUntil;
      return;
    }

    // Provider-specific circuit breakers.
    if (normalized == 'gemini' && isRateLimit) {
      health.cooldownUntil = now.add(const Duration(minutes: 15));
      return;
    }
    if (normalized == 'groq' && health.failures >= 3) {
      health.cooldownUntil = now.add(const Duration(minutes: 10));
      return;
    }
    if (normalized == 'ollama' && isLocalDown) {
      health.cooldownUntil = now.add(const Duration(minutes: 5));
      return;
    }

    // Generic cooldowns.
    if (isRateLimit) {
      health.cooldownUntil = now.add(_rateLimitCooldown);
      return;
    }
    if (isTimeout) {
      health.cooldownUntil = now.add(_timeoutCooldown);
      return;
    }
    if (health.failures >= _maxFailures) {
      health.cooldownUntil = now.add(_failureCooldown);
    }
  }

  bool _isRateLimitError(Object error) {
    if (error is CloudAiException) {
      return error.isRateLimit;
    }
    final text = error.toString().toLowerCase();
    return text.contains('rate limit') || text.contains('429');
  }

  bool _isQuotaError(Object error) {
    if (error is CloudAiException) {
      final status = error.statusCode ?? 0;
      if (status == 402 || status == 403) return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('insufficient_quota') ||
        text.contains('quota') ||
        text.contains('payment') ||
        text.contains('billing') ||
        text.contains('credits');
  }

  bool _isTimeoutError(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('timeout') || text.contains('timed out');
  }

  bool _isLocalDownError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('not reachable') ||
        text.contains('connection refused') ||
        text.contains('socket');
  }

  bool _isCloudDisabled() {
    final until = _cloudDisabledUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  static final Map<String, _ProviderHealth> _health = {};
  static const _failureWindow = Duration(minutes: 3);
  static const _failureCooldown = Duration(minutes: 2);
  static const _rateLimitCooldown = Duration(minutes: 4);
  static const _timeoutCooldown = Duration(seconds: 60);
  static const _maxFailures = 2;
  static const _localProviders = ['ollama', 'lmstudio'];
  static const _cloudProviders = ['groq', 'gemini', 'openrouter', 'backend'];
  static const _explicitProviders = [
    'groq',
    'gemini',
    'openrouter',
    'ollama',
    'lmstudio',
    'backend',
  ];
  static DateTime? _cloudDisabledUntil;
}

class _ProviderHealth {
  int failures = 0;
  DateTime? lastFailure;
  DateTime? cooldownUntil;
}
