import 'package:flutter/foundation.dart';
import 'package:student_survivor/core/mvp/base_view.dart';

abstract class Presenter<V extends BaseView> {
  V? _view;

  @protected
  V? get view => _view;

  void attachView(V view) {
    _view = view;
    onViewAttached();
  }

  void detachView() {
    onViewDetached();
    _view = null;
  }

  @protected
  void onViewAttached() {}

  @protected
  void onViewDetached() {}
}
