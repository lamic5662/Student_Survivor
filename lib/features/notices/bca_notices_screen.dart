import 'package:flutter/material.dart';
import 'package:student_survivor/data/bca_notice_service.dart';
import 'package:student_survivor/data/notice_cache_service.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/models/notice_models.dart';

enum _NoticeFilter { all, exam, form, result, admission, general }

class BcaNoticesScreen extends StatefulWidget {
  const BcaNoticesScreen({super.key});

  @override
  State<BcaNoticesScreen> createState() => _BcaNoticesScreenState();
}

class _BcaNoticesScreenState extends State<BcaNoticesScreen> {
  final _service = BcaNoticeService();
  final _cache = NoticeCacheService();
  List<BcaNotice> _notices = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  DateTime? _lastUpdated;
  _NoticeFilter _filter = _NoticeFilter.all;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _refreshFromNetwork(showSpinner: false);
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

  Future<void> _loadCached() async {
    final cached = await _cache.loadBcaNotices();
    final cachedTs = await _cache.loadBcaNoticesTimestamp();
    if (!mounted) return;
    setState(() {
      _notices = cached;
      _lastUpdated = cachedTs;
      _isLoading = cached.isEmpty;
    });
  }

  Future<void> _refreshFromNetwork({bool showSpinner = true}) async {
    if (showSpinner && _notices.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }
    try {
      final fresh = await _service.fetchNotices();
      if (!mounted) return;
      setState(() {
        _notices = fresh;
        _error = null;
      });
      await _cache.saveBcaNotices(fresh);
      final cachedTs = await _cache.loadBcaNoticesTimestamp();
      if (!mounted) return;
      setState(() {
        _lastUpdated = cachedTs;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load TU notices. Showing cached data if any.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refresh() => _refreshFromNetwork();

  List<BcaNotice> _filteredNotices() {
    if (_filter == _NoticeFilter.all) return _notices;
    return _notices.where((notice) {
      final category = _categoryFor(notice);
      switch (_filter) {
        case _NoticeFilter.exam:
          return category == _NoticeFilter.exam;
        case _NoticeFilter.form:
          return category == _NoticeFilter.form;
        case _NoticeFilter.result:
          return category == _NoticeFilter.result;
        case _NoticeFilter.admission:
          return category == _NoticeFilter.admission;
        case _NoticeFilter.general:
          return category == _NoticeFilter.general;
        case _NoticeFilter.all:
          return true;
      }
    }).toList();
  }

  _NoticeFilter _categoryFor(BcaNotice notice) {
    final text = notice.title.toLowerCase();
    if (text.contains('result') || text.contains('retotal')) {
      return _NoticeFilter.result;
    }
    if (text.contains('form') || text.contains('fill-up')) {
      return _NoticeFilter.form;
    }
    if (text.contains('admission') || text.contains('entrance')) {
      return _NoticeFilter.admission;
    }
    if (text.contains('exam') ||
        text.contains('examination') ||
        text.contains('center') ||
        text.contains('schedule')) {
      return _NoticeFilter.exam;
    }
    return _NoticeFilter.general;
  }

  void _openUrl(String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: title,
          url: url,
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date not listed';
    return date.toIso8601String().split('T').first;
  }

  String _formatLastUpdated(DateTime? date) {
    if (date == null) return 'Not cached yet';
    final parts = date.toLocal().toIso8601String().split('T');
    final time = parts.length > 1 ? parts[1].substring(0, 5) : '';
    return '${parts.first} $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'BCA Notices',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF38BDF8),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _NoticeBackdrop()),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF38BDF8),
              ),
            )
          else
            RefreshIndicator(
              color: const Color(0xFF38BDF8),
              backgroundColor: const Color(0xFF0B1220),
              onRefresh: _refresh,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                  20,
                  28,
                ),
                itemCount: _filteredNotices().length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GameCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Official TU BCA notices (FoHSS)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Last updated: ${_formatLastUpdated(_lastUpdated)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFFF59E0B),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _NoticeFilter.values.map((filter) {
                            final label = switch (filter) {
                              _NoticeFilter.all => 'All',
                              _NoticeFilter.exam => 'Exam',
                              _NoticeFilter.form => 'Form',
                              _NoticeFilter.result => 'Result',
                              _NoticeFilter.admission => 'Admission',
                              _NoticeFilter.general => 'General',
                            };
                            final selected = _filter == filter;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() => _filter = filter);
                              },
                              selectedColor: const Color(0xFF38BDF8),
                              backgroundColor: const Color(0xFF111B2E),
                              side: const BorderSide(
                                color: Color(0xFF1E2A44),
                              ),
                              labelStyle: TextStyle(
                                color:
                                    selected ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }

                  final notice = _filteredNotices()[index - 1];
                  return _GameCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notice.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _DateChip(label: _formatDate(notice.publishedAt)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.public,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'fohss.tu.edu.np',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: Colors.white60),
                            ),
                            const Spacer(),
                            if (notice.attachmentUrl != null)
                              _AttachmentChip(label: 'Attachment'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () =>
                                  _openUrl('BCA Notice', notice.url),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF38BDF8),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Open Notice'),
                            ),
                            if (notice.attachmentUrl != null)
                              OutlinedButton(
                                onPressed: () => _openUrl(
                                  'BCA Notice File',
                                  notice.attachmentUrl!,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                                child: const Text('Open Attachment'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final String label;

  const _AttachmentChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF5C421A)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.attach_file_rounded,
            size: 14,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBackdrop extends StatelessWidget {
  const _NoticeBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _NoticeGridPainter())),
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

class _NoticeGridPainter extends CustomPainter {
  const _NoticeGridPainter();

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
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
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
  bool shouldRepaint(covariant _NoticeGridPainter oldDelegate) => false;
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
