import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/profile_service.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
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
    _profileService = ProfileService(SupabaseConfig.client);
    _load();
  }

  late final ValueNotifier<ProfileEditViewModel> state;
  late final SubjectService _subjectService;
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

      state.value = state.value.copyWith(
        semesters: semesters,
        selectedSemester: preferredSemester,
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
    state.value = state.value.copyWith(selectedSemester: semester);
  }

  Future<void> save() async {
    if (!state.value.canSave) {
      view?.showMessage('Select a semester.');
      return;
    }

    final semester = state.value.selectedSemester;
    if (semester == null) {
      view?.showMessage('Select a semester.');
      return;
    }

    try {
      await _profileService.updateName(state.value.fullName.trim());
      await _profileService.updateSemester(semester.id);
      final fullSubjects = await _subjectService.fetchSubjectsForSemester(
        semester.id,
        includeContent: true,
      );

      final updatedProfile = UserProfile(
        name: state.value.fullName.trim(),
        email: state.value.email,
        semester: semester,
        subjects: fullSubjects,
        isAdmin: AppState.profile.value.isAdmin,
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
