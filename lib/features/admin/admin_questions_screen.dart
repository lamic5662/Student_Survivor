import 'package:flutter/material.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';

class AdminQuestionsScreen extends StatelessWidget {
  final VoidCallback? onLogout;
  final bool showBreadcrumb;

  const AdminQuestionsScreen({
    super.key,
    this.onLogout,
    this.showBreadcrumb = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdminScreen(
      title: 'Questions Admin',
      showTabs: false,
      initialTabIndex: 2,
      breadcrumbLabel: showBreadcrumb ? 'Questions & Quizzes' : null,
      onLogout: onLogout,
    );
  }
}
