import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/features/quiz/quiz_play_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class QuizDetailScreen extends StatefulWidget {
  final Quiz quiz;
  final Subject subject;
  final Chapter? chapter;
  final bool useGameZoneTheme;

  const QuizDetailScreen({
    super.key,
    required this.quiz,
    required this.subject,
    this.chapter,
    this.useGameZoneTheme = false,
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
    final appBar = AppBar(
      title: Text(widget.quiz.title),
      backgroundColor:
          widget.useGameZoneTheme ? AppColors.paper : null,
      foregroundColor: widget.useGameZoneTheme ? AppColors.ink : null,
      elevation: widget.useGameZoneTheme ? 0 : null,
      scrolledUnderElevation: widget.useGameZoneTheme ? 0 : null,
      surfaceTintColor:
          widget.useGameZoneTheme ? Colors.transparent : null,
    );

    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        AppCard(
          color: widget.useGameZoneTheme
              ? AppColors.surface
              : widget.subject.accentColor.withValues(alpha: 0.1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                  widget.subject.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    '${widget.quiz.questionCount} questions • ${widget.quiz.duration.inMinutes} min',
                    '${widget.quiz.questionCount} प्रश्न • ${widget.quiz.duration.inMinutes} मिनेट',
                  ),
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
                  context.tr('Game mode', 'गेम मोड'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _modeLabel(context, widget.quiz.type),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('Difficulty', 'कठिनाइ'),
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
              title: Text(
                context.tr('AI Generated Questions', 'AI प्रश्नहरू'),
              ),
              subtitle: Text(
                context.tr(
                  'Uses AI to generate questions and adapts difficulty (Ollama recommended).',
                  'AI ले प्रश्न बनाउँछ र कठिनाइ मिलाउँछ (Ollama सिफारिस)।',
                ),
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
                    context.tr('AI Difficulty', 'AI कठिनाइ'),
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
                  context.tr('What you will get', 'तपाईंले पाउनुहुने'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'XP points, adaptive feedback, and smart notes.',
                    'XP अंक, अनुकूली प्रतिक्रिया र स्मार्ट नोटहरू।',
                  ),
                ),
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
                      useGameZoneTheme: widget.useGameZoneTheme,
                    ),
                  ),
                );
              },
              child: Text(context.tr('Start Quiz', 'क्विज सुरु गर्नुहोस्')),
            ),
          ),
        ],
      );

    if (widget.useGameZoneTheme) {
      return GameZoneScaffold(
        appBar: appBar,
        body: body,
        useSafeArea: false,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
    );
  }

  String _modeLabel(BuildContext context, QuizType type) {
    switch (type) {
      case QuizType.mcq:
        return context.tr('MCQ Quickfire', 'MCQ छिटो');
      case QuizType.time:
        return context.tr('Time Attack', 'टाइम अट्याक');
      case QuizType.level:
        return context.tr('Level Mode', 'लेभल मोड');
    }
  }
}
