import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/search_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_study_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  late final SearchService _searchService;
  late final SubjectService _subjectService;
  Timer? _debounce;
  bool _isLoading = false;
  bool _isResolving = false;
  String? _errorMessage;
  List<SearchResult> _results = const [];
  _SearchIndex? _searchIndex;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(SupabaseConfig.client);
    _subjectService = SubjectService(SupabaseConfig.client);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() {
        _showTitle = shouldShow;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      if (query.isEmpty) {
        setState(() {
          _results = const [];
          _errorMessage = null;
        });
        return;
      }
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final results = await _searchService.search(query);
        if (!mounted) return;
        setState(() {
          _results = results;
          _isLoading = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = context.tr(
            'Search failed: $error',
            'खोज असफल: $error',
          );
          _isLoading = false;
        });
      }
    });
  }

  Future<_SearchIndex> _loadSearchIndex() async {
    if (_searchIndex != null) return _searchIndex!;
    final subjects =
        await _subjectService.fetchAllSubjects(includeContent: true);
    _searchIndex = _SearchIndex.fromSubjects(subjects);
    return _searchIndex!;
  }

  Future<void> _openResult(SearchResult result) async {
    if (_isResolving) return;
    setState(() {
      _isResolving = true;
    });
    try {
      final index = await _loadSearchIndex();
      if (!mounted) return;
      switch (result.rawType) {
        case 'subject':
          final subject = index.subjectById[result.id];
          if (subject == null) {
            _showNotFound();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SubjectDetailScreen(subject: subject, useGameZoneTheme: true),
            ),
          );
          break;
        case 'chapter':
          final chapter = index.chapterById[result.id];
          final subject = index.subjectByChapter[result.id];
          if (chapter == null || subject == null) {
            _showNotFound();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChapterDetailScreen(
                subject: subject,
                chapter: chapter,
                useGameZoneTheme: false,
              ),
            ),
          );
          break;
        case 'note':
          final chapter = index.chapterByNote[result.id];
          final subject = index.subjectByNote[result.id];
          if (chapter == null || subject == null) {
            _showNotFound();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChapterDetailScreen(
                subject: subject,
                chapter: chapter,
                useGameZoneTheme: false,
              ),
            ),
          );
          break;
        case 'question':
          final subject = index.subjectByQuestion[result.id];
          if (subject == null) {
            _showNotFound();
            return;
          }
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubjectStudyScreen(
                subject: subject,
                useGameZoneTheme: true,
                initialTabIndex: 1,
              ),
            ),
          );
          break;
        default:
          _showNotFound();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Unable to open: $error',
              'खोल्न सकिएन: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolving = false;
        });
      }
    }
  }

  void _showNotFound() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Content not found for this result.',
            'यो परिणामका लागि सामग्री भेटिएन।',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset =
        MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return GameZoneScaffold(
      useSafeArea: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.tr('Search', 'खोज'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, topInset, 20, 24),
        itemCount: _isLoading || _errorMessage != null || _results.isEmpty
            ? 5
            : 4 + _results.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _GameCard(
              child: TextField(
                controller: _controller,
                onChanged: _onQueryChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'Search notes, questions, topics... (typo friendly)',
                    'नोट, प्रश्न, विषय खोज्नुहोस्... (गल्ती भए पनि)',
                  ),
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0B1220),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF4FA3C7), width: 1.5),
                  ),
                ),
              ),
            );
          }
          if (index == 1) return const SizedBox(height: 16);
          if (index == 2) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SearchChip(label: context.tr('Notes', 'नोट')),
                _SearchChip(
                    label: context.tr(
                        'Important Questions', 'महत्त्वपूर्ण प्रश्न')),
                _SearchChip(label: context.tr('Quizzes', 'क्विज')),
                _SearchChip(label: context.tr('Topics', 'विषय')),
              ],
            );
          }
          if (index == 3) return const SizedBox(height: 20);
          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4FA3C7)),
            );
          }
          if (_errorMessage != null) {
            return Text(
              _errorMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFFF87171)),
            );
          }
          if (_results.isEmpty) {
            return Text(
              context.tr(
                'Type to search the syllabus and notes.',
                'पाठ्यक्रम र नोट खोज्न टाइप गर्नुहोस्।',
              ),
              style: const TextStyle(color: Colors.white70),
            );
          }
          final result = _results[index - 4];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _openResult(result),
              child: _GameCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.type,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF4FA3C7),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.snippet,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchIndex {
  final Map<String, Subject> subjectById;
  final Map<String, Chapter> chapterById;
  final Map<String, Subject> subjectByChapter;
  final Map<String, Chapter> chapterByNote;
  final Map<String, Subject> subjectByNote;
  final Map<String, Subject> subjectByQuestion;

  _SearchIndex({
    required this.subjectById,
    required this.chapterById,
    required this.subjectByChapter,
    required this.chapterByNote,
    required this.subjectByNote,
    required this.subjectByQuestion,
  });

  factory _SearchIndex.fromSubjects(List<Subject> subjects) {
    final subjectById = <String, Subject>{};
    final chapterById = <String, Chapter>{};
    final subjectByChapter = <String, Subject>{};
    final chapterByNote = <String, Chapter>{};
    final subjectByNote = <String, Subject>{};
    final subjectByQuestion = <String, Subject>{};

    for (final subject in subjects) {
      subjectById[subject.id] = subject;
      for (final chapter in subject.chapters) {
        chapterById[chapter.id] = chapter;
        subjectByChapter[chapter.id] = subject;
        for (final note in chapter.notes) {
          chapterByNote[note.id] = chapter;
          subjectByNote[note.id] = subject;
        }
        for (final question in chapter.importantQuestions) {
          subjectByQuestion[question.id] = subject;
        }
        for (final question in chapter.pastQuestions) {
          subjectByQuestion[question.id] = subject;
        }
      }
    }

    return _SearchIndex(
      subjectById: subjectById,
      chapterById: chapterById,
      subjectByChapter: subjectByChapter,
      chapterByNote: chapterByNote,
      subjectByNote: subjectByNote,
      subjectByQuestion: subjectByQuestion,
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;

  const _SearchChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF4FA3C7),
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
