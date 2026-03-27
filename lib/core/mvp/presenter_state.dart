import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';

abstract class PresenterState<T extends StatefulWidget, V extends BaseView,
    P extends Presenter<V>> extends State<T> implements BaseView {
  late final P presenter;

  P createPresenter();

  @override
  void initState() {
    super.initState();
    presenter = createPresenter();
    presenter.attachView(this as V);
  }

  @override
  void dispose() {
    presenter.detachView();
    super.dispose();
  }

  @override
  void showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
