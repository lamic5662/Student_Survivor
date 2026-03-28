import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class AppState {
  static final Semester _emptySemester = Semester(
    id: '',
    name: 'Select semester',
    subjects: const [],
  );

  static final ValueNotifier<UserProfile> profile =
      ValueNotifier<UserProfile>(
    UserProfile(
      name: 'Student',
      email: '',
      semester: _emptySemester,
      subjects: [],
      isAdmin: false,
    ),
  );

  static void updateProfile(UserProfile updated) {
    profile.value = updated;
  }

  static void updateFromAuth(User? user) {
    if (user == null) {
      return;
    }
    final displayName = user.userMetadata?['full_name']?.toString();
    profile.value = UserProfile(
      name: displayName ?? (user.email ?? 'Student'),
      email: user.email ?? '',
      semester: _emptySemester,
      subjects: const [],
      isAdmin: false,
    );
  }
}
