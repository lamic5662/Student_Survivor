import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/dashboard_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/dashboard/dashboard_view_model.dart';

abstract class DashboardView extends BaseView {
  void openSearch();
  void openPlanner();
  void openSyllabus();
  void openProgress();
  void openNotices();
  void openCoach();
}

class DashboardPresenter extends Presenter<DashboardView> {
  DashboardPresenter() {
    state = ValueNotifier(DashboardViewModel.initial(AppState.profile.value));
    _listener = () => _refreshFromProfile();
    AppState.profile.addListener(_listener);
    _dashboardService = DashboardService(SupabaseConfig.client);
    _load();
  }

  late final ValueNotifier<DashboardViewModel> state;
  late final VoidCallback _listener;
  late final DashboardService _dashboardService;

  void _refreshFromProfile() {
    state.value = state.value.copyWith(profile: AppState.profile.value);
    _load();
  }

  Future<void> _load() async {
    state.value = state.value.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _dashboardService.fetchDashboard(
        subjects: AppState.profile.value.subjects,
      );
      state.value = state.value.copyWith(
        isLoading: false,
        progress: data.progress,
        xp: data.xp,
        gamesPlayed: data.gamesPlayed,
        weakTopics: data.weakTopics,
        recommendedNotes: data.recommendedNotes,
        latestAttempt: data.latestAttempt,
      );
    } catch (error) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard: $error',
      );
    }
  }

  void onSearch() => view?.openSearch();

  void onPlanner() => view?.openPlanner();

  void onSyllabus() => view?.openSyllabus();

  void onProgress() => view?.openProgress();

  void onNotices() => view?.openNotices();

  void onCoach() => view?.openCoach();

  @override
  void onViewDetached() {
    AppState.profile.removeListener(_listener);
    state.dispose();
    super.onViewDetached();
  }
}
