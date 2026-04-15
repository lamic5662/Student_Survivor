import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/admin_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_breadcrumb.dart';
import 'package:student_survivor/features/admin/admin_management_widgets.dart';

class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  static const int _studentPageSize = 15;
  static const int _adminPageSize = 15;

  late final AdminService _adminService;
  final TextEditingController _searchController = TextEditingController();

  List<AdminActivityEntry> _studentActivities = const [];
  List<AdminAuditEntry> _adminActivities = const [];
  bool _isLoading = true;
  int _studentPage = 1;
  int _adminPage = 1;
  int _studentTotalCount = 0;
  int _adminTotalCount = 0;
  String _mode = 'student';
  String _studentFilter = 'all';
  String _adminFilter = 'all';
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(SupabaseConfig.client);
    _refreshAll();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminService.fetchRecentActivities(
          limit: _studentPageSize,
          offset: 0,
          search: _searchController.text,
          activityType:
              _studentFilter == 'all' ? null : _studentFilter,
        ),
        _adminService.fetchAdminAuditEntries(
          limit: _adminPageSize,
          offset: 0,
          search: _searchController.text,
          actionType: _adminFilter == 'all' ? null : _adminFilter,
        ),
        _adminService.fetchRecentActivityCount(
          search: _searchController.text,
          activityType:
              _studentFilter == 'all' ? null : _studentFilter,
        ),
        _adminService.fetchAdminAuditCount(
          search: _searchController.text,
          actionType: _adminFilter == 'all' ? null : _adminFilter,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _studentActivities = results[0] as List<AdminActivityEntry>;
        _adminActivities = results[1] as List<AdminAuditEntry>;
        _studentTotalCount = results[2] as int;
        _adminTotalCount = results[3] as int;
        _studentPage = 1;
        _adminPage = 1;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load activity: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentActivities({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminService.fetchRecentActivities(
          limit: _studentPageSize,
          offset: (page - 1) * _studentPageSize,
          search: _searchController.text,
          activityType:
              _studentFilter == 'all' ? null : _studentFilter,
        ),
        _adminService.fetchRecentActivityCount(
          search: _searchController.text,
          activityType:
              _studentFilter == 'all' ? null : _studentFilter,
        ),
      ]);
      final items = results[0] as List<AdminActivityEntry>;
      final total = results[1] as int;
      if (items.isEmpty && total > 0 && page > 1) {
        return _loadStudentActivities(page: page - 1);
      }
      if (!mounted) return;
      setState(() {
        _studentActivities = items;
        _studentPage = page;
        _studentTotalCount = total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load student activity: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAdminActivities({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminService.fetchAdminAuditEntries(
          limit: _adminPageSize,
          offset: (page - 1) * _adminPageSize,
          search: _searchController.text,
          actionType: _adminFilter == 'all' ? null : _adminFilter,
        ),
        _adminService.fetchAdminAuditCount(
          search: _searchController.text,
          actionType: _adminFilter == 'all' ? null : _adminFilter,
        ),
      ]);
      final items = results[0] as List<AdminAuditEntry>;
      final total = results[1] as int;
      if (items.isEmpty && total > 0 && page > 1) {
        return _loadAdminActivities(page: page - 1);
      }
      if (!mounted) return;
      setState(() {
        _adminActivities = items;
        _adminPage = page;
        _adminTotalCount = total;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load admin activity: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingStudent = _mode == 'student';
    final items = showingStudent ? _studentActivities : _adminActivities;
    final loadedCount =
        showingStudent ? _studentActivities.length : _adminActivities.length;
    final filterValue = showingStudent ? _studentFilter : _adminFilter;
    final currentPage = showingStudent ? _studentPage : _adminPage;
    final totalCount =
        showingStudent ? _studentTotalCount : _adminTotalCount;
    final pageSize = showingStudent ? _studentPageSize : _adminPageSize;
    final totalPages = totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
    final startItem =
        totalCount == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;
    final endItem =
        totalCount == 0 ? 0 : (((currentPage - 1) * pageSize) + loadedCount).clamp(0, totalCount);

    return GameZoneScaffold(
      appBar: AppBar(
        title: const Text('Admin Activity'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const AdminBreadcrumb(label: 'Activity'),
          const SizedBox(height: 12),
          AdminPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionHeader(
                  title: 'Activity Monitor',
                  subtitle:
                      'Review recent student behavior and admin moderation history from one place.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminInlineBadge(
                      label: 'Student: $_studentTotalCount total',
                      color: AppColors.secondary,
                      icon: Icons.bolt_outlined,
                    ),
                    AdminInlineBadge(
                      label: 'Admin: $_adminTotalCount total',
                      color: AppColors.warning,
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'student',
                      icon: Icon(Icons.school_outlined),
                      label: Text('Students'),
                    ),
                    ButtonSegment<String>(
                      value: 'admin',
                      icon: Icon(Icons.manage_accounts_outlined),
                      label: Text('Admins'),
                    ),
                  ],
                  selected: {_mode},
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.white70;
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.selected)
                          ? AppColors.secondary.withValues(alpha: 0.22)
                          : const Color(0xFF08101D);
                    }),
                    side: WidgetStatePropertyAll(
                      const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                  ),
                  onSelectionChanged: (selection) {
                    final next = selection.first;
                    setState(() => _mode = next);
                    if (next == 'student' && _studentActivities.isEmpty) {
                      _loadStudentActivities(page: 1);
                    }
                    if (next == 'admin' && _adminActivities.isEmpty) {
                      _loadAdminActivities(page: 1);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: showingStudent
                        ? 'Search user, subject, chapter, activity'
                        : 'Search admin, target, action',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF08101D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: showingStudent
                      ? _studentFilterOptions.map(
                          (filter) => ChoiceChip(
                            selected: _studentFilter == filter,
                            label: Text(filter == 'all'
                                ? 'All'
                                : formatAdminLabel(filter)),
                            onSelected: (_) {
                              setState(() => _studentFilter = filter);
                              _loadStudentActivities(page: 1);
                            },
                            labelStyle: TextStyle(
                              color: _studentFilter == filter
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: const Color(0xFF08101D),
                            selectedColor:
                                AppColors.secondary.withValues(alpha: 0.22),
                            side: BorderSide(
                              color: _studentFilter == filter
                                  ? AppColors.secondary
                                  : const Color(0xFF1E2A44),
                            ),
                          ),
                        ).toList()
                      : _adminFilterOptions.map(
                          (filter) => ChoiceChip(
                            selected: _adminFilter == filter,
                            label: Text(filter == 'all'
                                ? 'All'
                                : formatAdminLabel(filter)),
                            onSelected: (_) {
                              setState(() => _adminFilter = filter);
                              _loadAdminActivities(page: 1);
                            },
                            labelStyle: TextStyle(
                              color: _adminFilter == filter
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                            backgroundColor: const Color(0xFF08101D),
                            selectedColor:
                                AppColors.warning.withValues(alpha: 0.22),
                            side: BorderSide(
                              color: _adminFilter == filter
                                  ? AppColors.warning
                                  : const Color(0xFF1E2A44),
                            ),
                          ),
                        ).toList(),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminInlineBadge(
                      label: '${items.length} visible',
                      color: AppColors.accent,
                      icon: Icons.filter_alt_outlined,
                    ),
                    AdminInlineBadge(
                      label: '$startItem-$endItem of $totalCount',
                      color: Colors.white70,
                      icon: Icons.format_list_numbered_outlined,
                    ),
                    if (filterValue != 'all')
                      AdminInlineBadge(
                        label: formatAdminLabel(filterValue),
                        color: showingStudent
                            ? AppColors.secondary
                            : AppColors.warning,
                        icon: Icons.tune_outlined,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            AdminEmptyCard(
              title: 'Unable to load activity',
              message: _error!,
              icon: Icons.error_outline,
            )
          else if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (items.isEmpty)
            AdminEmptyCard(
              title: showingStudent
                  ? 'No student activity'
                  : 'No admin actions yet',
              message: showingStudent
                  ? 'Student events will appear here after quizzes, notes, focus sessions, and other tracked actions.'
                  : 'Admin moderation, user management, and content actions will appear here.',
              icon: showingStudent
                  ? Icons.history_toggle_off_outlined
                  : Icons.admin_panel_settings_outlined,
            )
          else if (showingStudent)
            ..._studentActivities.map(_buildStudentActivityCard)
          else
            ..._adminActivities.map(_buildAdminAuditCard),
          if (!_isLoading && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: currentPage > 1
                        ? () => showingStudent
                            ? _loadStudentActivities(page: currentPage - 1)
                            : _loadAdminActivities(page: currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                    label: const Text('Previous'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Page $currentPage / $totalPages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: currentPage < totalPages
                        ? () => showingStudent
                            ? _loadStudentActivities(page: currentPage + 1)
                            : _loadAdminActivities(page: currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    iconAlignment: IconAlignment.end,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentActivityCard(AdminActivityEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminPanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.bolt_outlined,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAdminLabel(entry.activityType),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.userName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAdminTimestamp(entry.createdAt),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.source.isNotEmpty)
                  AdminInlineBadge(
                    label: formatAdminLabel(entry.source),
                    color: AppColors.accent,
                    icon: Icons.route_outlined,
                  ),
                if (entry.points != 0)
                  AdminInlineBadge(
                    label: '${entry.points} pts',
                    color: AppColors.success,
                    icon: Icons.stars_outlined,
                  ),
                if (entry.subjectName.isNotEmpty)
                  AdminInlineBadge(
                    label: entry.subjectName,
                    color: AppColors.secondary,
                    icon: Icons.menu_book_outlined,
                  ),
                if (entry.chapterTitle.isNotEmpty)
                  AdminInlineBadge(
                    label: entry.chapterTitle,
                    color: Colors.white70,
                    icon: Icons.layers_outlined,
                  ),
              ],
            ),
            if (entry.userEmail.isNotEmpty || entry.metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (entry.userEmail.isNotEmpty)
                Text(
                  entry.userEmail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                ),
              if (entry.metadata.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.metadata.entries
                      .map((item) => '${formatAdminLabel(item.key)}: ${item.value}')
                      .join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAuditCard(AdminAuditEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminPanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatAdminLabel(entry.actionType),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.actorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatAdminTimestamp(entry.createdAt),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entry.targetType.isNotEmpty)
                  AdminInlineBadge(
                    label: formatAdminLabel(entry.targetType),
                    color: AppColors.warning,
                    icon: Icons.flag_outlined,
                  ),
                if (entry.targetId.isNotEmpty)
                  AdminInlineBadge(
                    label: entry.targetId,
                    color: Colors.white70,
                    icon: Icons.fingerprint,
                  ),
              ],
            ),
            if (entry.actorEmail.isNotEmpty || entry.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (entry.actorEmail.isNotEmpty)
                Text(
                  entry.actorEmail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white60,
                      ),
                ),
              if (entry.details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  entry.details.entries
                      .map((item) => '${formatAdminLabel(item.key)}: ${item.value}')
                      .join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<String> get _studentFilterOptions {
    final values = _studentActivities
        .map((entry) => entry.activityType)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['all', ...values];
  }

  List<String> get _adminFilterOptions {
    final values = _adminActivities
        .map((entry) => entry.actionType)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['all', ...values];
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _mode == 'student'
          ? _loadStudentActivities(page: 1)
          : _loadAdminActivities(page: 1),
    );
  }
}
