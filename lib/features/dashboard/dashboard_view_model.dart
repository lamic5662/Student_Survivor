import 'package:student_survivor/models/app_models.dart';

class DashboardViewModel {
  final bool isLoading;
  final String? errorMessage;
  final UserProfile profile;
  final double progress;
  final int xp;
  final int gamesPlayed;
  final List<WeakTopic> weakTopics;
  final List<Note> recommendedNotes;
  final QuizAttempt? latestAttempt;

  const DashboardViewModel({
    required this.isLoading,
    required this.errorMessage,
    required this.profile,
    required this.progress,
    required this.xp,
    required this.gamesPlayed,
    required this.weakTopics,
    required this.recommendedNotes,
    required this.latestAttempt,
  });

  DashboardViewModel copyWith({
    bool? isLoading,
    String? errorMessage,
    UserProfile? profile,
    double? progress,
    int? xp,
    int? gamesPlayed,
    List<WeakTopic>? weakTopics,
    List<Note>? recommendedNotes,
    QuizAttempt? latestAttempt,
  }) {
    return DashboardViewModel(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      profile: profile ?? this.profile,
      progress: progress ?? this.progress,
      xp: xp ?? this.xp,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      weakTopics: weakTopics ?? this.weakTopics,
      recommendedNotes: recommendedNotes ?? this.recommendedNotes,
      latestAttempt: latestAttempt ?? this.latestAttempt,
    );
  }

  factory DashboardViewModel.initial(UserProfile profile) {
    return DashboardViewModel(
      isLoading: true,
      errorMessage: null,
      profile: profile,
      progress: 0,
      xp: 0,
      gamesPlayed: 0,
      weakTopics: const [],
      recommendedNotes: const [],
      latestAttempt: null,
    );
  }
}
