import 'package:student_survivor/models/app_models.dart';

class ProfileEditViewModel {
  final String fullName;
  final String email;
  final List<Semester> semesters;
  final Semester? selectedSemester;
  final Set<String> selectedSubjectIds;
  final bool isLoading;
  final String? errorMessage;

  const ProfileEditViewModel({
    required this.fullName,
    required this.email,
    required this.semesters,
    required this.selectedSemester,
    required this.selectedSubjectIds,
    required this.isLoading,
    required this.errorMessage,
  });

  List<Subject> get availableSubjects => selectedSemester?.subjects ?? [];

  bool get canSave =>
      !isLoading && selectedSemester != null && selectedSubjectIds.isNotEmpty;

  ProfileEditViewModel copyWith({
    String? fullName,
    String? email,
    List<Semester>? semesters,
    Semester? selectedSemester,
    Set<String>? selectedSubjectIds,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileEditViewModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedSubjectIds: selectedSubjectIds ?? this.selectedSubjectIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory ProfileEditViewModel.initial({
    required String fullName,
    required String email,
  }) {
    return ProfileEditViewModel(
      fullName: fullName,
      email: email,
      semesters: const [],
      selectedSemester: null,
      selectedSubjectIds: <String>{},
      isLoading: true,
      errorMessage: null,
    );
  }
}
