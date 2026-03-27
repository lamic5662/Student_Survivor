import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class ProfileView extends BaseView {}

class ProfilePresenter extends Presenter<ProfileView> {
  ProfilePresenter() {
    state = ValueNotifier(MockData.profile);
  }

  late final ValueNotifier<UserProfile> state;

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
