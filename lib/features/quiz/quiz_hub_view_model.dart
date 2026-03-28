import 'package:student_survivor/models/app_models.dart';

class QuizHubViewModel {
  final String semesterName;
  final List<Subject> subjects;
  final bool isLoading;
  final String? errorMessage;

  const QuizHubViewModel({
    required this.semesterName,
    required this.subjects,
    required this.isLoading,
    required this.errorMessage,
  });

  QuizHubViewModel copyWith({
    String? semesterName,
    List<Subject>? subjects,
    bool? isLoading,
    String? errorMessage,
  }) {
    return QuizHubViewModel(
      semesterName: semesterName ?? this.semesterName,
      subjects: subjects ?? this.subjects,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory QuizHubViewModel.initial() {
    return const QuizHubViewModel(
      semesterName: '',
      subjects: [],
      isLoading: true,
      errorMessage: null,
    );
  }
}
