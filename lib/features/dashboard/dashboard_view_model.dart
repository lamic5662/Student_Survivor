import 'package:student_survivor/models/app_models.dart';

class DashboardViewModel {
  final UserProfile profile;
  final double progress;
  final int xp;
  final int gamesPlayed;
  final List<WeakTopic> weakTopics;
  final List<Note> recommendedNotes;
  final List<StudyPlanDay> planner;
  final QuizAttempt latestAttempt;

  const DashboardViewModel({
    required this.profile,
    required this.progress,
    required this.xp,
    required this.gamesPlayed,
    required this.weakTopics,
    required this.recommendedNotes,
    required this.planner,
    required this.latestAttempt,
  });
}
