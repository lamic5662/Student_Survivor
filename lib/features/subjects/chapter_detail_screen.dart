import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/quiz/quiz_detail_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class ChapterDetailScreen extends StatelessWidget {
  final Subject subject;
  final Chapter chapter;

  const ChapterDetailScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(chapter.title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Notes'),
              Tab(text: 'Important'),
              Tab(text: 'Past Qs'),
              Tab(text: 'Quizzes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotesTab(notes: chapter.notes),
            _QuestionsTab(questions: chapter.importantQuestions),
            _QuestionsTab(questions: chapter.pastQuestions),
            _QuizzesTab(subject: subject, quizzes: chapter.quizzes),
          ],
        ),
      ),
    );
  }
}

class _NotesTab extends StatelessWidget {
  final List<Note> notes;

  const _NotesTab({required this.notes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  note.shortAnswer,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                Text(
                  note.detailedAnswer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final List<Question> questions;

  const _QuestionsTab({required this.questions});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.help_outline, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${question.marks} marks',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuizzesTab extends StatelessWidget {
  final Subject subject;
  final List<Quiz> quizzes;

  const _QuizzesTab({required this.subject, required this.quizzes});

  @override
  Widget build(BuildContext context) {
    if (quizzes.isEmpty) {
      return const Center(child: Text('No quizzes yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${quiz.questionCount} questions • ${quiz.duration.inMinutes} min',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizDetailScreen(
                            quiz: quiz,
                            subject: subject,
                          ),
                        ),
                      );
                    },
                    child: const Text('Play Quiz'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
