import 'package:flutter/material.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';

class AdminSyllabusScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  final bool showBreadcrumb;

  const AdminSyllabusScreen({
    super.key,
    this.onLogout,
    this.showBreadcrumb = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdminScreen(
      title: 'Syllabus Admin',
      showTabs: false,
      initialTabIndex: 0,
      breadcrumbLabel: showBreadcrumb ? 'Syllabus' : null,
      onLogout: onLogout,
    );
  }
}
