import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/ai/ai_screen.dart';
import 'package:student_survivor/features/dashboard/dashboard_screen.dart';
import 'package:student_survivor/features/profile/profile_screen.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/quiz/quiz_hub_screen.dart';
import 'package:student_survivor/features/subjects/subjects_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _profilePrompted = false;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SubjectsScreen(),
    QuizHubScreen(),
    AiAssistantScreen(),
    ProfileScreen(),
  ];

  Widget _buildNavBar(BuildContext context) {
    const accent = Color(0xFF38BDF8);
    final l10n = context.l10n;
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
                    Color(0xFF38BDF8),
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
              selectedIndex: _currentIndex,
              onDestinationSelected: (value) {
                if (value == 2) {
                  AppState.notifyGameHub();
                }
                setState(() => _currentIndex = value);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home),
                  label: l10n.home,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book),
                  label: l10n.subjects,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.sports_esports),
                  label: l10n.play,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome),
                  label: l10n.ai,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person),
                  label: l10n.profile,
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
    if (!_profilePrompted) {
      _profilePrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (AppState.profile.value.semester.id.isEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
          );
        }
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNavBar(context),
    );
  }
}
