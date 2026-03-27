import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class ProfileView extends BaseView {}

class ProfilePresenter extends Presenter<ProfileView> {
  ProfilePresenter() {
    state = AppState.profile;
  }

  late final ValueNotifier<UserProfile> state;

  @override
  void onViewDetached() {
    // AppState.profile is global; do not dispose it here.
  }
}
