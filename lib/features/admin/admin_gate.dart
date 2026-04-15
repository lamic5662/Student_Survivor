import 'package:flutter/material.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/profile_service.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/admin/admin_auth_screen.dart';
import 'package:student_survivor/features/admin/admin_shell.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool _isLoading = true;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final client = SupabaseConfig.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
      return;
    }

    AppState.updateFromAuth(user);
    try {
      final profileService = ProfileService(client);
      final subjectService = SubjectService(client);
      final profile = await profileService.fetchProfile();
      if (profile == null) {
        throw Exception('Profile not found.');
      }
      final subjects = profile.semester.id.isEmpty
          ? <Subject>[]
          : await subjectService.fetchSubjectsForSemester(
              profile.semester.id,
              includeContent: true,
            );
      AppState.updateProfile(
        UserProfile(
          name: profile.name,
          email: profile.email,
          collegeName: profile.collegeName,
          semester: profile.semester,
          subjects: subjects,
          isAdmin: profile.isAdmin,
          isBlocked: profile.isBlocked,
          blockedReason: profile.blockedReason,
        ),
      );
      if (!mounted) return;
      setState(() {
        _isAdmin = profile.isAdmin;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile: $error';
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await SupabaseConfig.client.auth.signOut(
        scope: SignOutScope.local,
      );
    } catch (_) {
      // Ignore logout errors; we'll still clear local state.
    }
    AppState.reset();
    if (!mounted) return;
    setState(() {
      _isAdmin = false;
      _error = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      return AdminAuthScreen(onLoggedIn: _bootstrap);
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Access'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Access denied',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                _error ??
                    'This account does not have admin privileges. Please log in with an admin account.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _logout,
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return AdminShell(onLogout: _logout);
  }
}
