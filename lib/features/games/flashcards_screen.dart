import 'dart:math';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/ai_status_chip.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/models/app_models.dart';

class FlashcardsScreen extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;

  const FlashcardsScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  late final UserNotesService _userNotesService;
  late final AiNotesService _aiNotesService;
  bool _isLoading = true;
  bool _isGeneratingAi = false;
  String? _aiError;
  bool _showBack = false;
  int _index = 0;
  bool _usingAi = false;
  List<_FlashcardItem> _noteCards = const [];
  List<_FlashcardItem> _cards = const [];
  late final ActivityLogService _activityLogService;

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
    _activityLogService = ActivityLogService(SupabaseConfig.client);
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });
    final userNotes =
        await _userNotesService.fetchForChapter(widget.chapter.id);
    final cards = <_FlashcardItem>[];

    for (final note in widget.chapter.notes) {
      final back = note.detailedAnswer.isNotEmpty
          ? note.detailedAnswer
          : note.shortAnswer;
      if (back.trim().isEmpty) {
        continue;
      }
      cards.add(
        _FlashcardItem(
          title: note.title,
          front: note.title,
          back: back.trim(),
          source: 'Official',
        ),
      );
    }

    for (final note in userNotes) {
      final back = note.detailedAnswer.isNotEmpty
          ? note.detailedAnswer
          : note.shortAnswer;
      if (back.trim().isEmpty) {
        continue;
      }
      cards.add(
        _FlashcardItem(
          title: note.title,
          front: note.title,
          back: back.trim(),
          source: 'My Notes',
        ),
      );
    }

    setState(() {
      _noteCards = cards;
      _cards = cards;
      _index = 0;
      _showBack = false;
      _isLoading = false;
      _usingAi = false;
    });
  }

  Future<void> _generateAiCards() async {
    if (_isGeneratingAi) return;
    setState(() {
      _isGeneratingAi = true;
      _aiError = null;
    });
    try {
      final aiCards = await _aiNotesService.generateFlashcards(
        subject: widget.subject,
        chapter: widget.chapter,
      );
      final cards = aiCards
          .map(
            (card) => _FlashcardItem(
              title: card.front,
              front: card.front,
              back: card.back,
              source: 'AI',
            ),
          )
          .toList();
      final merged = [..._noteCards, ...cards];
      if (merged.isEmpty) {
        throw Exception('AI returned empty cards.');
      }
      setState(() {
        _cards = merged;
        _index = 0;
        _showBack = false;
        _usingAi = true;
      });
    } catch (error) {
      setState(() {
        _aiError = error.toString();
      });
    } finally {
      setState(() {
        _isGeneratingAi = false;
      });
    }
  }

  void _useNotesCards() {
    setState(() {
      _cards = _noteCards;
      _index = 0;
      _showBack = false;
      _usingAi = false;
    });
  }

  void _nextCard() {
    if (_cards.isEmpty) return;
    setState(() {
      _index = (_index + 1) % _cards.length;
      _showBack = false;
    });
    _activityLogService.logActivityUnawaited(
      type: 'flashcard_review',
      source: 'flashcards',
      points: 1,
      subjectId: widget.subject.id,
      chapterId: widget.chapter.id,
      metadata: {
        'source': _cards[_index].source,
        'deck': _usingAi ? 'ai' : 'notes',
      },
    );
  }

  void _prevCard() {
    if (_cards.isEmpty) return;
    setState(() {
      _index = (_index - 1) < 0 ? _cards.length - 1 : _index - 1;
      _showBack = false;
    });
  }

  void _shuffleCards() {
    if (_cards.length < 2) return;
    final shuffled = [..._cards]..shuffle(Random());
    setState(() {
      _cards = shuffled;
      _index = 0;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(
        'Flashcards',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        28,
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _arenaAccent),
            )
          : _cards.isNotEmpty
              ? _buildCardsView(_cards[_index])
              : _EmptyFlashcards(
                  onRefresh: _loadCards,
                  onGenerateAi: _generateAiCards,
                  isGeneratingAi: _isGeneratingAi,
                  aiError: _aiError,
                ),
    );
    return GameZoneScaffold(
      appBar: appBar,
      body: body,
      useSafeArea: false,
      extendBodyBehindAppBar: true,
    );
  }

  Widget _buildCardsView(_FlashcardItem current) {
    return Column(
      children: [
        const SizedBox(height: 4),
        _ArenaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose deck',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              const AiStatusChip(compact: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _usingAi ? _useNotesCards : null,
                      style: _arenaTonalButtonStyle(),
                      child: const Text('Notes Cards'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _isGeneratingAi ? null : _generateAiCards,
                      style: _arenaTonalButtonStyle(),
                      child: _isGeneratingAi
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('AI Cards'),
                    ),
                  ),
                ],
              ),
              if (_aiError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _aiError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.danger),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ArenaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _InfoPill(
                icon: Icons.layers_rounded,
                label: '${_index + 1} / ${_cards.length}',
              ),
              const SizedBox(width: 8),
              _InfoPill(
                icon: Icons.bookmark_rounded,
                label: current.source,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showBack = !_showBack;
              });
            },
            child: _ArenaCard(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _FlashcardFace(
                  key: ValueKey(_showBack),
                  title: current.title,
                  label: _showBack ? 'Answer' : 'Prompt',
                  content: _showBack ? current.back : current.front,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _prevCard,
                style: _arenaTonalButtonStyle(),
                child: const Text('Prev'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _nextCard,
                style: _arenaPrimaryButtonStyle(),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: _shuffleCards,
                style: _arenaTonalButtonStyle(),
                child: const Text('Shuffle'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _showBack = !_showBack;
                  });
                },
                style: _arenaTonalButtonStyle(),
                child: Text(_showBack ? 'Show Prompt' : 'Show Answer'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the card to flip.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: _arenaMuted),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _arenaSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _arenaBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _arenaAccent),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _FlashcardItem {
  final String title;
  final String front;
  final String back;
  final String source;

  const _FlashcardItem({
    required this.title,
    required this.front,
    required this.back,
    required this.source,
  });
}

