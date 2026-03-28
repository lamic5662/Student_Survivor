import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/admin/admin_screen.dart';
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
  @override
  ProfilePresenter createPresenter() => ProfilePresenter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ValueListenableBuilder<UserProfile>(
        valueListenable: presenter.state,
        builder: (context, profile, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                      child: Text(
                        profile.name
                            .split(' ')
                            .map((part) => part.isNotEmpty ? part[0] : '')
                            .take(2)
                            .join(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.secondary),
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
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.email,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.semester.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                        ],
                      ),
                    ),
                    IconButton.outlined(
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
              _ProfileItem(
                icon: Icons.search,
                label: 'Search',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
              _ProfileItem(
                icon: Icons.event_note,
                label: 'Study Planner',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlannerScreen()),
                  );
                },
              ),
              _ProfileItem(
                icon: Icons.insights,
                label: 'Progress Tracking',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProgressScreen()),
                  );
                },
              ),
              _ProfileItem(
                icon: Icons.list_alt,
                label: 'Syllabus',
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
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    );
                  },
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
  final VoidCallback onTap;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.secondary),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
