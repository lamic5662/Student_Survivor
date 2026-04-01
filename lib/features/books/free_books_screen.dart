import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';

class FreeBooksScreen extends StatefulWidget {
  const FreeBooksScreen({super.key});

  @override
  State<FreeBooksScreen> createState() => _FreeBooksScreenState();
}

class _FreeBooksScreenState extends State<FreeBooksScreen> {
  _BookFilter _filter = _BookFilter.cs;

  @override
  Widget build(BuildContext context) {
    final sources = _bookSources;
    final query = _filterQuery(_filter);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Books'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            color: AppColors.secondary.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free textbook libraries',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse open textbooks from trusted sources. Use the site '
                  'search to find BCA topics like programming, databases, OS, '
                  'networks, and statistics.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Sources'),
          const SizedBox(height: 12),
          _FilterRow(
            filter: _filter,
            onChanged: (value) {
              setState(() {
                _filter = value;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Showing results for: ${_filterLabel(_filter)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 12),
          ...sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SourceCard(
                source: source,
                query: query,
                filterLabel: _filterLabel(_filter),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Suggested Topics'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _TopicChip('Programming'),
              _TopicChip('Data Structures'),
              _TopicChip('DBMS'),
              _TopicChip('Operating Systems'),
              _TopicChip('Computer Networks'),
              _TopicChip('Web Tech'),
              _TopicChip('Discrete Math'),
              _TopicChip('Statistics'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final _BookSource source;
  final String query;
  final String filterLabel;

  const _SourceCard({
    required this.source,
    required this.query,
    required this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openSource(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: source.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(source.icon, color: source.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            source.subtitle,
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
                const SizedBox(height: 12),
                Text(
                  source.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => _openFiltered(context),
                      child: Text('Open $filterLabel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SyllabusWebViewScreen(
                              title: source.name,
                              url: source.url,
                            ),
                          ),
                        );
                      },
                      child: const Text('Visit site'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openSource(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: source.name,
          url: source.url,
        ),
      ),
    );
  }

  void _openFiltered(BuildContext context) {
    final url = source.searchUrlBuilder != null
        ? source.searchUrlBuilder!(query)
        : source.url;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: '${source.name} • $filterLabel',
          url: url,
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;

  const _TopicChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.ink),
      ),
    );
  }
}

class _BookSource {
  final String name;
  final String subtitle;
  final String description;
  final String url;
  final String Function(String query)? searchUrlBuilder;
  final IconData icon;
  final Color accent;

  const _BookSource({
    required this.name,
    required this.subtitle,
    required this.description,
    required this.url,
    this.searchUrlBuilder,
    required this.icon,
    required this.accent,
  });
}

const _bookSources = [
  _BookSource(
    name: 'OpenStax',
    subtitle: 'Peer-reviewed open textbooks',
    description:
        'High-quality, openly licensed textbooks used by universities.',
    url: 'https://openstax.org/subjects',
    searchUrlBuilder: _openStaxSearchUrl,
    icon: Icons.auto_stories_rounded,
    accent: AppColors.secondary,
  ),
  _BookSource(
    name: 'Open Textbook Library',
    subtitle: 'Free college textbooks',
    description:
        'Curated, faculty-reviewed open textbooks across many subjects.',
    url: 'https://open.umn.edu/opentextbooks',
    searchUrlBuilder: _openTextbookLibrarySearchUrl,
    icon: Icons.menu_book_rounded,
    accent: AppColors.accent,
  ),
  _BookSource(
    name: 'LibreTexts',
    subtitle: 'Open educational resources',
    description:
        'Massive collection of open textbooks and learning resources.',
    url: 'https://libretexts.org',
    searchUrlBuilder: _libreTextsSearchUrl,
    icon: Icons.local_library_rounded,
    accent: AppColors.warning,
  ),
];

class _FilterRow extends StatelessWidget {
  final _BookFilter filter;
  final ValueChanged<_BookFilter> onChanged;

  const _FilterRow({
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('CS'),
          selected: filter == _BookFilter.cs,
          onSelected: (_) => onChanged(_BookFilter.cs),
        ),
        ChoiceChip(
          label: const Text('BCA'),
          selected: filter == _BookFilter.bca,
          onSelected: (_) => onChanged(_BookFilter.bca),
        ),
      ],
    );
  }
}

enum _BookFilter { cs, bca }

String _filterQuery(_BookFilter filter) {
  switch (filter) {
    case _BookFilter.cs:
      return 'computer science';
    case _BookFilter.bca:
      return 'computer applications';
  }
}

String _filterLabel(_BookFilter filter) {
  switch (filter) {
    case _BookFilter.cs:
      return 'CS Books';
    case _BookFilter.bca:
      return 'BCA Books';
  }
}

String _openStaxSearchUrl(String query) {
  final encoded = Uri.encodeComponent(query);
  return 'https://openstax.org/search?query=$encoded';
}

String _openTextbookLibrarySearchUrl(String query) {
  final encoded = Uri.encodeComponent(query);
  return 'https://open.umn.edu/opentextbooks/textbooks?term=$encoded';
}

String _libreTextsSearchUrl(String query) {
  final encoded = Uri.encodeComponent(query);
  return 'https://libretexts.org/search?query=$encoded';
}