class _FlashcardFace extends StatelessWidget {
  final String title;
  final String label;
  final String content;

  const _FlashcardFace({
    super.key,
    required this.title,
    required this.label,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: _arenaMuted),
        ),
        const SizedBox(height: 8),
        MathText(
          text: title,
          textStyle: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: MathText(
              text: content,
              textStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFlashcards extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onGenerateAi;
  final bool isGeneratingAi;
  final String? aiError;

  const _EmptyFlashcards({
    required this.onRefresh,
    required this.onGenerateAi,
    required this.isGeneratingAi,
    required this.aiError,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArenaCard(
            child: Column(
              children: [
                const Icon(Icons.style_outlined,
                    size: 48, color: _arenaMuted),
                const SizedBox(height: 12),
                Text(
                  'No flashcards yet.',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add notes or generate AI notes to create flashcards.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _arenaMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onRefresh,
                    style: _arenaTonalButtonStyle(),
                    child: const Text('Refresh'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isGeneratingAi ? null : onGenerateAi,
                    style: _arenaPrimaryButtonStyle(),
                    child: isGeneratingAi
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Generate AI Cards'),
                  ),
                ),
              ],
            ),
          ),
          if (aiError != null) ...[
            const SizedBox(height: 8),
            Text(
              aiError!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

const _arenaSurface = Color(0xFF0B1220);
const _arenaBorder = Color(0xFF1E2A44);
const _arenaMuted = Color(0xFF94A3B8);
const _arenaAccent = Color(0xFF4FA3C7);

ButtonStyle _arenaPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _arenaAccent,
    foregroundColor: const Color(0xFF0B1220),
  );
}

ButtonStyle _arenaTonalButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF111B2E),
    foregroundColor: Colors.white,
  );
}

class _ArenaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _ArenaCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _arenaSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _arenaBorder),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}
