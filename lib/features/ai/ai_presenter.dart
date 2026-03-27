import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';

abstract class AiView extends BaseView {}

class AiPresenter extends Presenter<AiView> {
  AiPresenter() {
    state = ValueNotifier(
      const AiViewModel(
        messages: [
          AiMessage(isUser: true, text: 'Explain TCP vs UDP in simple terms.'),
          AiMessage(
            isUser: false,
            text:
                'TCP is like a registered mail service. It confirms delivery and order. '
                'UDP is like a quick postcard: faster, but no confirmation.',
          ),
        ],
        suggestions: [
          'Short answer (5 marks)',
          'Long answer (10 marks)',
          'Explain in simple language',
          'Suggest exam questions',
        ],
      ),
    );
  }

  late final ValueNotifier<AiViewModel> state;

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}
