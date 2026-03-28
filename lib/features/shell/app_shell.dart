import 'package:flutter/material.dart';
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) {
          setState(() => _currentIndex = value);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.sports_esports), label: 'Play'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
