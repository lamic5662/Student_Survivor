import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/auth_service.dart';
import 'package:student_survivor/data/profile_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
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
  }

  late final ValueNotifier<AuthViewModel> state;
  late final AuthService _authService;
  late final ProfileService _profileService;

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

      final user = response.user ?? Supabase.instance.client.auth.currentUser;
      AppState.updateFromAuth(user);

      final profile = await _profileService.fetchProfile();
      if (profile != null) {
        AppState.updateProfile(profile);
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
