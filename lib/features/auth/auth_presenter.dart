import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/features/auth/auth_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class AuthView extends BaseView {
  void goToHome();
}

class AuthPresenter extends Presenter<AuthView> {
  AuthPresenter() {
    state = ValueNotifier(AuthViewModel.initial());
  }

  late final ValueNotifier<AuthViewModel> state;

  void toggleMode() {
    state.value = state.value.copyWith(isLogin: !state.value.isLogin);
  }

  void setAuthMethod(AuthMethod method) {
    state.value = state.value.copyWith(method: method);
  }

  void submit() {
    view?.goToHome();
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
