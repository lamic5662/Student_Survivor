import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class NoteSubmissionService {
  final SupabaseClient _client;

  NoteSubmissionService(this._client);

  Future<void> submitNote({
    required String chapterId,
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
    List<String> tags = const [],
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    await _client.from('note_submissions').insert({
      'user_id': user.id,
      'chapter_id': chapterId,
      'title': title,
      'short_answer': shortAnswer,
      'detailed_answer': detailedAnswer,
      'tags': tags,
      'status': 'pending',
    });
  }

  Future<List<NoteSubmission>> fetchMySubmissions(String chapterId) async {
    final user = _client.auth.currentUser;
    if (user == null || chapterId.isEmpty) {
      return [];
    }
    final data = await _client
        .from('note_submissions')
        .select(
          'id,chapter_id,title,short_answer,detailed_answer,tags,status,created_at',
        )
        .eq('user_id', user.id)
        .eq('chapter_id', chapterId)
        .order('created_at', ascending: false);

    return (data as List<dynamic>)
        .map((row) => _submissionFromMap(row as Map<String, dynamic>))
        .toList();
  }

  NoteSubmission _submissionFromMap(Map<String, dynamic> map) {
    final tags = (map['tags'] as List<dynamic>? ?? [])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final createdAt = map['created_at']?.toString();
    return NoteSubmission(
      id: map['id']?.toString() ?? '',
      chapterId: map['chapter_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Note',
      shortAnswer: map['short_answer']?.toString() ?? '',
      detailedAnswer: map['detailed_answer']?.toString() ?? '',
      tags: tags,
      status: map['status']?.toString() ?? 'pending',
      createdAt: createdAt == null ? null : DateTime.tryParse(createdAt),
    );
  }
}
