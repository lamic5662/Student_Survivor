import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/features/quiz/quiz_hub_view_model.dart';

abstract class QuizHubView extends BaseView {}

class QuizHubPresenter extends Presenter<QuizHubView> {
  QuizHubPresenter() {
    final items = <QuizCardItem>[];
    for (final subject in MockData.profile.subjects) {
      for (final chapter in subject.chapters) {
        for (final quiz in chapter.quizzes) {
          items.add(QuizCardItem(quiz: quiz, subject: subject));
        }
      }
    }

    state = ValueNotifier(QuizHubViewModel(quizzes: items));
  }

  late final ValueNotifier<QuizHubViewModel> state;

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
