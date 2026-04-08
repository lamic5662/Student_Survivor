import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:student_survivor/data/supabase_config.dart';

class LocalAiStatus {
  final bool ollamaOnline;
  final bool lmStudioOnline;
  final Duration? ollamaLatency;
  final Duration? lmStudioLatency;

  const LocalAiStatus({
    required this.ollamaOnline,
    required this.lmStudioOnline,
    this.ollamaLatency,
    this.lmStudioLatency,
  });
}

class LocalAiStatusService {
  LocalAiStatusService({Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 2);

  final Duration _timeout;

  Future<LocalAiStatus> fetch() async {
    final ollama = await _pingOllama();
    final lmStudio = await _pingLmStudio();
    return LocalAiStatus(
      ollamaOnline: ollama.online,
      lmStudioOnline: lmStudio.online,
      ollamaLatency: ollama.latency,
      lmStudioLatency: lmStudio.latency,
    );
  }

  Future<_PingResult> _pingOllama() async {
    for (final base in SupabaseConfig.ollamaBaseUrls) {
      final uri = _appendPath(Uri.parse(base), 'api/tags');
      final result = await _ping(uri);
      if (result.online) {
        return result;
      }
    }
    return const _PingResult(online: false);
  }

  Future<_PingResult> _pingLmStudio() async {
    final base = SupabaseConfig.lmStudioBaseUrl;
    final uri = _appendPath(Uri.parse(base), 'models');
    return _ping(uri);
  }

  Future<_PingResult> _ping(Uri uri) async {
    final start = DateTime.now();
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _PingResult(
          online: true,
          latency: DateTime.now().difference(start),
        );
      }
    } catch (_) {}
    return const _PingResult(online: false);
  }

  Uri _appendPath(Uri base, String path) {
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final nextPath = basePath.isEmpty ? path : '$basePath/$path';
    return base.replace(path: nextPath);
  }
}

class _PingResult {
  final bool online;
  final Duration? latency;

  const _PingResult({required this.online, this.latency});
}
