import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/admin_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_breadcrumb.dart';
import 'package:student_survivor/features/admin/admin_management_widgets.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late final AdminService _adminService;

  List<AdminContentReport> _reports = const [];
  List<AdminNoteSubmission> _submissions = const [];
  List<AdminCommunityQuestion> _communityQuestions = const [];
  bool _isLoading = true;
  String _reportFilter = 'pending';
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(SupabaseConfig.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _adminService.fetchReports(status: _reportFilter),
        _adminService.fetchPendingNoteSubmissions(),
        _adminService.fetchPendingCommunityQuestions(),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<AdminContentReport>;
        _submissions = results[1] as List<AdminNoteSubmission>;
        _communityQuestions = results[2] as List<AdminCommunityQuestion>;
        _isLoading = false;
        _busyId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load moderation data: $error';
        _isLoading = false;
        _busyId = null;
      });
    }
  }

  Future<String?> _promptNote({
    required String title,
    required String label,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _dismissReport(AdminContentReport report) async {
    final note = await _promptNote(
      title: 'Dismiss report',
      label: 'Review note',
      initialValue: report.reviewNote,
    );
    if (note == null) return;
    await _runBusy(report.id, () async {
      await _adminService.updateReportStatus(
        reportId: report.id,
        status: 'dismissed',
        reviewNote: note,
      );
      await _load();
    }, successMessage: 'Report dismissed.');
  }

  Future<void> _resolveReport(AdminContentReport report) async {
    final confirmed = await _confirm(
      title: 'Remove reported content?',
      message:
          'This will remove the reported content when supported, then mark the report as resolved.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;

    await _runBusy(report.id, () async {
      switch (report.targetType) {
        case 'user_note':
          await _adminService.deleteUserNote(report.targetId);
          break;
        case 'note':
          await _adminService.deleteNote(report.targetId);
          break;
        case 'question':
          await _adminService.deleteQuestion(report.targetId);
          break;
        case 'community_question':
          await _adminService.deleteCommunityQuestion(report.targetId);
          break;
        case 'community_answer':
          await _adminService.deleteCommunityAnswer(report.targetId);
          break;
        case 'chat_message':
          await _adminService.deleteChatMessage(report.targetId);
          break;
        case 'note_submission':
          await _adminService.deleteNoteSubmission(report.targetId);
          break;
        default:
          throw Exception(
            'Unsupported target type "${report.targetType}" for auto-removal.',
          );
      }
      await _adminService.updateReportStatus(
        reportId: report.id,
        status: 'resolved',
        reviewNote: 'Content removed by admin.',
      );
      await _load();
    }, successMessage: 'Reported content removed.');
  }

  Future<void> _approveSubmission(AdminNoteSubmission submission) async {
    await _runBusy(submission.id, () async {
      await _adminService.approveNoteSubmission(submission);
      await _load();
    }, successMessage: 'Submission approved.');
  }

  Future<void> _rejectSubmission(AdminNoteSubmission submission) async {
    final feedback = await _promptNote(
      title: 'Reject note submission',
      label: 'Feedback',
    );
    if (feedback == null) return;
    await _runBusy(submission.id, () async {
      await _adminService.rejectNoteSubmission(
        submission,
        feedback: feedback,
      );
      await _load();
    }, successMessage: 'Submission rejected.');
  }

  Future<void> _deleteSubmission(AdminNoteSubmission submission) async {
    final confirmed = await _confirm(
      title: 'Delete submission?',
      message: 'Delete "${submission.title}" from the pending queue?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await _runBusy(submission.id, () async {
      await _adminService.deleteNoteSubmission(submission.id);
      await _load();
    }, successMessage: 'Submission deleted.');
  }

  Future<void> _approveCommunityQuestion(AdminCommunityQuestion question) async {
    await _runBusy(question.id, () async {
      await _adminService.approveCommunityQuestion(question);
      await _load();
    }, successMessage: 'Community question approved.');
  }

  Future<void> _rejectCommunityQuestion(AdminCommunityQuestion question) async {
    final reason = await _promptNote(
      title: 'Reject community question',
      label: 'Reason',
    );
    if (reason == null) return;
    await _runBusy(question.id, () async {
      await _adminService.rejectCommunityQuestion(
        question,
        adminReason: reason,
      );
      await _load();
    }, successMessage: 'Community question rejected.');
  }

  Future<void> _deleteCommunityQuestion(AdminCommunityQuestion question) async {
    final confirmed = await _confirm(
      title: 'Delete community question?',
      message: 'Delete this question permanently?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    await _runBusy(question.id, () async {
      await _adminService.deleteCommunityQuestion(question.id);
      await _load();
    }, successMessage: 'Community question deleted.');
  }

  Future<void> _runBusy(
    String id,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
      setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameZoneScaffold(
      appBar: AppBar(
        title: const Text('Reports & Moderation'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
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
          const AdminBreadcrumb(label: 'Reports & Moderation'),
          const SizedBox(height: 12),
          AdminPanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionHeader(
                  title: 'Reports & Inappropriate Content',
                  subtitle:
                      'Handle reported content, moderate student note submissions, and review community posts.',
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    AdminInlineBadge(
                      label: '${_reports.length} reports',
                      color: AppColors.warning,
                      icon: Icons.flag_outlined,
                    ),
                    AdminInlineBadge(
                      label: '${_submissions.length} pending notes',
                      color: AppColors.secondary,
                      icon: Icons.note_alt_outlined,
                    ),
                    AdminInlineBadge(
                      label:
                          '${_communityQuestions.length} pending community posts',
                      color: AppColors.accent,
                      icon: Icons.forum_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('pending', 'Pending'),
                    _buildFilterChip('resolved', 'Resolved'),
                    _buildFilterChip('dismissed', 'Dismissed'),
                    _buildFilterChip('all', 'All'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            AdminEmptyCard(
              title: 'Unable to load moderation data',
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
          else ...[
            _buildReportsSection(),
            const SizedBox(height: 16),
            _buildNoteSubmissionSection(),
            const SizedBox(height: 16),
            _buildCommunitySection(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _reportFilter == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) {
        if (_reportFilter == value) return;
        setState(() => _reportFilter = value);
        _load();
      },
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: const Color(0xFF08101D),
      selectedColor: AppColors.warning.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? AppColors.warning : const Color(0xFF1E2A44),
      ),
    );
  }

  Widget _buildReportsSection() {
    if (_reports.isEmpty) {
      return const AdminEmptyCard(
        title: 'No reports',
        message:
            'When students report inappropriate notes, questions, answers, or chat messages, they will appear here.',
        icon: Icons.flag_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reported content',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ..._reports.map((report) {
          final busy = _busyId == report.id;
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
                              report.targetTitle.isEmpty
                                  ? 'Untitled content'
                                  : report.targetTitle,
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
                              'Reported by ${report.reporterName}',
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
                      AdminInlineBadge(
                        label: formatAdminLabel(report.status),
                        color: report.status == 'resolved'
                            ? AppColors.success
                            : report.status == 'dismissed'
                                ? Colors.white70
                                : AppColors.warning,
                        icon: Icons.report_outlined,
                      ),
                      AdminInlineBadge(
                        label: formatAdminLabel(report.targetType),
                        color: AppColors.secondary,
                        icon: Icons.category_outlined,
                      ),
                      if (report.reason.isNotEmpty)
                        AdminInlineBadge(
                          label: report.reason,
                          color: AppColors.accent,
                          icon: Icons.help_outline,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (report.targetPreview.isNotEmpty)
                    Text(
                      report.targetPreview,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  if (report.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Details: ${report.details}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    formatAdminTimestamp(report.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                  if (report.status == 'pending') ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : () => _dismissReport(report),
                          icon: const Icon(Icons.remove_done_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Color(0xFF50607A)),
                          ),
                          label: const Text('Dismiss'),
                        ),
                        FilledButton.icon(
                          onPressed: busy ? null : () => _resolveReport(report),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.warning,
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Remove Content'),
                        ),
                      ],
                    ),
                  ] else if (report.reviewNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Review note: ${report.reviewNote}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNoteSubmissionSection() {
    if (_submissions.isEmpty) {
      return const AdminEmptyCard(
        title: 'No pending student notes',
        message: 'Submitted notes waiting for approval will appear here.',
        icon: Icons.note_alt_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending student notes',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ..._submissions.map((submission) {
          final busy = _busyId == submission.id;
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
                        child: Text(
                          submission.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((submission.userName ?? '').isNotEmpty)
                        AdminInlineBadge(
                          label: submission.userName!,
                          color: AppColors.secondary,
                          icon: Icons.person_outline,
                        ),
                      AdminInlineBadge(
                        label: submission.chapterTitle,
                        color: AppColors.accent,
                        icon: Icons.layers_outlined,
                      ),
                      if ((submission.subjectName ?? '').isNotEmpty)
                        AdminInlineBadge(
                          label: submission.subjectName!,
                          color: Colors.white70,
                          icon: Icons.menu_book_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    submission.shortAnswer.isNotEmpty
                        ? submission.shortAnswer
                        : submission.detailedAnswer,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _approveSubmission(submission),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _rejectSubmission(submission),
                        icon: const Icon(Icons.close_outlined),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                        ),
                        label: const Text('Reject'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _deleteSubmission(submission),
                        icon: const Icon(Icons.delete_outline),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF50607A)),
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
      ],
    );
  }

  Widget _buildCommunitySection() {
    if (_communityQuestions.isEmpty) {
      return const AdminEmptyCard(
        title: 'No pending community questions',
        message: 'Student questions waiting for moderation will appear here.',
        icon: Icons.forum_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending community questions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ..._communityQuestions.map((question) {
          final busy = _busyId == question.id;
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
                        child: Text(
                          question.question,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
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
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AdminInlineBadge(
                        label: question.subjectName,
                        color: AppColors.secondary,
                        icon: Icons.menu_book_outlined,
                      ),
                      AdminInlineBadge(
                        label: formatAdminLabel(question.status),
                        color: AppColors.warning,
                        icon: Icons.pending_outlined,
                      ),
                    ],
                  ),
                  if ((question.aiReason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'AI reason: ${question.aiReason}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => _approveCommunityQuestion(question),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _rejectCommunityQuestion(question),
                        icon: const Icon(Icons.close_outlined),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                        ),
                        label: const Text('Reject'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _deleteCommunityQuestion(question),
                        icon: const Icon(Icons.delete_outline),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF50607A)),
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
      ],
    );
  }
}
