import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class SearchService {
  final SupabaseClient _client;

  SearchService(this._client);

  static const String _cachePrefix = 'search_cache_v1_';

  Future<List<SearchHit>> searchHits(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 3) {
      return [];
    }
    try {
      final data = await _client.rpc(
        'search_content',
        params: {
          'p_query': trimmed,
          'p_limit': 20,
        },
      );

      final hits = (data as List<dynamic>)
          .map(
            (row) => SearchHit(
              type: row['item_type']?.toString() ?? '',
              id: row['item_id']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              snippet: row['snippet']?.toString() ?? '',
              score: (row['score'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList();
      await _cacheSearch(trimmed, hits);
      return hits;
    } catch (_) {
      final cached = await _loadCachedSearch(trimmed);
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<SearchResult>> search(String query) async {
    final hits = await searchHits(query);
    return hits
        .map(
          (hit) => SearchResult(
            title: hit.title,
            type: _labelForType(hit.type),
            snippet: hit.snippet,
          ),
        )
        .toList();
  }

  String _labelForType(String type) {
    switch (type) {
      case 'note':
        return 'Note';
      case 'question':
        return 'Question';
      case 'chapter':
        return 'Chapter';
      case 'subject':
        return 'Subject';
      default:
        return type;
    }
  }

  Future<void> _cacheSearch(String query, List<SearchHit> hits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = hits
          .map(
            (hit) => {
              'type': hit.type,
              'id': hit.id,
              'title': hit.title,
              'snippet': hit.snippet,
              'score': hit.score,
            },
          )
          .toList();
      await prefs.setString(_cacheKey(query), jsonEncode(payload));
    } catch (_) {}
  }

  Future<List<SearchHit>> _loadCachedSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(query));
      if (raw == null || raw.isEmpty) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map>()
          .map((entry) {
            final map = Map<String, dynamic>.from(entry);
            return SearchHit(
              type: map['type']?.toString() ?? '',
              id: map['id']?.toString() ?? '',
              title: map['title']?.toString() ?? '',
              snippet: map['snippet']?.toString() ?? '',
              score: (map['score'] as num?)?.toDouble() ?? 0,
            );
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _cacheKey(String query) {
    final safe = query
        .toLowerCase()
        .replaceAll(RegExp(r'\\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
        .trim();
    final key = safe.isEmpty ? 'query' : safe;
    final capped = key.length > 40 ? key.substring(0, 40) : key;
    return '$_cachePrefix$capped';
  }
}

class SearchHit {
  final String type;
  final String id;
  final String title;
  final String snippet;
  final double score;

  const SearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.snippet,
    required this.score,
  });
}
