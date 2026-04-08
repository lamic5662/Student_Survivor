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
  void openBooks();
  void openProgrammingWorld();
  void openCoach();
  void openRevisionQueue();
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
  bool _loading = false;

  void _refreshFromProfile() {
    state.value = state.value.copyWith(profile: AppState.profile.value);
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
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
        revisionQueue: data.revisionQueue,
        latestAttempt: data.latestAttempt,
      );
    } catch (error) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard: $error',
      );
    } finally {
      _loading = false;
    }
  }

  void onSearch() => view?.openSearch();

  void onPlanner() => view?.openPlanner();

  void onSyllabus() => view?.openSyllabus();

  void onProgress() => view?.openProgress();

  void onNotices() => view?.openNotices();

  void onBooks() => view?.openBooks();

  void onProgrammingWorld() => view?.openProgrammingWorld();

  void onCoach() => view?.openCoach();

  void onRevisionQueue() => view?.openRevisionQueue();

  @override
  void onViewDetached() {
    AppState.profile.removeListener(_listener);
    state.dispose();
    super.onViewDetached();
  }
}
