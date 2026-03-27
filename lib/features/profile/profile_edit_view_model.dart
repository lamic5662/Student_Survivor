import 'package:student_survivor/models/app_models.dart';

class ProfileEditViewModel {
  final String fullName;
  final String email;
  final List<Semester> semesters;
  final Semester selectedSemester;
  final Set<String> selectedSubjectIds;

  const ProfileEditViewModel({
    required this.fullName,
    required this.email,
    required this.semesters,
    required this.selectedSemester,
    required this.selectedSubjectIds,
  });

  List<Subject> get availableSubjects => selectedSemester.subjects;

  bool get canSave => fullName.trim().isNotEmpty && selectedSubjectIds.isNotEmpty;

  ProfileEditViewModel copyWith({
    String? fullName,
    String? email,
    List<Semester>? semesters,
    Semester? selectedSemester,
    Set<String>? selectedSubjectIds,
  }) {
    return ProfileEditViewModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedSubjectIds: selectedSubjectIds ?? this.selectedSubjectIds,
    );
  }

  factory ProfileEditViewModel.fromProfile({
    required UserProfile profile,
    required List<Semester> semesters,
  }) {
    return ProfileEditViewModel(
      fullName: profile.name,
      email: profile.email,
      semesters: semesters,
      selectedSemester: profile.semester,
      selectedSubjectIds: profile.subjects.map((subject) => subject.id).toSet(),
    );
  }
}
