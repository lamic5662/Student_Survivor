import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _coachService = CoachService(DashboardService(SupabaseConfig.client));
    _load();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
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
        _error = context.tr(
          'Coach failed: $error',
          'कोच असफल भयो: $error',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset =
        MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return GameZoneScaffold(
      extendBodyBehindAppBar: true,
      useSafeArea: false,
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.tr('AI Personal Coach', 'एआई पर्सनल कोच'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(20, topInset, 20, 24),
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
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Today’s AI Coach Plan', 'आजको एआई कोच योजना'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Personalized for ${snapshot.date.toIso8601String().split('T').first}',
                    'मिति: ${snapshot.date.toIso8601String().split('T').first}',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Weak Topics', 'कमजोर विषयहरू'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          if (topics.isEmpty)
            Text(
              context.tr(
                'No weak topics detected yet. Take a quiz to unlock insights.',
                'अहिले कमजोर विषय भेटिएन। जानकारीका लागि क्विज दिनुहोस्।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('What to study next', 'अर्को के पढ्ने'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Smart Suggestions', 'स्मार्ट सुझावहरू'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            Text(
              context.tr(
                'Complete more quizzes to unlock tips.',
                'थप सुझावका लागि धेरै क्विज पूरा गर्नुहोस्।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: Icon(Icons.tune, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Adaptive Difficulty', 'अनुकुल कठिनाइ'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Recommended level: ${difficulty.toUpperCase()}',
                    'सिफारिस स्तर: ${difficulty.toUpperCase()}',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF111B2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Ask your coach', 'कोचसँग सोध्नुहोस्'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Chat for explanations or study help.',
                    'व्याख्या वा पढाइ सहयोगका लागि च्याट गर्नुहोस्।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('Open Chat', 'च्याट खोल्नुहोस्')),
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
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Daily Plan', 'दैनिक योजना'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          if (plan.isEmpty)
            Text(
              context.tr(
                'Add subjects to generate a study plan.',
                'अध्ययन योजना बनाउन विषयहरू थप्नुहोस्।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detail,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
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
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Daily 10 Questions', 'दैनिक १० प्रश्न'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          if (questions.isEmpty)
            Text(
              context.tr(
                'No notes available to build daily questions.',
                'दैनिक प्रश्न बनाउन नोट उपलब्ध छैन।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            )
          else
            ...questions.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OutlineCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${entry.key + 1}. ',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          MathText(
                            text: entry.value.prompt,
                            textStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.value.source,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          if (revealed.contains(entry.key))
                            MathText(
                              text: entry.value.answer,
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => onToggle(entry.key),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF38BDF8),
                              ),
                              child: Text(
                                revealed.contains(entry.key)
                                    ? context.tr('Hide answer', 'उत्तर लुकाउनुहोस्')
                                    : context.tr(
                                        'Show answer',
                                        'उत्तर देखाउनुहोस्',
                                      ),
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _OutlineCard extends StatelessWidget {
  final Widget child;

  const _OutlineCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: child,
    );
  }
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}
