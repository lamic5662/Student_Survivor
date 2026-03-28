import 'dart:math';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _aiNotesService = AiNotesService(SupabaseConfig.client);
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
      if (cards.isEmpty) {
        throw Exception('AI returned empty cards.');
      }
      setState(() {
        _cards = cards;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _cards.isNotEmpty
                ? _buildCardsView(_cards[_index])
                : _EmptyFlashcards(
                    onRefresh: _loadCards,
                    onGenerateAi: _generateAiCards,
                    isGeneratingAi: _isGeneratingAi,
                    aiError: _aiError,
                  ),
      ),
    );
  }

  Widget _buildCardsView(_FlashcardItem current) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _usingAi ? _useNotesCards : null,
                child: const Text('Notes Cards'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _isGeneratingAi ? null : _generateAiCards,
                child: _isGeneratingAi
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_index + 1} / ${_cards.length}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            ),
            Text(
              current.source,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showBack = !_showBack;
              });
            },
            child: AppCard(
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
              child: OutlinedButton(
                onPressed: _prevCard,
                child: const Text('Prev'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _nextCard,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _shuffleCards,
                child: const Text('Shuffle'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showBack = !_showBack;
                  });
                },
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
              ?.copyWith(color: AppColors.mutedInk),
        ),
      ],
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
              ?.copyWith(color: AppColors.mutedInk),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
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
          const Icon(Icons.style_outlined, size: 48, color: AppColors.mutedInk),
          const SizedBox(height: 12),
          Text(
            'No flashcards yet.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Add notes or generate AI notes to create flashcards.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRefresh,
            child: const Text('Refresh'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: isGeneratingAi ? null : onGenerateAi,
            child: isGeneratingAi
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Generate AI Cards'),
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
