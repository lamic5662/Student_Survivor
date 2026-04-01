import 'package:supabase_flutter/supabase_flutter.dart';

class NoteGeneratedQuestionService {
  final SupabaseClient _client;

  NoteGeneratedQuestionService(this._client);

  Future<String?> create({
    required String noteId,
    required String chapterId,
    required String question,
    String? answer,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || noteId.isEmpty || chapterId.isEmpty) {
      return null;
    }
    final inserted = await _client
        .from('note_generated_questions')
        .insert({
          'user_id': user.id,
          'note_id': noteId,
          'chapter_id': chapterId,
          'question': question,
          'answer': answer,
        })
        .select('id')
        .single();
    return inserted['id']?.toString();
  }

  Future<void> updateAnswer({
    required String id,
    required String answer,
  }) async {
    if (id.isEmpty) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('note_generated_questions')
        .update({
          'answer': answer,
        })
        .eq('id', id)
        .eq('user_id', user.id);
  }
}
