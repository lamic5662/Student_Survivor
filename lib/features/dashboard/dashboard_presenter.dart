import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/features/dashboard/dashboard_view_model.dart';

abstract class DashboardView extends BaseView {
  void openSearch();
  void openPlanner();
  void openSyllabus();
  void openProgress();
}

class DashboardPresenter extends Presenter<DashboardView> {
  DashboardPresenter() {
    state = ValueNotifier(
      DashboardViewModel(
        profile: MockData.profile,
        progress: 0.62,
        xp: 1240,
        gamesPlayed: 18,
        weakTopics: MockData.weakTopics,
        recommendedNotes: MockData.networkingChapters.first.notes,
        planner: MockData.planner,
        latestAttempt: MockData.sampleAttempt,
      ),
    );
  }

  late final ValueNotifier<DashboardViewModel> state;

  void onSearch() => view?.openSearch();

  void onPlanner() => view?.openPlanner();

  void onSyllabus() => view?.openSyllabus();

  void onProgress() => view?.openProgress();

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
