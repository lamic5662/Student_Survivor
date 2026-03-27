import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/profile_service.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_subject_service.dart';
import 'package:student_survivor/features/profile/profile_edit_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class ProfileEditView extends BaseView {
  void close();
}

class ProfileEditPresenter extends Presenter<ProfileEditView> {
  ProfileEditPresenter() {
    final profile = AppState.profile.value;
    state = ValueNotifier(
      ProfileEditViewModel.initial(
        fullName: profile.name,
        email: profile.email,
      ),
    );
    _subjectService = SubjectService(SupabaseConfig.client);
    _userSubjectService = UserSubjectService(SupabaseConfig.client);
    _profileService = ProfileService(SupabaseConfig.client);
    _load();
  }

  late final ValueNotifier<ProfileEditViewModel> state;
  late final SubjectService _subjectService;
  late final UserSubjectService _userSubjectService;
  late final ProfileService _profileService;

  Future<void> _load() async {
    try {
      final semesters = await _subjectService.fetchSemesters();
      if (semesters.isEmpty) {
        state.value = state.value.copyWith(
          semesters: const [],
          selectedSemester: null,
          isLoading: false,
          errorMessage: 'No semesters found. Seed the database first.',
        );
        return;
      }

      final profile = AppState.profile.value;
      final preferredSemester = semesters.firstWhere(
        (semester) => semester.id == profile.semester.id,
        orElse: () => semesters.first,
      );

      final selectedIds = profile.subjects
          .map((subject) => subject.id)
          .where((id) => preferredSemester.subjects
              .any((subject) => subject.id == id))
          .toSet();

      state.value = state.value.copyWith(
        semesters: semesters,
        selectedSemester: preferredSemester,
        selectedSubjectIds: selectedIds,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load semesters: $error',
      );
    }
  }

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

  Future<void> save() async {
    if (!state.value.canSave) {
      view?.showMessage('Select at least one subject.');
      return;
    }

    final semester = state.value.selectedSemester;
    if (semester == null) {
      view?.showMessage('Select a semester.');
      return;
    }

    final selectedSubjects = semester.subjects
        .where((subject) => state.value.selectedSubjectIds.contains(subject.id))
        .toList();

    try {
      await _profileService.updateName(state.value.fullName.trim());
      await _userSubjectService.setUserSubjects(
        semesterId: semester.id,
        subjectIds: selectedSubjects.map((subject) => subject.id).toList(),
      );

      final updatedProfile = UserProfile(
        name: state.value.fullName.trim(),
        email: state.value.email,
        semester: semester,
        subjects: selectedSubjects,
      );

      AppState.updateProfile(updatedProfile);
      view?.close();
    } catch (error) {
      view?.showMessage('Failed to save profile: $error');
    }
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
