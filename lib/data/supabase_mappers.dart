import 'package:flutter/material.dart';
import 'package:student_survivor/models/app_models.dart';

Color parseAccentColor(String? value) {
  if (value == null || value.isEmpty) {
    return const Color(0xFF6366F1);
  }
  final hex = value.replaceAll('#', '').padLeft(6, '0');
  final colorValue = int.tryParse('FF$hex', radix: 16) ?? 0xFF6366F1;
  return Color(colorValue);
}

QuizType parseQuizType(String? value) {
  switch (value) {
    case 'time':
      return QuizType.time;
    case 'level':
      return QuizType.level;
    case 'mcq':
    default:
      return QuizType.mcq;
  }
}

QuizDifficulty parseQuizDifficulty(String? value) {
  switch (value) {
    case 'medium':
      return QuizDifficulty.medium;
    case 'hard':
      return QuizDifficulty.hard;
    case 'easy':
    default:
      return QuizDifficulty.easy;
  }
}
