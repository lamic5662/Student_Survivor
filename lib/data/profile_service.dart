import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  Future<void> updateName(String fullName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', user.id);
  }

  Future<void> updateSemester(String semesterId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({'semester_id': semesterId})
        .eq('id', user.id);
  }

  Future<void> updateCollege(String collegeName) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({'college_name': collegeName})
        .eq('id', user.id);
  }

  Future<UserProfile?> fetchProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select(
          'id, full_name, email, college_name, is_admin, semester:semesters(id,name,code)',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    final semester = data['semester'];
    final semesterModel = Semester(
      id: semester?['id']?.toString() ?? '',
      name: semester?['name']?.toString() ?? 'Semester',
      subjects: const [],
    );

    return UserProfile(
      name: data['full_name']?.toString() ?? (user.email ?? 'Student'),
      email: data['email']?.toString() ?? (user.email ?? ''),
      collegeName: data['college_name']?.toString() ?? '',
      semester: semesterModel,
      subjects: const [],
      isAdmin: data['is_admin'] as bool? ?? false,
    );
  }
}
