import 'package:flutter/material.dart';
import 'package:student_survivor/features/admin/admin_dashboard_screen.dart';
import 'package:student_survivor/features/admin/admin_notes_screen.dart';
import 'package:student_survivor/features/admin/admin_questions_screen.dart';
import 'package:student_survivor/features/admin/admin_syllabus_screen.dart';

class AdminShell extends StatefulWidget {
  final VoidCallback? onLogout;

  const AdminShell({super.key, this.onLogout});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _setIndex(int value) {
    if (_index == value) return;
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      AdminDashboardScreen(
        onLogout: widget.onLogout,
        onNavigate: _setIndex,
      ),
      AdminSyllabusScreen(
        onLogout: widget.onLogout,
        showBreadcrumb: false,
      ),
      AdminNotesScreen(
        onLogout: widget.onLogout,
        showBreadcrumb: false,
      ),
      AdminQuestionsScreen(
        onLogout: widget.onLogout,
        showBreadcrumb: false,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _setIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Syllabus',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz),
            label: 'Questions',
          ),
        ],
      ),
    );
  }
}
