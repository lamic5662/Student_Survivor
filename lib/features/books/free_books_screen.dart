import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';

class FreeBooksScreen extends StatefulWidget {
  const FreeBooksScreen({super.key});

  @override
  State<FreeBooksScreen> createState() => _FreeBooksScreenState();
}

class _FreeBooksScreenState extends State<FreeBooksScreen> {
  _BookFilter _filter = _BookFilter.cs;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final sources = _bookSources;
    final query = _filterQuery(_filter);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.l10n.freeBooks,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _BooksBackdrop()),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              20,
              28,
            ),
            children: [
              _GameCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'Free textbook libraries',
                        'निःशुल्क पाठ्यपुस्तक पुस्तकालय',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr(
                        'Browse open textbooks from trusted sources. Use the site '
                        'search to find BCA topics like programming, databases, OS, '
                        'networks, and statistics.',
                        'विश्वसनीय स्रोतबाट खुला पाठ्यपुस्तकहरू हेर्नुहोस्। '
                        'प्रोग्रामिङ, डेटाबेस, OS, नेटवर्क र सांख्यिकी जस्ता '
                        'BCA विषयहरू खोज्न साइट खोज प्रयोग गर्नुहोस्।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.tr('Sources', 'स्रोतहरू'),
              ),
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
                context.tr(
                  'Showing results for: ${_filterLabel(_filter)}',
                  'नतिजा देखाइँदै: ${_filterLabel(_filter)}',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
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
              _SectionTitle(
                title: context.tr('Suggested Topics', 'सुझाव गरिएको विषय'),
              ),
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
    return _GameCard(
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
                        color: const Color(0xFF111B2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E2A44)),
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            source.subtitle,
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
                const SizedBox(height: 12),
                Text(
                  source.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'Source: ${source.name}. Open‑license library. Content stays on the source site.',
                    'स्रोत: ${source.name}। खुला लाइसेन्स पुस्तकालय। सामग्री स्रोत साइटमै छ।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _openFiltered(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4FA3C7),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        context.tr(
                          'Open $filterLabel',
                          '$filterLabel खोल्नुहोस्',
                        ),
                      ),
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
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: Text(
                        context.tr('Visit site', 'वेबसाइट खोल्नुहोस्'),
                      ),
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
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white70),
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
          selectedColor: const Color(0xFF4FA3C7),
          backgroundColor: const Color(0xFF111B2E),
          side: const BorderSide(color: Color(0xFF1E2A44)),
          labelStyle: TextStyle(
            color: filter == _BookFilter.cs ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        ChoiceChip(
          label: const Text('BCA'),
          selected: filter == _BookFilter.bca,
          onSelected: (_) => onChanged(_BookFilter.bca),
          selectedColor: const Color(0xFF4FA3C7),
          backgroundColor: const Color(0xFF111B2E),
          side: const BorderSide(color: Color(0xFF1E2A44)),
          labelStyle: TextStyle(
            color: filter == _BookFilter.bca ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _BooksBackdrop extends StatelessWidget {
  const _BooksBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _BooksGridPainter())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _BooksGridPainter extends CustomPainter {
  const _BooksGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF4FA3C7).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BooksGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GameCard({required this.child, this.padding});

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
        padding: padding ?? const EdgeInsets.all(16),
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
