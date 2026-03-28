import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/auth_service.dart';
import 'package:student_survivor/data/profile_service.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/features/auth/auth_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class AuthView extends BaseView {
  void goToHome();
}

class AuthPresenter extends Presenter<AuthView> {
  AuthPresenter() {
    state = ValueNotifier(AuthViewModel.initial());
    _authService = AuthService(SupabaseConfig.client);
    _profileService = ProfileService(SupabaseConfig.client);
    _subjectService = SubjectService(SupabaseConfig.client);
  }

  late final ValueNotifier<AuthViewModel> state;
  late final AuthService _authService;
  late final ProfileService _profileService;
  late final SubjectService _subjectService;

  void toggleMode() {
    state.value = state.value.copyWith(isLogin: !state.value.isLogin);
  }

  void setAuthMethod(AuthMethod method) {
    state.value = state.value.copyWith(method: method);
  }

  Future<void> submit({
    required String identifier,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      view?.showMessage('Supabase config missing.');
      return;
    }

    if (identifier.trim().isEmpty || password.trim().isEmpty) {
      view?.showMessage('Email/phone and password are required.');
      return;
    }

    if (state.value.isSubmitting) {
      return;
    }

    state.value = state.value.copyWith(isSubmitting: true);

    try {
      AuthResponse response;
      if (state.value.isLogin) {
        response = await _authService.signIn(
          method: state.value.method,
          identifier: identifier,
          password: password,
        );
      } else {
        response = await _authService.signUp(
          method: state.value.method,
          identifier: identifier,
          password: password,
        );
      }

      final user = response.user;
      final session = response.session;
      if (user == null) {
        view?.showMessage('Authentication failed. Please try again.');
        return;
      }
      if (session == null) {
        if (state.value.isLogin) {
          view?.showMessage('Invalid credentials. Please try again.');
        } else {
          view?.showMessage(
            'Check your email/phone to verify your account, then login.',
          );
        }
        return;
      }

      if (!state.value.isLogin) {
        try {
          await SupabaseConfig.client.auth.signOut(
            scope: SignOutScope.local,
          );
        } catch (_) {
          // Ignore logout errors; user can login after signup.
        }
        state.value = state.value.copyWith(isLogin: true);
        view?.showMessage('Account created. Please login.');
        return;
      }

      AppState.updateFromAuth(user);

      final profile = await _profileService.fetchProfile();
      if (profile != null) {
        final subjects = await _subjectService.fetchSubjectsForSemester(
          profile.semester.id,
          includeContent: true,
        );
        AppState.updateProfile(
          UserProfile(
            name: profile.name,
            email: profile.email,
            semester: profile.semester,
            subjects: subjects,
            isAdmin: profile.isAdmin,
          ),
        );
      }

      view?.goToHome();
    } on AuthException catch (error) {
      view?.showMessage(error.message);
    } catch (error) {
      view?.showMessage('Login failed: $error');
    } finally {
      state.value = state.value.copyWith(isSubmitting: false);
    }
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
