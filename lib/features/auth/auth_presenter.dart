import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/features/auth/auth_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class AuthView extends BaseView {
  void goToHome();
}

class AuthPresenter extends Presenter<AuthView> {
  AuthPresenter() {
    state = ValueNotifier(AuthViewModel.initial(MockData.semesters));
  }

  late final ValueNotifier<AuthViewModel> state;

  void toggleMode() {
    state.value = state.value.copyWith(isLogin: !state.value.isLogin);
  }

  void setAuthMethod(AuthMethod method) {
    state.value = state.value.copyWith(method: method);
  }

  void selectSemester(Semester semester) {
    state.value = state.value.copyWith(
      selectedSemester: semester,
      selectedSubjectIds: <String>{},
    );
  }

  void toggleSubject(String subjectId) {
    final updated = Set<String>.from(state.value.selectedSubjectIds);
    if (updated.contains(subjectId)) {
      updated.remove(subjectId);
    } else {
      updated.add(subjectId);
    }
    state.value = state.value.copyWith(selectedSubjectIds: updated);
  }

  void submit() {
    if (!state.value.canContinue) {
      view?.showMessage('Select a semester and at least one subject.');
      return;
    }
    view?.goToHome();
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
