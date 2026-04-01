import 'package:student_survivor/models/app_models.dart';

class CoachPlanItem {
  final String title;
  final String detail;
  final String duration;

  const CoachPlanItem({
    required this.title,
    required this.detail,
    required this.duration,
  });
}

class CoachQuestion {
  final String prompt;
  final String answer;
  final String source;

  const CoachQuestion({
    required this.prompt,
    required this.answer,
    required this.source,
  });

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'answer': answer,
      'source': source,
    };
  }

  factory CoachQuestion.fromJson(Map<String, dynamic> json) {
    return CoachQuestion(
      prompt: json['prompt']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }
}

class CoachSnapshot {
  final DateTime date;
  final List<WeakTopic> weakTopics;
  final String nextSuggestion;
  final List<String> smartSuggestions;
  final String recommendedDifficulty;
  final List<CoachPlanItem> dailyPlan;
  final List<CoachQuestion> dailyQuestions;

  const CoachSnapshot({
    required this.date,
    required this.weakTopics,
    required this.nextSuggestion,
    required this.smartSuggestions,
    required this.recommendedDifficulty,
    required this.dailyPlan,
    required this.dailyQuestions,
  });
}
