import 'dart:math';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/ai_notes_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectFlashcardsScreen extends StatefulWidget {
  final Subject subject;

  const SubjectFlashcardsScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectFlashcardsScreen> createState() =>
      _SubjectFlashcardsScreenState();
}

class _SubjectFlashcardsScreenState extends State<SubjectFlashcardsScreen> {
  late final UserNotesService _userNotesService;
  late final AiNotesService _aiNotesService;
  late final Chapter _subjectChapter;
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
    _subjectChapter = _buildSubjectChapter(widget.subject);
    _loadCards();
  }

  Chapter _buildSubjectChapter(Subject subject) {
    final notes = <Note>[];
    final important = <Question>[];
    final past = <Question>[];
    for (final chapter in subject.chapters) {
      notes.addAll(chapter.notes);
      important.addAll(chapter.importantQuestions);
      past.addAll(chapter.pastQuestions);
    }
    return Chapter(
      id: 'subject_${subject.id}',
      title: '${subject.name} Overview',
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: const [],
    );
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    final chapterIds = widget.subject.chapters
        .map((chapter) => chapter.id)
        .where((id) => id.isNotEmpty)
        .toList();
    final userNotes = await _userNotesService.fetchForSubject(chapterIds);

    final cards = <_FlashcardItem>[];
    for (final chapter in widget.subject.chapters) {
      for (final note in chapter.notes) {
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
            source: 'Official • ${chapter.title}',
          ),
        );
      }
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
        chapter: _subjectChapter,
        count: 10,
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
    final hasCards = _cards.isNotEmpty;
    final current = hasCards ? _cards[_index] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Flashcards'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : hasCards
                ? Column(
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
                              onPressed:
                                  _isGeneratingAi ? null : _generateAiCards,
                              child: Text(
                                _isGeneratingAi
                                    ? 'Generating...'
                                    : 'AI Cards',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: AppCard(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showBack = !_showBack;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _showBack
                                      ? current?.back ?? ''
                                      : current?.front ?? '',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showBack
                                      ? 'Tap to show question'
                                      : 'Tap to show answer',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.mutedInk),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _prevCard,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              '${_index + 1} / ${_cards.length}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            onPressed: _nextCard,
                            icon: const Icon(Icons.chevron_right),
                          ),
                          IconButton(
                            onPressed: _shuffleCards,
                            icon: const Icon(Icons.shuffle),
                          ),
                        ],
                      ),
                      if (_aiError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _aiError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                      ],
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.style, size: 48),
                        const SizedBox(height: 12),
                        const Text('No flashcards yet.'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _isGeneratingAi ? null : _generateAiCards,
                          child: const Text('Generate AI Flashcards'),
                        ),
                      ],
                    ),
                  ),
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
