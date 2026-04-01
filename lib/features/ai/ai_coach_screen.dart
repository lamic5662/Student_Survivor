import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/coach_service.dart';
import 'package:student_survivor/data/dashboard_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/ai/ai_screen.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/models/coach_models.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  late final CoachService _coachService;
  CoachSnapshot? _snapshot;
  bool _isLoading = true;
  String? _error;
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _coachService = CoachService(DashboardService(SupabaseConfig.client));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _coachService.buildSnapshot(
        subjects: AppState.profile.value.subjects,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Coach failed: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Personal Coach'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _CoachHero(snapshot: _snapshot!),
                      const SizedBox(height: 16),
                      _WeakTopicsCard(topics: _snapshot!.weakTopics),
                      const SizedBox(height: 16),
                      _SmartSuggestionsCard(
                        suggestions: _snapshot!.smartSuggestions,
                      ),
                      const SizedBox(height: 16),
                      _NextStudyCard(text: _snapshot!.nextSuggestion),
                      const SizedBox(height: 16),
                      _AdaptiveCard(
                        difficulty: _snapshot!.recommendedDifficulty,
                      ),
                      const SizedBox(height: 16),
                      _DailyPlanCard(plan: _snapshot!.dailyPlan),
                      const SizedBox(height: 16),
                      _DailyQuestionsCard(
                        questions: _snapshot!.dailyQuestions,
                        revealed: _revealed,
                        onToggle: (index) {
                          setState(() {
                            if (_revealed.contains(index)) {
                              _revealed.remove(index);
                            } else {
                              _revealed.add(index);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      _AskCoachCard(onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AiAssistantScreen(),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _CoachHero extends StatelessWidget {
  final CoachSnapshot snapshot;

  const _CoachHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s AI Coach Plan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalized for ${snapshot.date.toIso8601String().split('T').first}',
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
    );
  }
}

class _WeakTopicsCard extends StatelessWidget {
  final List<WeakTopic> topics;

  const _WeakTopicsCard({required this.topics});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weak Topics',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (topics.isEmpty)
            Text(
              'No weak topics detected yet. Take a quiz to unlock insights.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topics
                  .map(
                    (topic) => _Chip(
                      label: topic.name,
                      color: AppColors.warning,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _NextStudyCard extends StatelessWidget {
  final String text;

  const _NextStudyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What to study next',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SmartSuggestionsCard extends StatelessWidget {
  final List<String> suggestions;

  const _SmartSuggestionsCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Suggestions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            Text(
              'Complete more quizzes to unlock tips.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else
            ...suggestions.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Bullet(color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdaptiveCard extends StatelessWidget {
  final String difficulty;

  const _AdaptiveCard({required this.difficulty});

  Color _colorFor(String value) {
    switch (value) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(difficulty);
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.tune, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adaptive Difficulty',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended level: ${difficulty.toUpperCase()}',
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
    );
  }
}

class _AskCoachCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _AskCoachCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask your coach',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chat for explanations or study help.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onOpen,
            child: const Text('Open Chat'),
          ),
        ],
      ),
    );
  }
}

class _DailyPlanCard extends StatelessWidget {
  final List<CoachPlanItem> plan;

  const _DailyPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Plan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (plan.isEmpty)
            Text(
              'Add subjects to generate a study plan.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else
            ...plan.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bullet(color: AppColors.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detail,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chip(label: item.duration, color: AppColors.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyQuestionsCard extends StatelessWidget {
  final List<CoachQuestion> questions;
  final Set<int> revealed;
  final ValueChanged<int> onToggle;

  const _DailyQuestionsCard({
    required this.questions,
    required this.revealed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily 10 Questions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (questions.isEmpty)
            Text(
              'No notes available to build daily questions.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else
            ...questions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      color: AppColors.paper,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${entry.key + 1}. ${entry.value.prompt}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.value.source,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                          const SizedBox(height: 8),
                          if (revealed.contains(entry.key))
                            Text(
                              entry.value.answer,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => onToggle(entry.key),
                              child: Text(
                                revealed.contains(entry.key)
                                    ? 'Hide answer'
                                    : 'Show answer',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final Color color;

  const _Bullet({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
