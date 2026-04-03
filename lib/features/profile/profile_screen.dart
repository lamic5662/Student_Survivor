import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';
import 'package:student_survivor/features/auth/auth_screen.dart';
import 'package:student_survivor/features/community/subject_qna_screen.dart';
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
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Logout'),
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
    if (profile.subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects available yet.')),
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
                'Community Q&A',
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
                'Choose a subject to view questions.',
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Profile',
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
                                  color: const Color(0xFF38BDF8),
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
                                  _ProfileChip(
                                    label: profile.isAdmin
                                        ? 'Admin'
                                        : 'Student',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
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
                    'Quick actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  _ProfileItem(
                    icon: Icons.search,
                    label: 'Search',
                    subtitle: 'Find notes, questions, and quizzes.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.forum_outlined,
                    label: 'Community Q&A',
                    subtitle: 'Ask questions and help classmates.',
                    onTap: () => _openCommunityQna(profile),
                  ),
                  _ProfileItem(
                    icon: Icons.event_note,
                    label: 'Study Planner',
                    subtitle: 'Plan sessions and stay on track.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PlannerScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.insights,
                    label: 'Progress Tracking',
                    subtitle: 'Review goals and achievements.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProgressScreen()),
                      );
                    },
                  ),
                  _ProfileItem(
                    icon: Icons.list_alt,
                    label: 'Syllabus',
                    subtitle: 'Open official course outlines.',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SyllabusScreen()),
                      );
                    },
                  ),
                  if (profile.isAdmin)
                    _ProfileItem(
                      icon: Icons.admin_panel_settings,
                      label: 'Admin',
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
                    label: 'Logout',
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
                child: Icon(icon, color: const Color(0xFF38BDF8)),
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
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
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
            Color(0xFF38BDF8),
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
