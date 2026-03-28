import 'package:flutter/material.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';

class AdminNotesScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  final bool showBreadcrumb;

  const AdminNotesScreen({
    super.key,
    this.onLogout,
    this.showBreadcrumb = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdminScreen(
      title: 'Notes Admin',
      showTabs: false,
      initialTabIndex: 1,
      breadcrumbLabel: showBreadcrumb ? 'Notes' : null,
      onLogout: onLogout,
    );
  }
}
