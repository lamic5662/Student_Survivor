import 'package:student_survivor/models/app_models.dart';

class ProfileEditViewModel {
  final String fullName;
  final String email;
  final List<Semester> semesters;
  final Semester? selectedSemester;
  final bool isLoading;
  final String? errorMessage;

  const ProfileEditViewModel({
    required this.fullName,
    required this.email,
    required this.semesters,
    required this.selectedSemester,
    required this.isLoading,
    required this.errorMessage,
  });

  bool get canSave => !isLoading && selectedSemester != null;

  ProfileEditViewModel copyWith({
    String? fullName,
    String? email,
    List<Semester>? semesters,
    Semester? selectedSemester,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileEditViewModel(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
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
      isLoading: true,
      errorMessage: null,
    );
  }
}
