import 'package:student_survivor/models/app_models.dart';

class QuizCardItem {
  final Quiz quiz;
  final Subject subject;

  const QuizCardItem({
    required this.quiz,
    required this.subject,
  });
}

class QuizHubViewModel {
  final List<QuizCardItem> quizzes;

  const QuizHubViewModel({required this.quizzes});
}
