import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/models/app_models.dart';

class AppState {
  static final ValueNotifier<UserProfile> profile =
      ValueNotifier<UserProfile>(
    UserProfile(
      name: MockData.profile.name,
      email: MockData.profile.email,
      semester: MockData.semesters.first,
      subjects: const [],
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
      semester: MockData.semesters.first,
      subjects: const [],
    );
  }
}
