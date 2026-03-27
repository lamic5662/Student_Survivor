import 'package:student_survivor/models/app_models.dart';

class AuthViewModel {
  final bool isLogin;
  final AuthMethod method;
  final List<Semester> semesters;
  final Semester? selectedSemester;
  final Set<String> selectedSubjectIds;

  const AuthViewModel({
    required this.isLogin,
    required this.method,
    required this.semesters,
    required this.selectedSemester,
    required this.selectedSubjectIds,
  });

  List<Subject> get availableSubjects => selectedSemester?.subjects ?? [];

  bool get canContinue =>
      selectedSemester != null && selectedSubjectIds.isNotEmpty;

  AuthViewModel copyWith({
    bool? isLogin,
    AuthMethod? method,
    List<Semester>? semesters,
    Semester? selectedSemester,
    Set<String>? selectedSubjectIds,
  }) {
    return AuthViewModel(
      isLogin: isLogin ?? this.isLogin,
      method: method ?? this.method,
      semesters: semesters ?? this.semesters,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedSubjectIds: selectedSubjectIds ?? this.selectedSubjectIds,
    );
  }

  factory AuthViewModel.initial(List<Semester> semesters) {
    return AuthViewModel(
      isLogin: true,
      method: AuthMethod.email,
      semesters: semesters,
      selectedSemester: semesters.isNotEmpty ? semesters[0] : null,
      selectedSubjectIds: <String>{},
    );
  }
}
