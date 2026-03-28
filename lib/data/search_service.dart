import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class SearchService {
  final SupabaseClient _client;

  SearchService(this._client);

  Future<List<SearchHit>> searchHits(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < 3) {
      return [];
    }

    final data = await _client.rpc(
      'search_content',
      params: {
        'p_query': trimmed,
        'p_limit': 20,
      },
    );

    return (data as List<dynamic>)
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
