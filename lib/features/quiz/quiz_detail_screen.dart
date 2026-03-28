import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/quiz/quiz_play_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizDetailScreen extends StatefulWidget {
  final Quiz quiz;
  final Subject subject;
  final Chapter? chapter;

  const QuizDetailScreen({
    super.key,
    required this.quiz,
    required this.subject,
    this.chapter,
  });

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  bool _useAi = false;
  late QuizDifficulty _aiDifficulty;

  @override
  void initState() {
    super.initState();
    _aiDifficulty = widget.quiz.difficulty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: widget.subject.accentColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subject.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.quiz.questionCount} questions • ${widget.quiz.duration.inMinutes} min',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Game mode',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _modeLabel(widget.quiz.type),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 16),
                Text(
                  'Difficulty',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  (_useAi ? _aiDifficulty : widget.quiz.difficulty)
                      .name
                      .toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI Generated Questions'),
              subtitle: const Text(
                'Uses AI to generate questions and adapts difficulty (Ollama recommended).',
              ),
              value: _useAi,
              onChanged: (value) {
                setState(() {
                  _useAi = value;
                });
              },
            ),
          ),
          if (_useAi) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Difficulty',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<QuizDifficulty>(
                    initialValue: _aiDifficulty,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: QuizDifficulty.values
                        .map(
                          (difficulty) => DropdownMenuItem(
                            value: difficulty,
                            child: Text(difficulty.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _aiDifficulty = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What you will get',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text('XP points, adaptive feedback, and smart notes.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final quizToPlay = _useAi
                    ? Quiz(
                        id: widget.quiz.id,
                        title: widget.quiz.title,
                        type: widget.quiz.type,
                        difficulty: _aiDifficulty,
                        questionCount: widget.quiz.questionCount,
                        duration: widget.quiz.duration,
                      )
                    : widget.quiz;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizPlayScreen(
                      quiz: quizToPlay,
                      subject: widget.subject,
                      chapter: widget.chapter,
                      isAi: _useAi,
                    ),
                  ),
                );
              },
              child: const Text('Start Quiz'),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(QuizType type) {
    switch (type) {
      case QuizType.mcq:
        return 'MCQ Quickfire';
      case QuizType.time:
        return 'Time Attack';
      case QuizType.level:
        return 'Level Mode';
    }
  }
}
