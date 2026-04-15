import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/admin_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_breadcrumb.dart';
import 'package:student_survivor/features/admin/admin_management_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const int _pageSize = 15;

  late final AdminService _adminService;
  final TextEditingController _searchController = TextEditingController();

  List<AdminManagedUser> _users = const [];
  bool _isLoading = true;
  bool _blockedOnly = false;
  int _currentPage = 1;
  int _totalUsers = 0;
  String? _busyUserId;
  String? _error;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(SupabaseConfig.client);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminService.fetchUsers(
          query: _searchController.text,
          blockedOnly: _blockedOnly,
          limit: _pageSize,
          offset: (page - 1) * _pageSize,
        ),
        _adminService.fetchFilteredUserCount(
          query: _searchController.text,
          blockedOnly: _blockedOnly,
        ),
      ]);
      final users = results[0] as List<AdminManagedUser>;
      final total = results[1] as int;
      if (users.isEmpty && total > 0 && page > 1) {
        return _loadUsers(page: page - 1);
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _currentPage = page;
        _totalUsers = total;
        _busyUserId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load users: $error';
        _isLoading = false;
        _busyUserId = null;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadUsers(page: 1),
    );
  }

  Future<String?> _promptBlockReason(AdminManagedUser user) async {
    var reason = user.blockedReason;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block ${user.name}?'),
        content: TextFormField(
          initialValue: reason,
          minLines: 2,
          maxLines: 4,
          onChanged: (value) => reason = value,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Optional reason shown to the user',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reason.trim()),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<bool> _confirmDelete(AdminManagedUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${user.name}?'),
        content: const Text(
          'This removes the account from auth and deletes linked profile data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _setBlocked(AdminManagedUser user, bool blocked) async {
    if (_busyUserId == user.id) return;
    String? reason;
    if (blocked) {
      reason = await _promptBlockReason(user);
      if (reason == null) return;
    }
    setState(() => _busyUserId = user.id);
    try {
      await _adminService.setUserBlocked(
        userId: user.id,
        blocked: blocked,
        reason: reason,
      );
      await _loadUsers(page: _currentPage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(blocked ? 'User blocked.' : 'User unblocked.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
      setState(() => _busyUserId = null);
    }
  }

  Future<void> _deleteUser(AdminManagedUser user) async {
    if (_busyUserId == user.id) return;
    final confirmed = await _confirmDelete(user);
    if (!confirmed) return;
    setState(() => _busyUserId = user.id);
    try {
      await _adminService.deleteUser(user.id);
      await _loadUsers(page: _currentPage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $error')),
      );
      setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedCount = _users.where((user) => user.isBlocked).length;
    final totalPages = _totalUsers == 0 ? 1 : (_totalUsers / _pageSize).ceil();
    final startItem = _totalUsers == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final endItem = _totalUsers == 0
        ? 0
        : ((_currentPage - 1) * _pageSize + _users.length).clamp(0, _totalUsers);

    return GameZoneScaffold(
      appBar: AppBar(
        title: const Text('Admin Users'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadUsers(page: _currentPage),
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
          const AdminBreadcrumb(label: 'Users'),
          const SizedBox(height: 12),
          AdminPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionHeader(
                  title: 'User Management',
                  subtitle:
                      'View accounts, block access, and delete inappropriate or duplicate users.',
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final filter = FilterChip(
                      selected: _blockedOnly,
                      onSelected: (value) {
                        setState(() => _blockedOnly = value);
                        _loadUsers(page: 1);
                      },
                      label: const Text('Blocked only'),
                      backgroundColor: const Color(0xFF08101D),
                      selectedColor: AppColors.warning.withValues(alpha: 0.18),
                      checkmarkColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: _blockedOnly ? AppColors.warning : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _blockedOnly
                            ? AppColors.warning
                            : const Color(0xFF1E2A44),
                      ),
                    );
                    final field = TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, college, semester',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF08101D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E2A44),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF1E2A44),
                          ),
                        ),
                      ),
                    );
                    if (constraints.maxWidth < 560) {
                      return Column(
                        children: [
                          field,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: filter,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 12),
                        filter,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminInlineBadge(
                      label: 'Page $_currentPage of $totalPages',
                      color: AppColors.secondary,
                      icon: Icons.pages_outlined,
                    ),
                    AdminInlineBadge(
                      label: '$blockedCount blocked on page',
                      color: AppColors.warning,
                      icon: Icons.block_outlined,
                    ),
                    AdminInlineBadge(
                      label: '$startItem-$endItem of $_totalUsers users',
                      color: AppColors.accent,
                      icon: Icons.format_list_numbered_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            AdminEmptyCard(
              title: 'Unable to load users',
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
          else if (_users.isEmpty)
            const AdminEmptyCard(
              title: 'No users found',
              message:
                  'Try a different search or turn off the blocked filter.',
              icon: Icons.people_outline,
            )
          else
            ..._users.map((user) {
              final busy = _busyUserId == user.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AdminPanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email.isEmpty
                                      ? 'No email'
                                      : user.email,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          if (busy)
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (user.isAdmin)
                            const AdminInlineBadge(
                              label: 'Admin',
                              color: AppColors.secondary,
                              icon: Icons.verified_user_outlined,
                            ),
                          if (user.isBlocked)
                            const AdminInlineBadge(
                              label: 'Blocked',
                              color: AppColors.warning,
                              icon: Icons.block_outlined,
                            ),
                          if (user.semesterName.isNotEmpty)
                            AdminInlineBadge(
                              label: user.semesterName,
                              color: AppColors.accent,
                              icon: Icons.school_outlined,
                            ),
                          if (user.collegeName.isNotEmpty)
                            AdminInlineBadge(
                              label: user.collegeName,
                              color: Colors.white70,
                              icon: Icons.location_city_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (user.phone.isNotEmpty)
                        _InfoLine(
                          label: 'Phone',
                          value: user.phone,
                        ),
                      if (user.isBlocked && user.blockedReason.isNotEmpty)
                        _InfoLine(
                          label: 'Block reason',
                          value: user.blockedReason,
                        ),
                      if (user.blockedAt != null)
                        _InfoLine(
                          label: 'Blocked at',
                          value: formatAdminTimestamp(user.blockedAt),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _setBlocked(user, !user.isBlocked),
                            icon: Icon(
                              user.isBlocked
                                  ? Icons.lock_open_outlined
                                  : Icons.block_outlined,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: user.isBlocked
                                  ? AppColors.success
                                  : AppColors.warning,
                              side: BorderSide(
                                color: user.isBlocked
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            label: Text(
                              user.isBlocked ? 'Unblock' : 'Block',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => _deleteUser(user),
                            icon: const Icon(Icons.delete_outline),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.warning,
                              side: const BorderSide(color: AppColors.warning),
                            ),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (!_isLoading && _users.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentPage > 1
                        ? () => _loadUsers(page: _currentPage - 1)
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
                    'Page $_currentPage / $totalPages',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _currentPage < totalPages
                        ? () => _loadUsers(page: _currentPage + 1)
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
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
