import 'package:supabase_flutter/supabase_flutter.dart';

class UserSubjectService {
  final SupabaseClient _client;

  UserSubjectService(this._client);

  Future<void> setUserSubjects({
    required String semesterId,
    required List<String> subjectIds,
  }) async {
    await _client.rpc(
      'set_user_subjects',
      params: {
        'p_semester_id': semesterId,
        'p_subject_ids': subjectIds,
      },
    );
  }
}
