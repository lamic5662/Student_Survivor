import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/features/profile/profile_edit_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class ProfileEditView extends BaseView {
  void close();
}

class ProfileEditPresenter extends Presenter<ProfileEditView> {
  ProfileEditPresenter() {
    state = ValueNotifier(
      ProfileEditViewModel.fromProfile(
        profile: AppState.profile.value,
        semesters: MockData.semesters,
      ),
    );
  }

  late final ValueNotifier<ProfileEditViewModel> state;

  void updateName(String value) {
    state.value = state.value.copyWith(fullName: value);
  }

  void selectSemester(Semester semester) {
    final validIds = semester.subjects.map((subject) => subject.id).toSet();
    final retained = state.value.selectedSubjectIds.intersection(validIds);
    state.value = state.value.copyWith(
      selectedSemester: semester,
      selectedSubjectIds: retained,
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

  void save() {
    if (!state.value.canSave) {
      view?.showMessage('Select at least one subject.');
      return;
    }

    final subjects = state.value.selectedSemester.subjects
        .where((subject) => state.value.selectedSubjectIds.contains(subject.id))
        .toList();

    final updatedProfile = UserProfile(
      name: state.value.fullName.trim(),
      email: state.value.email,
      semester: state.value.selectedSemester,
      subjects: subjects,
    );

    AppState.updateProfile(updatedProfile);
    view?.close();
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
