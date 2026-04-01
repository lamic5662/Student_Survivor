import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCached();
    _refreshFromNetwork(showSpinner: false);
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
      appBar: AppBar(
        title: const Text('BCA Notices'),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _filteredNotices().length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Official TU BCA notices (FoHSS)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Last updated: ${_formatLastUpdated(_lastUpdated)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.mutedInk),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.warning),
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
                            return ChoiceChip(
                              label: Text(label),
                              selected: _filter == filter,
                              onSelected: (_) {
                                setState(() => _filter = filter);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  }

                  final notice = _filteredNotices()[index - 1];
                  return AppCard(
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
                                    ?.copyWith(fontWeight: FontWeight.w600),
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
                              color: AppColors.mutedInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'fohss.tu.edu.np',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.mutedInk),
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
                            FilledButton.tonal(
                              onPressed: () =>
                                  _openUrl('BCA Notice', notice.url),
                              child: const Text('Open Notice'),
                            ),
                            if (notice.attachmentUrl != null)
                              OutlinedButton(
                                onPressed: () => _openUrl(
                                  'BCA Notice File',
                                  notice.attachmentUrl!,
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
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.secondary,
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
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.attach_file_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
