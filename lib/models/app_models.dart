import 'package:flutter/material.dart';

enum AuthMethod { email, phone }

enum QuizType { mcq, time, level }

enum QuizDifficulty { easy, medium, hard }

class UserProfile {
  final String name;
  final String email;
  final Semester semester;
  final List<Subject> subjects;
  final bool? _isAdmin;

  const UserProfile({
    required this.name,
    required this.email,
    required this.semester,
    required this.subjects,
    bool? isAdmin,
  }) : _isAdmin = isAdmin;

  bool get isAdmin => _isAdmin ?? false;
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
  final String? syllabusUrl;
  final List<PastPaper> pastPapers;
  final List<Chapter> chapters;

  const Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.accentColor,
    this.syllabusUrl,
    this.pastPapers = const [],
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
  final String? fileUrl;

  const Note({
    required this.id,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
    this.fileUrl,
  });
}

class NoteSubmission {
  final String id;
  final String chapterId;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;
  final List<String> tags;
  final String status;
  final String? fileUrl;
  final String? adminFeedback;
  final DateTime? createdAt;

  const NoteSubmission({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
    required this.tags,
    required this.status,
    this.fileUrl,
    this.adminFeedback,
    this.createdAt,
  });
}

class NoteDraft {
  final String title;
  final String shortAnswer;
  final String detailedAnswer;

  const NoteDraft({
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
  });
}

class AiHistoryItem {
  final String text;
  final DateTime? createdAt;

  const AiHistoryItem({
    required this.text,
    this.createdAt,
  });
}

class UserNote {
  final String id;
  final String title;
  final String shortAnswer;
  final String detailedAnswer;
  final String? chapterId;

  const UserNote({
    required this.id,
    required this.title,
    required this.shortAnswer,
    required this.detailedAnswer,
    this.chapterId,
  });
}

class Question {
  final String id;
  final String prompt;
  final int marks;
  final String kind;
  final int? year;

  const Question({
    required this.id,
    required this.prompt,
    required this.marks,
    this.kind = 'important',
    this.year,
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

class QuizCardItem {
  final Quiz quiz;
  final Subject subject;

  const QuizCardItem({
    required this.quiz,
    required this.subject,
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

class QuizAnswerReview {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final int? selectedIndex;
  final String? explanation;

  const QuizAnswerReview({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    this.explanation,
  });

  bool get isCorrect =>
      selectedIndex != null && selectedIndex == correctIndex;
}

class WeakTopic {
  final String name;
  final String reason;

  const WeakTopic({
    required this.name,
    required this.reason,
  });
}

class PastPaper {
  final String id;
  final String title;
  final int? year;
  final String fileUrl;

  const PastPaper({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.year,
  });
}

class StudyTask {
  final String id;
  final String title;
  final String subject;
  final bool isDone;
  final String? dueDate;

  const StudyTask({
    this.id = '',
    required this.title,
    required this.subject,
    required this.isDone,
    this.dueDate,
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

class CommunityQuestion {
  final String id;
  final String subjectId;
  final String userId;
  final String question;
  final String status;
  final bool aiValid;
  final String? aiReason;
  final DateTime? createdAt;

  const CommunityQuestion({
    required this.id,
    required this.subjectId,
    required this.userId,
    required this.question,
    required this.status,
    required this.aiValid,
    this.aiReason,
    this.createdAt,
  });
}

class CommunityAnswer {
  final String id;
  final String questionId;
  final String userId;
  final String answer;
  final DateTime? createdAt;

  const CommunityAnswer({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.answer,
    this.createdAt,
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
