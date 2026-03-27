import 'package:flutter/material.dart';

enum AuthMethod { email, phone }

enum QuizType { mcq, time, level }

enum QuizDifficulty { easy, medium, hard }

class UserProfile {
  final String name;
  final String email;
  final Semester semester;
  final List<Subject> subjects;

  const UserProfile({
    required this.name,
    required this.email,
    required this.semester,
    required this.subjects,
  });
}

class Semester {
  final String id;
  final String name;
  final List<Subject> subjects;

  const Semester({
    required this.id,
    required this.name,
    required this.subjects,
  });
}

class Subject {
  final String id;
  final String name;
  final String code;
  final Color accentColor;
  final List<Chapter> chapters;

  const Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.accentColor,
    required this.chapters,
  });
}

class Chapter {
  final String id;
  final String title;
  final List<Note> notes;
  final List<Question> importantQuestions;
  final List<Question> pastQuestions;
  final List<Quiz> quizzes;

  const Chapter({
    required this.id,
    required this.title,
    required this.notes,
    required this.importantQuestions,
    required this.pastQuestions,
    required this.quizzes,
  });
}

class Note {
  final String id;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;

  const Note({
    required this.id,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
  });
}

class Question {
  final String id;
  final String prompt;
  final int marks;

  const Question({
    required this.id,
    required this.prompt,
    required this.marks,
  });
}

class Quiz {
  final String id;
  final String title;
  final QuizType type;
  final QuizDifficulty difficulty;
  final int questionCount;
  final Duration duration;

  const Quiz({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.questionCount,
    required this.duration,
  });
}

class QuizAttempt {
  final Quiz quiz;
  final int score;
  final int total;
  final int xpEarned;
  final List<WeakTopic> weakTopics;

  const QuizAttempt({
    required this.quiz,
    required this.score,
    required this.total,
    required this.xpEarned,
    required this.weakTopics,
  });

  bool get isPass => score >= (total * 0.6);
}

class WeakTopic {
  final String name;
  final String reason;

  const WeakTopic({
    required this.name,
    required this.reason,
  });
}

class StudyTask {
  final String title;
  final String subject;
  final bool isDone;

  const StudyTask({
    required this.title,
    required this.subject,
    required this.isDone,
  });
}

class StudyPlanDay {
  final String label;
  final List<StudyTask> tasks;

  const StudyPlanDay({
    required this.label,
    required this.tasks,
  });
}

class SyllabusItem {
  final String subject;
  final String detail;

  const SyllabusItem({
    required this.subject,
    required this.detail,
  });
}

class SearchResult {
  final String title;
  final String type;
  final String snippet;

  const SearchResult({
    required this.title,
    required this.type,
    required this.snippet,
  });
}
