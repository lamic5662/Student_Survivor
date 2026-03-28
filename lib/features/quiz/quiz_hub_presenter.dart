import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';
import 'package:student_survivor/data/app_state.dart';

abstract class QuizHubView extends BaseView {}

class QuizHubPresenter extends Presenter<QuizHubView> {
  QuizHubPresenter() {
    state = ValueNotifier(_fromProfile(isLoading: true));
    _listener = () => state.value = _fromProfile(isLoading: false);
    AppState.profile.addListener(_listener);
    state.value = _fromProfile(isLoading: false);
  }

  late final ValueNotifier<QuizHubViewModel> state;
  late final VoidCallback _listener;

  QuizHubViewModel _fromProfile({required bool isLoading}) {
    final profile = AppState.profile.value;
    final hasSemester = profile.semester.id.isNotEmpty;
    return QuizHubViewModel(
      semesterName: hasSemester ? profile.semester.name : '',
      subjects: hasSemester ? profile.subjects : const [],
      isLoading: isLoading,
      errorMessage: null,
    );
  }

  @override
  void onViewDetached() {
    AppState.profile.removeListener(_listener);
    state.dispose();
    super.onViewDetached();
  }
}
