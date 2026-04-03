import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogService {
  final SupabaseClient _client;

  ActivityLogService(this._client);

  Future<void> logActivity({
    required String type,
    String? source,
    int points = 0,
    String? subjectId,
    String? chapterId,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('user_activity_log').insert({
      'user_id': user.id,
      'activity_type': type,
      'source': source,
      'points': points,
      'subject_id': subjectId,
      'chapter_id': chapterId,
      'metadata': metadata ?? <String, dynamic>{},
    });
  }

  void logActivityUnawaited({
    required String type,
    String? source,
    int points = 0,
    String? subjectId,
    String? chapterId,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(
      logActivity(
        type: type,
        source: source,
        points: points,
        subjectId: subjectId,
        chapterId: chapterId,
        metadata: metadata,
      ),
    );
  }
}
