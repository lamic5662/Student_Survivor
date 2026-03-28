import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(SupabaseConfig.client);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Search notes, questions, topics... (typo friendly)',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              Chip(label: Text('Notes')),
              Chip(label: Text('Important Questions')),
              Chip(label: Text('Quizzes')),
              Chip(label: Text('Topics')),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!)
          else if (_results.isEmpty)
            const Text('Type to search the syllabus and notes.')
          else
            ..._results.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.type,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.secondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.snippet,
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
        ],
      ),
    );
  }
}
