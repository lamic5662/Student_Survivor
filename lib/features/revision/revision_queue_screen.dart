import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/revision_queue_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/revision/quick_revision_quiz_screen.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_study_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class RevisionQueueScreen extends StatefulWidget {
  const RevisionQueueScreen({super.key});

  @override
  State<RevisionQueueScreen> createState() => _RevisionQueueScreenState();
}

class _RevisionQueueScreenState extends State<RevisionQueueScreen> {
  late final RevisionQueueService _service;
  late final ActivityLogService _activityLog;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  bool _loading = true;
  String? _errorMessage;
  List<RevisionItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = RevisionQueueService(SupabaseConfig.client);
    _activityLog = ActivityLogService(SupabaseConfig.client);
    _scrollController.addListener(_handleScroll);
    _load();
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final items = await _service.fetchQueue(
        subjects: AppState.profile.value.subjects,
        limit: 12,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to load revision queue: $error',
          'पुनरावलोकन लोड गर्न असफल: $error',
        );
        _loading = false;
      });
    }
  }

  void _markDone(RevisionItem item) {
    _activityLog.logActivityUnawaited(
      type: 'revision_complete',
      source: 'revision_queue',
      subjectId: item.subject?.id,
      chapterId: item.chapter?.id,
      metadata: {
        'title': item.title,
        'detail': item.detail,
        'type': item.type.name,
        'priority': item.priority.name,
      },
    );
    _service.markReviewed(item: item, success: true);
    _load();
  }

  void _openItem(RevisionItem item) {
    if (item.chapter != null && item.subject != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChapterDetailScreen(
            subject: item.subject!,
            chapter: item.chapter!,
            useGameZoneTheme: true,
          ),
        ),
      );
      return;
    }
    if (item.subject != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubjectStudyScreen(
            subject: item.subject!,
            useGameZoneTheme: true,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Open the subject list to review this item.',
            'यो सामग्री हेर्न विषय सूची खोल्नुहोस्।',
          ),
        ),
      ),
    );
  }

  Future<void> _startQuickRevision() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'No revision items yet.',
              'अहिले पुनरावलोकन सामग्री छैन।',
            ),
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickRevisionQuizScreen(items: _items),
      ),
    );
    if (mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameZoneScaffold(
      extendBodyBehindAppBar: true,
      useSafeArea: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            l10n.revisionQueue,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4FA3C7)),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          12,
                      20,
                      24,
                    ),
                    itemCount: _items.isEmpty ? 3 : _items.length + 2,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _QueueCard(
                          child: _QuickRevisionBanner(
                            onStart: _startQuickRevision,
                          ),
                        );
                      }
                      if (index == 1) {
                        return const SizedBox(height: 16);
                      }
                      if (_items.isEmpty) {
                        return _QueueCard(
                          child: Text(
                            context.tr(
                              'You are all caught up. Great work!',
                              'सबै पूरा भयो। राम्रो काम!',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        );
                      }
                      final item = _items[index - 2];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QueueCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _QueueIcon(type: item.type),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.detail,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _QueueTag(
                                              label: _typeLabel(context, item),
                                              accent: const Color(0xFF4F46E5),
                                            ),
                                            _QueueTag(
                                              label: _dueLabel(
                                                context,
                                                item.dueAt,
                                              ),
                                              accent: const Color(0xFF22D3EE),
                                            ),
                                            _QueueTag(
                                              label: _priorityLabel(
                                                context,
                                                item.priority,
                                              ),
                                              accent: const Color(0xFFF97316),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _openItem(item),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF4FA3C7),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: Text(l10n.reviewNow),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: () => _markDone(item),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(
                                        color: Color(0xFF1E2A44),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(l10n.markDone),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _dueLabel(BuildContext context, DateTime dueAt) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final diff = dueAt.difference(now);
    if (diff.inHours <= 0) return l10n.dueToday;
    if (diff.inDays == 0) return l10n.dueToday;
    if (diff.inDays == 1) return l10n.dueTomorrow;
    return l10n.dueInDays(diff.inDays);
  }

  String _priorityLabel(BuildContext context, RevisionPriority priority) {
    final l10n = context.l10n;
    switch (priority) {
      case RevisionPriority.high:
        return l10n.priorityHigh;
      case RevisionPriority.medium:
        return l10n.priorityMedium;
      case RevisionPriority.low:
        return l10n.priorityLow;
    }
  }

  String _typeLabel(BuildContext context, RevisionItem item) {
    switch (item.type) {
      case RevisionItemType.chapter:
        return context.tr('Chapter review', 'अध्याय पुनरावलोकन');
      case RevisionItemType.note:
        return context.tr('Notes review', 'नोट्स पुनरावलोकन');
      case RevisionItemType.question:
        return context.tr('Important question', 'महत्वपूर्ण प्रश्न');
      case RevisionItemType.topic:
        return context.tr('Weak topic', 'कमजोर विषय');
    }
  }
}

class _QueueCard extends StatelessWidget {
  final Widget child;

  const _QueueCard({required this.child});

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
            blurRadius: 24,
            offset: const Offset(0, 12),
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

class _QueueIcon extends StatelessWidget {
  final RevisionItemType type;

  const _QueueIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color accent;
    switch (type) {
      case RevisionItemType.chapter:
        icon = Icons.menu_book_rounded;
        accent = const Color(0xFF4F46E5);
        break;
      case RevisionItemType.note:
        icon = Icons.description_rounded;
        accent = const Color(0xFF22D3EE);
        break;
      case RevisionItemType.question:
        icon = Icons.quiz_rounded;
        accent = const Color(0xFF4FA3C7);
        break;
      case RevisionItemType.topic:
        icon = Icons.warning_amber_rounded;
        accent = AppColors.warning;
        break;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Icon(icon, color: accent),
    );
  }
}

class _QueueTag extends StatelessWidget {
  final String label;
  final Color accent;

  const _QueueTag({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _QuickRevisionBanner extends StatelessWidget {
  final VoidCallback onStart;

  const _QuickRevisionBanner({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2A44)),
          ),
          child: const Icon(Icons.flash_on_rounded, color: Color(0xFF4FA3C7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('Quick revision', 'छिटो पुनरावलोकन'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(
                  'Short quiz from your weak topics.',
                  'कमजोर विषयबाट छोटो क्विज।',
                ),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4FA3C7),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(context.tr('Start', 'सुरु')),
        ),
      ],
    );
  }
}
