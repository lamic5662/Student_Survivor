import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';

abstract class QuizHubView extends BaseView {}

class QuizHubPresenter extends Presenter<QuizHubView> {
  QuizHubPresenter() {
    state = ValueNotifier(_fromProfile());
    _listener = () => state.value = _fromProfile();
    AppState.profile.addListener(_listener);
  }

  late final ValueNotifier<QuizHubViewModel> state;
  late final VoidCallback _listener;

  QuizHubViewModel _fromProfile() {
    final items = <QuizCardItem>[];
    final profile = AppState.profile.value;
    for (final subject in profile.subjects) {
      for (final chapter in subject.chapters) {
        for (final quiz in chapter.quizzes) {
          items.add(QuizCardItem(quiz: quiz, subject: subject));
        }
      }
    }

    return QuizHubViewModel(quizzes: items);
  }

  @override
  void onViewDetached() {
    AppState.profile.removeListener(_listener);
    state.dispose();
    super.onViewDetached();
  }
}
