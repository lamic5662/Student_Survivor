import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/models/app_models.dart';

abstract class SubjectsView extends BaseView {}

class SubjectsPresenter extends Presenter<SubjectsView> {
  SubjectsPresenter() {
    state = ValueNotifier(MockData.profile.subjects);
    semesterName = MockData.profile.semester.name;
  }

  late final ValueNotifier<List<Subject>> state;
  late final String semesterName;

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
