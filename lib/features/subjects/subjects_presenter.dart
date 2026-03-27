import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/subjects/subjects_view_model.dart';

abstract class SubjectsView extends BaseView {}

class SubjectsPresenter extends Presenter<SubjectsView> {
  SubjectsPresenter() {
    state = ValueNotifier(_fromProfile());
    _listener = () => state.value = _fromProfile();
    AppState.profile.addListener(_listener);
  }

  late final ValueNotifier<SubjectsViewModel> state;
  late final VoidCallback _listener;

  SubjectsViewModel _fromProfile() {
    final profile = AppState.profile.value;
    return SubjectsViewModel(
      semesterName: profile.semester.name,
      subjects: profile.subjects,
    );
  }

  @override
  void onViewDetached() {
    AppState.profile.removeListener(_listener);
    state.dispose();
    super.onViewDetached();
  }
}
