import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/ai/ai_screen.dart';
import 'package:student_survivor/features/dashboard/dashboard_screen.dart';
import 'package:student_survivor/features/profile/profile_screen.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/quiz/quiz_hub_screen.dart';
import 'package:student_survivor/features/subjects/subjects_screen.dart';
import 'package:student_survivor/features/teacher/ai_teacher_screen.dart';
import 'package:student_survivor/core/widgets/focus_overlay_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _aiDisclaimerKey = 'ai_disclaimer_pending';
  int _currentIndex = 0;
  bool _profilePrompted = false;
  bool _aiDisclaimerShown = false;
  OverlayEntry? _focusOverlayEntry;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SubjectsScreen(),
    QuizHubScreen(),
    AiAssistantScreen(),
    AiTeacherScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AppState.focusLock.addListener(_syncFocusOverlay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFocusOverlay();
      _showAiDisclaimer();
    });
  }

  @override
  void dispose() {
    AppState.focusLock.removeListener(_syncFocusOverlay);
    _removeFocusOverlay();
    super.dispose();
  }

  void _syncFocusOverlay() {
    final focus = AppState.focusLock.value;
    if (focus == null) {
      _removeFocusOverlay();
      return;
    }
    if (_focusOverlayEntry != null) return;
    final overlay = Overlay.of(context);
    _focusOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        right: 12,
        child: const FocusOverlayBar(),
      ),
    );
    overlay.insert(_focusOverlayEntry!);
  }

  void _removeFocusOverlay() {
    _focusOverlayEntry?.remove();
    _focusOverlayEntry = null;
  }

  Future<void> _showAiDisclaimer() async {
    if (_aiDisclaimerShown) return;
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool(_aiDisclaimerKey) ?? false;
    if (!shouldShow) return;
    _aiDisclaimerShown = true;
    await prefs.setBool(_aiDisclaimerKey, false);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(1.4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFF59E0B),
                Color(0xFF4FA3C7),
                Color(0xFF4F46E5),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2A44)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1B2D),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFF1E2A44)),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('AI Warning', 'AI चेतावनी'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1203),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Text(
                        context.tr('NEW', 'नयाँ'),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.tr(
                    'AI responses may be inaccurate. Use AI only as a reference '
                    'and verify with official notes, teachers, or textbooks.',
                    'AI ले कहिलेकाहीँ गलत जवाफ दिन सक्छ। AI लाई केवल सन्दर्भको रूपमा '
                    'प्रयोग गर्नुहोस् र आधिकारिक नोट, शिक्षक वा पुस्तकबाट पुष्टि गर्नुहोस्।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4FA3C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('I Understand', 'बुझें')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    const accent = Color(0xFF4FA3C7);
    final l10n = context.l10n;
    final focus = AppState.focusLock.value;
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
              selectedIndex: _currentIndex,
              onDestinationSelected: (value) {
                if (focus != null &&
                    !focus.allowedIndices.contains(value)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Focus mode active. Subjects and AI only.',
                      ),
                    ),
                  );
                  return;
                }
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
                  icon: const Icon(Icons.school),
                  label: l10n.teacher,
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

    return ValueListenableBuilder<FocusLock?>(
      valueListenable: AppState.focusLock,
      builder: (context, focus, child) {
        if (focus != null &&
            !focus.allowedIndices.contains(_currentIndex)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = focus.allowedIndices.first);
          });
        }
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildNavBar(context),
        );
      },
    );
  }
}
