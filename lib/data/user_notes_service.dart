import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/notes_cache_service.dart';
import 'package:student_survivor/models/app_models.dart';

class UserNotesService {
  final SupabaseClient _client;
  final NotesCacheService _cache;

  UserNotesService(this._client) : _cache = NotesCacheService();

  Future<List<UserNote>> fetchForChapter(String chapterId) async {
    final user = _client.auth.currentUser;
    if (user == null || chapterId.isEmpty) {
      return [];
    }

    try {
      final data = await _client
          .from('user_notes')
          .select('id,title,short_answer,detailed_answer')
          .eq('user_id', user.id)
          .eq('chapter_id', chapterId)
          .order('created_at', ascending: false);

      final notes = (data as List<dynamic>).map((row) {
        return UserNote(
          id: row['id']?.toString() ?? '',
          title: row['title']?.toString() ?? 'Note',
          shortAnswer: row['short_answer']?.toString() ?? '',
          detailedAnswer: row['detailed_answer']?.toString() ?? '',
          chapterId: chapterId,
        );
      }).toList();
      await _cache.cacheUserNotes(chapterId, notes);
      return notes;
    } catch (_) {
      return _cache.loadUserNotes(chapterId);
    }
  }

  Future<List<UserNote>> fetchForSubject(List<String> chapterIds) async {
    final user = _client.auth.currentUser;
    if (user == null || chapterIds.isEmpty) {
      return [];
    }

    try {
      final data = await _client
          .from('user_notes')
          .select('id,title,short_answer,detailed_answer,chapter_id')
          .eq('user_id', user.id)
          .inFilter('chapter_id', chapterIds)
          .order('created_at', ascending: false);

      final notes = (data as List<dynamic>).map((row) {
        return UserNote(
          id: row['id']?.toString() ?? '',
          title: row['title']?.toString() ?? 'Note',
          shortAnswer: row['short_answer']?.toString() ?? '',
          detailedAnswer: row['detailed_answer']?.toString() ?? '',
          chapterId: row['chapter_id']?.toString(),
        );
      }).toList();
      await _cache.cacheUserNotesForSubject(notes);
      return notes;
    } catch (_) {
      final merged = <UserNote>[];
      for (final chapterId in chapterIds) {
        merged.addAll(await _cache.loadUserNotes(chapterId));
      }
      return merged;
    }
  }

  Future<void> saveNote({
    required String chapterId,
    required String title,
    required String shortAnswer,
    required String detailedAnswer,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to save notes.');
    }
    if (chapterId.isEmpty) {
      throw Exception('Chapter is required.');
    }

    await _client.from('user_notes').insert({
      'user_id': user.id,
      'chapter_id': chapterId,
      'title': title,
      'short_answer': shortAnswer,
      'detailed_answer': detailedAnswer,
    });
  }

  Future<void> deleteNote(String noteId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to delete notes.');
    }
    if (noteId.isEmpty) {
      throw Exception('Note is required.');
    }

    await _client
        .from('user_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', user.id);
  }
}
