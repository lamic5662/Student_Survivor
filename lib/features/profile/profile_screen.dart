import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/localization/locale_controller.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';
import 'package:student_survivor/features/auth/auth_screen.dart';
import 'package:student_survivor/features/community/subject_qna_screen.dart';
import 'package:student_survivor/features/chat/chat_hub_screen.dart';
import 'package:student_survivor/features/planner/planner_screen.dart';
import 'package:student_survivor/features/profile/profile_edit_screen.dart';
import 'package:student_survivor/features/profile/profile_presenter.dart';
import 'package:student_survivor/features/progress/progress_screen.dart';
import 'package:student_survivor/features/search/search_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState
    extends PresenterState<ProfileScreen, ProfileView, ProfilePresenter>
    implements ProfileView {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  bool _freeTierOnly = SupabaseConfig.aiFreeTierOnly;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  @override
  ProfilePresenter createPresenter() => ProfilePresenter();

  Future<void> _handleLogout() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.logoutTitle),
            content: Text(l10n.logoutMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.logout),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await SupabaseConfig.client.auth.signOut(
        scope: SignOutScope.local,
      );
    } catch (_) {
      // Ignore logout errors; we'll clear local state.
    }
    AppState.reset();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }


  void _openCommunityQna(UserProfile profile) {
    final l10n = context.l10n;
    if (profile.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noSubjects)),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                l10n.communityQna,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.chooseSubject,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ...profile.subjects.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GameCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectQnaScreen(subject: subject),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111B2E),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFF1E2A44)),
                            ),
                            child:
                                Icon(Icons.forum, color: subject.accentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              subject.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = LocaleController.instance.value;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            l10n.profile,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: presenter.state,
        builder: (context, profile, _) {
          return Stack(
            children: [
              const Positioned.fill(child: _ProfileBackdrop()),
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top +
                      kToolbarHeight +
                      -44,
                  20,
                  28,
                ),
                children: [
                  _GameCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF111B2E),
                          child: Text(
                            profile.name
                                .split(' ')
                                .map((part) => part.isNotEmpty ? part[0] : '')
                                .take(2)
                                .join(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF4FA3C7),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile.email,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _ProfileChip(label: profile.semester.name),
                                  if (profile.collegeName.isNotEmpty)
                                    _ProfileChip(label: profile.collegeName),
                                  _ProfileChip(
                                    label: profile.isAdmin
                                        ? l10n.adminRole
                                        : l10n.student,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF4FA3C7),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ProfileEditScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.quickActions,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  _ProfileItem(
                    icon: Icons.search,
                    label: l10n.search,
                    subtitle: 'Find notes, questions, and quizzes.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.chat_bubble_outline,
                    label: context.tr('Semester Chat', 'सेमेस्टर च्याट'),
                    subtitle: context.tr(
                      'Public semester chat + private groups.',
                      'सार्वजनिक सेमेस्टर च्याट र निजी समूहहरू।',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatHubScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.forum_outlined,
                    label: l10n.communityQna,
                    subtitle: 'Ask questions and help classmates.',
                    onTap: () => _openCommunityQna(profile),
                  ),
                  _ProfileItem(
                    icon: Icons.event_note,
                    label: l10n.studyPlanner,
                    subtitle: 'Plan sessions and stay on track.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlannerScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.insights,
                    label: l10n.progressTracking,
                    subtitle: 'Review goals and achievements.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProgressScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.list_alt,
                    label: l10n.syllabus,
                    subtitle: 'Open official course outlines.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SyllabusScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.language,
                    label: l10n.language,
                    subtitle: currentLocale?.languageCode == 'ne'
                        ? l10n.nepali
                        : l10n.english,
                    onTap: () => _showLanguagePicker(context),
                  ),
                  _ProfileItem(
                    icon: Icons.smart_toy_outlined,
                    label: context.tr('AI Provider', 'AI प्रदायक'),
                    subtitle: _aiProviderSubtitle(context),
                    onTap: () => _showAiProviderPicker(context),
                  ),
                  _ProfileToggleItem(
                    icon: Icons.shield_outlined,
                    label: context.tr('Free-tier only', 'फ्रि टियर मात्र'),
                    subtitle: context.tr(
                      'Stop cloud when free credits end. Fallback to local AI.',
                      'फ्रि क्रेडिट सकिँदा क्लाउड रोक्नुहोस्। लोकल AI प्रयोग हुन्छ।',
                    ),
                    value: _freeTierOnly,
                    onChanged: (value) async {
                      await SupabaseConfig.setAiFreeTierOnly(value);
                      if (!mounted) return;
                      setState(() => _freeTierOnly = value);
                    },
                  ),
                  if (profile.isAdmin)
                    _ProfileItem(
                      icon: Icons.admin_panel_settings,
                      label: l10n.admin,
                      subtitle: 'Manage content and approvals.',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminScreen()),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                  _ProfileItem(
                    icon: Icons.logout,
                    label: l10n.logout,
                    subtitle: 'Sign out of your account.',
                    onTap: _handleLogout,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                l10n.language,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              _GameCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    LocaleController.instance
                        .setLocale(const Locale('en'));
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF4FA3C7)),
                      const SizedBox(width: 12),
                      Text(
                        l10n.english,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _GameCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    LocaleController.instance
                        .setLocale(const Locale('ne'));
                    Navigator.of(context).pop();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Color(0xFF4FA3C7)),
                      const SizedBox(width: 12),
                      Text(
                        l10n.nepali,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _aiProviderSubtitle(BuildContext context) {
    final mode =
        (SupabaseConfig.aiProviderOverride ?? SupabaseConfig.aiMode).toLowerCase();
    switch (mode) {
      case 'groq':
        return context.tr('Groq (fast)', 'Groq (छिटो)');
      case 'openrouter':
        return context.tr('OpenRouter (free)', 'OpenRouter (फ्री)');
      case 'gemini':
        return context.tr('Gemini (backup)', 'Gemini (ब्याकअप)');
      case 'ollama':
        return context.tr('Ollama (offline)', 'Ollama (अफलाइन)');
      default:
        return context.tr(
          'Auto: Groq → OpenRouter → Gemini → Ollama',
          'Auto: Groq → OpenRouter → Gemini → Ollama',
        );
    }
  }

  void _showAiProviderPicker(BuildContext context) {
    final current =
        (SupabaseConfig.aiProviderOverride ?? SupabaseConfig.aiMode).toLowerCase();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        Future<void> selectProvider(String? value) async {
          final navigator = Navigator.of(context);
          await SupabaseConfig.setAiProviderOverride(value);
          if (!mounted) return;
          setState(() {});
          navigator.pop();
        }

        Widget option({
          required String label,
          required String value,
          String? subtitle,
        }) {
          final selected = current == value;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF4FA3C7) : Colors.white54,
            ),
            title: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Colors.white),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white60),
                  ),
            onTap: () => selectProvider(value == 'auto' ? null : value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Choose AI Provider', 'AI प्रदायक छान्नुहोस्'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              option(
                label: context.tr(
                  'Auto (Groq → OpenRouter → Gemini → Ollama)',
                  'Auto (Groq → OpenRouter → Gemini → Ollama)',
                ),
                value: 'auto',
                subtitle: context.tr(
                  'Use free-tier cloud first, then offline.',
                  'पहिला क्लाउड, पछि अफलाइन।',
                ),
              ),
              option(
                label: context.tr('Groq (fast)', 'Groq (छिटो)'),
                value: 'groq',
                subtitle: context.tr(
                  'Primary cloud model.',
                  'मुख्य क्लाउड मोडेल।',
                ),
              ),
              option(
                label:
                    context.tr('OpenRouter (free)', 'OpenRouter (फ्री)'),
                value: 'openrouter',
                subtitle: context.tr(
                  'Free-tier cloud fallback.',
                  'फ्री क्लाउड ब्याकअप।',
                ),
              ),
              option(
                label: context.tr('Gemini (backup)', 'Gemini (ब्याकअप)'),
                value: 'gemini',
                subtitle: context.tr(
                  'Fallback cloud model.',
                  'ब्याकअप क्लाउड मोडेल।',
                ),
              ),
              option(
                label: context.tr('Ollama (offline)', 'Ollama (अफलाइन)'),
                value: 'ollama',
                subtitle: context.tr(
                  'Use local model only.',
                  'स्थानीय मोडेल मात्र।',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GameCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Icon(icon, color: const Color(0xFF4FA3C7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileToggleItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProfileToggleItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GameCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF111B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2A44)),
              ),
              child: Icon(icon, color: const Color(0xFF4FA3C7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF4FA3C7),
              activeTrackColor: const Color(0xFF1E2A44),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;

  const _ProfileChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _ProfileGridPainter())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _ProfileGridPainter extends CustomPainter {
  const _ProfileGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF4FA3C7).withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF4FA3C7),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}
