import 'package:flutter/material.dart';
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
}
