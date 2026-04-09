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

  Widget _buildNavBar() {
    const accent = Color(0xFF4FA3C7);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        border: const Border(top: BorderSide(color: Color(0xFF1E2A44))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x0022D3EE),
                    Color(0xFF4FA3C7),
                    Color(0x004F46E5),
                  ],
                ),
              ),
            ),
          ),
          NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: const Color(0xFF1E2A44),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? Colors.white
                      : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? accent
                      : Colors.white70,
                ),
              ),
            ),
            child: NavigationBar(
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
          ),
        ],
      ),
    );
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
      bottomNavigationBar: _buildNavBar(),
    );
  }
}
