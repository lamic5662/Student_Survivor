import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/search_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  late final SearchService _searchService;
  Timer? _debounce;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResult> _results = const [];
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(SupabaseConfig.client);
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
          _errorMessage = 'Search failed: $error';
          _isLoading = false;
        });
      }
    });
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
            'Search',
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
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20, topInset, 20, 24),
        children: [
          _GameCard(
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search notes, questions, topics... (typo friendly)',
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
                      const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _SearchChip(label: 'Notes'),
              _SearchChip(label: 'Important Questions'),
              _SearchChip(label: 'Quizzes'),
              _SearchChip(label: 'Topics'),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFFF87171)),
            )
          else if (_results.isEmpty)
            const Text(
              'Type to search the syllabus and notes.',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                              color: const Color(0xFF38BDF8),
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
            ),
        ],
      ),
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
