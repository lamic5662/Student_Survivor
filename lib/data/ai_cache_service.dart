import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_response.dart';
import 'package:student_survivor/data/supabase_config.dart';

class AiCacheEntry {
  final String content;
  final String provider;
  final String? model;
  final AiUsage? usage;
  final DateTime createdAt;

  const AiCacheEntry({
    required this.content,
    required this.provider,
    required this.createdAt,
    this.model,
    this.usage,
  });

  Map<String, dynamic> toJson() => {
        'content': content,
        'provider': provider,
        'model': model,
        'usage': usage?.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  static AiCacheEntry? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final createdRaw = json['created_at']?.toString();
    final createdAt = createdRaw == null
        ? null
        : DateTime.tryParse(createdRaw);
    if (createdAt == null) return null;
    return AiCacheEntry(
      content: json['content']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      model: json['model']?.toString(),
      usage: AiUsage.fromJson(json['usage'] as Map<String, dynamic>?),
      createdAt: createdAt,
    );
  }
}

class AiCacheService {
  static const _prefix = 'ai_cache_v1_';

  Future<AiCacheEntry?> read(AiRequest request) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(request);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entry = AiCacheEntry.fromJson(decoded);
      if (entry == null) return null;
      final ttl = _ttlForFeature(request.feature);
      if (DateTime.now().difference(entry.createdAt) > ttl) {
        await prefs.remove(key);
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AiRequest request, AiResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(request);
    final entry = AiCacheEntry(
      content: response.content,
      provider: response.provider,
      model: response.model,
      usage: response.usage,
      createdAt: DateTime.now(),
    );
    await prefs.setString(key, jsonEncode(entry.toJson()));
  }

  String _keyFor(AiRequest request) {
    final payload = jsonEncode({
      'feature': request.feature.name,
      'system': request.systemPrompt.trim(),
      'user': request.userPrompt.trim(),
      'temperature': request.temperature,
      'fast': request.fastModel,
      'expects_json': request.expectsJson,
      'mode': SupabaseConfig.aiProviderOverride ?? SupabaseConfig.aiMode,
    });
    final digest = sha1.convert(utf8.encode(payload)).toString();
    return '$_prefix${request.feature.name}_$digest';
  }

  Duration _ttlForFeature(AiFeature feature) {
    switch (feature) {
      case AiFeature.game:
        return const Duration(minutes: 15);
      case AiFeature.tutor:
      case AiFeature.quizExplanation:
        return const Duration(minutes: 10);
      case AiFeature.exam:
      case AiFeature.weaknessAnalysis:
        return const Duration(hours: 1);
      case AiFeature.notes:
      case AiFeature.topicSummary:
        return const Duration(hours: 6);
      case AiFeature.studyPlan:
        return const Duration(hours: 4);
      case AiFeature.promptTesting:
      case AiFeature.modelTesting:
      case AiFeature.debugging:
        return const Duration(minutes: 10);
    }
  }
}
