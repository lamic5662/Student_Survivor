import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/features/ai/ai_presenter.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState
    extends PresenterState<AiAssistantScreen, AiView, AiPresenter>
    implements AiView {
  @override
  AiPresenter createPresenter() => AiPresenter();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Study Assistant'),
      ),
      body: ValueListenableBuilder<AiViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    ...model.messages.map(
                      (message) => Align(
                        alignment: message.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: message.isUser
                                ? AppColors.secondary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: message.isUser
                                ? null
                                : Border.all(color: AppColors.outline),
                          ),
                          child: Text(
                            message.text,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: message.isUser
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try asking:',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: model.suggestions
                          .map(
                            (suggestion) => ActionChip(
                              label: Text(suggestion),
                              onPressed: () {},
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.outline)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Ask anything about your subject...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () {},
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
