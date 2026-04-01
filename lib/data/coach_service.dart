import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/data/dashboard_service.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/models/coach_models.dart';

class CoachService {
  static const _questionsCacheKey = 'coach_daily_questions_v1';
  static const _questionsDateKey = 'coach_daily_questions_date_v1';

  final DashboardService _dashboardService;

  CoachService(this._dashboardService);

  Future<CoachSnapshot> buildSnapshot({
    required List<Subject> subjects,
  }) async {
    DashboardData? dashboard;
    try {
      dashboard = await _dashboardService.fetchDashboard(subjects: subjects);
    } catch (_) {}

    final weakTopics = dashboard?.weakTopics ?? const <WeakTopic>[];
    final recommendedDifficulty =
        _recommendedDifficulty(dashboard?.latestAttempt);
    final dailyQuestions = await _loadOrGenerateQuestions(
      subjects: subjects,
      weakTopics: weakTopics,
      limit: 10,
    );
    final plan = _buildDailyPlan(subjects, weakTopics);
    final suggestions = _buildSmartSuggestions(subjects, weakTopics);
    final suggestion =
        suggestions.isNotEmpty ? suggestions.first : _buildNextSuggestion(subjects, weakTopics);
    return CoachSnapshot(
      date: DateTime.now(),
      weakTopics: weakTopics,
      nextSuggestion: suggestion,
      smartSuggestions: suggestions,
      recommendedDifficulty: recommendedDifficulty,
      dailyPlan: plan,
      dailyQuestions: dailyQuestions,
    );
  }

  String _recommendedDifficulty(QuizAttempt? attempt) {
    if (attempt == null || attempt.total == 0) {
      return 'medium';
    }
    final ratio = attempt.score / attempt.total;
    if (ratio >= 0.85) {
      return 'hard';
    }
    if (ratio >= 0.6) {
      return 'medium';
    }
    return 'easy';
  }

  String _buildNextSuggestion(
    List<Subject> subjects,
    List<WeakTopic> weakTopics,
  ) {
    if (weakTopics.isNotEmpty) {
      return 'Focus next on "${weakTopics.first.name}". Review notes and try 10 practice questions.';
    }
    if (subjects.isEmpty) {
      return 'Add your semester subjects to unlock a personalized plan.';
    }
    final subject = subjects.first;
    return 'Continue with ${subject.name}. Review two chapters and take a short quiz.';
  }

  List<String> _buildSmartSuggestions(
    List<Subject> subjects,
    List<WeakTopic> weakTopics,
  ) {
    if (weakTopics.isNotEmpty) {
      final primary = weakTopics.first.name;
      final secondary =
          weakTopics.length > 1 ? weakTopics[1].name : weakTopics.first.name;
      return [
        'Revise $primary notes and highlight 3 key points.',
        'Practice 5 MCQs on $primary right now.',
        'Summarize $secondary in 5 bullet points.',
      ];
    }
    if (subjects.isEmpty) {
      return [
        'Add subjects in your profile to unlock personalized tips.',
      ];
    }
    final subject = subjects.first.name;
    return [
      'Start with $subject and review the first chapter.',
      'Take a 10-question quiz to find weak areas.',
      'Write a 3-line summary of today’s topic.',
    ];
  }

  List<CoachPlanItem> _buildDailyPlan(
    List<Subject> subjects,
    List<WeakTopic> weakTopics,
  ) {
    if (subjects.isEmpty) {
      return const [];
    }
    final primarySubject = subjects.first;
    final weakLabel =
        weakTopics.isNotEmpty ? weakTopics.first.name : primarySubject.name;
    return [
      CoachPlanItem(
        title: 'Review weak topic',
        detail: 'Read notes for $weakLabel and highlight 3 key points.',
        duration: '20 min',
      ),
      CoachPlanItem(
        title: 'Practice questions',
        detail: 'Answer today’s 10 questions and mark what felt hard.',
        duration: '20 min',
      ),
      CoachPlanItem(
        title: 'Quick recap',
        detail: 'Summarize what you learned in 5 bullet points.',
        duration: '10 min',
      ),
    ];
  }

  Future<List<CoachQuestion>> _loadOrGenerateQuestions({
    required List<Subject> subjects,
    required List<WeakTopic> weakTopics,
    int limit = 10,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dateKey(DateTime.now());
    final cachedDate = prefs.getString(_questionsDateKey);
    if (cachedDate == todayKey) {
      final cachedRaw = prefs.getString(_questionsCacheKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedRaw);
          if (decoded is List) {
            return decoded
                .whereType<Map>()
                .map((e) => CoachQuestion.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList();
          }
        } catch (_) {}
      }
    }

    final notes = _collectNotes(subjects);
    if (notes.isEmpty) {
      return const [];
    }

    final pool = _filterNotesByWeakTopics(notes, weakTopics);
    final selected = _pickDailyNotes(
      pool.isEmpty ? notes : pool,
      notes,
      limit,
      seed: todayKey.hashCode,
    );

    final questions = selected
        .where((note) => note.answer.trim().isNotEmpty)
        .map(
          (note) => CoachQuestion(
            prompt: 'Explain: ${note.title}',
            answer: note.answer,
            source: '${note.subject} • ${note.chapter}',
          ),
        )
        .toList();

    await prefs.setString(
      _questionsCacheKey,
      jsonEncode(questions.map((q) => q.toJson()).toList()),
    );
    await prefs.setString(_questionsDateKey, todayKey);
    return questions;
  }

  String _dateKey(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  List<_CoachNote> _collectNotes(List<Subject> subjects) {
    final notes = <_CoachNote>[];
    for (final subject in subjects) {
      for (final chapter in subject.chapters) {
        for (final note in chapter.notes) {
          final answer =
              note.detailedAnswer.trim().isNotEmpty ? note.detailedAnswer : note.shortAnswer;
          notes.add(
            _CoachNote(
              id: note.id,
              title: note.title,
              answer: answer,
              subject: subject.name,
              chapter: chapter.title,
            ),
          );
        }
      }
    }
    return notes;
  }

  List<_CoachNote> _filterNotesByWeakTopics(
    List<_CoachNote> notes,
    List<WeakTopic> weakTopics,
  ) {
    if (weakTopics.isEmpty) return [];
    final keywords = weakTopics
        .map((t) => t.name.toLowerCase())
        .where((k) => k.isNotEmpty)
        .toList();
    return notes.where((note) {
      final haystack =
          '${note.title} ${note.chapter} ${note.subject}'.toLowerCase();
      return keywords.any((k) => haystack.contains(k));
    }).toList();
  }

  List<_CoachNote> _pickDailyNotes(
    List<_CoachNote> primary,
    List<_CoachNote> fallback,
    int limit, {
    required int seed,
  }) {
    final random = Random(seed);
    final picked = <_CoachNote>[];
    final primaryCopy = List<_CoachNote>.from(primary);
    primaryCopy.shuffle(random);
    for (final note in primaryCopy) {
      picked.add(note);
      if (picked.length >= limit) break;
    }
    if (picked.length < limit) {
      final fallbackCopy = List<_CoachNote>.from(fallback);
      fallbackCopy.shuffle(random);
      for (final note in fallbackCopy) {
        if (picked.any((p) => p.id == note.id)) continue;
        picked.add(note);
        if (picked.length >= limit) break;
      }
    }
    return picked;
  }
}

class _CoachNote {
  final String id;
  final String title;
  final String answer;
  final String subject;
  final String chapter;

  const _CoachNote({
    required this.id,
    required this.title,
    required this.answer,
    required this.subject,
    required this.chapter,
  });
}
