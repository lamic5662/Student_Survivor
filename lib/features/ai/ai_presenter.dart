import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/ai_service.dart';
import 'package:student_survivor/data/free_ai_service.dart';
import 'package:student_survivor/data/lmstudio_ai_service.dart';
import 'package:student_survivor/data/ollama_ai_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';

abstract class AiView extends BaseView {}

class AiPresenter extends Presenter<AiView> {
  AiPresenter() {
    state = ValueNotifier(AiViewModel.initial());
    _aiService = AiService(SupabaseConfig.client);
    _freeAiService = FreeAiService(SupabaseConfig.client);
    _ollamaService = OllamaAiService();
    _lmStudioService = LmStudioAiService();
  }

  late final ValueNotifier<AiViewModel> state;
  late final AiService _aiService;
  late final FreeAiService _freeAiService;
  late final OllamaAiService _ollamaService;
  late final LmStudioAiService _lmStudioService;
  String? _conversationId;

  Future<void> sendMessage(String message, {String? mode}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final extracted = _extractMode(trimmed);
    final cleanedMessage = extracted.cleaned;
    final chosenMode = mode ?? extracted.mode;

    final messages = List<AiMessage>.from(state.value.messages)
      ..add(AiMessage(isUser: true, text: trimmed));
    state.value = state.value.copyWith(
      messages: messages,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final reply = await _send(cleanedMessage, chosenMode);
      messages.add(AiMessage(isUser: false, text: reply.isEmpty ? '...' : reply));
      state.value = state.value.copyWith(messages: messages, isLoading: false);
    } catch (error) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: 'AI failed: $error',
      );
    }
  }

  Future<String> _send(String message, String? mode) async {
    final modeKey =
        SupabaseConfig.aiProviderFor(AiFeature.tutor, message: message, mode: mode)
            .toLowerCase();
    if (modeKey == 'free') {
      final conversationId = await _aiService.ensureConversationId(
        _conversationId,
      );
      if (conversationId != null) {
        _conversationId = conversationId;
        await _aiService.logMessage(
          conversationId: conversationId,
          role: 'user',
          content: message,
        );
      }
      final reply = await _freeAiService.answer(message, mode: mode);
      if (conversationId != null && reply.isNotEmpty) {
        await _aiService.logMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: reply,
        );
      }
      return reply;
    }
    if (modeKey == 'ollama') {
      try {
        final conversationId = await _aiService.ensureConversationId(
          _conversationId,
        );
        if (conversationId != null) {
          _conversationId = conversationId;
          await _aiService.logMessage(
            conversationId: conversationId,
            role: 'user',
            content: message,
          );
        }
        final reply = await _ollamaService.answer(message, mode: mode);
        if (conversationId != null && reply.isNotEmpty) {
          await _aiService.logMessage(
            conversationId: conversationId,
            role: 'assistant',
            content: reply,
          );
        }
        return reply;
      } catch (_) {
        final fallback = await _freeAiService.answer(message, mode: mode);
        return 'Ollama not reachable, using local AI.\n\n$fallback';
      }
    }
    if (modeKey == 'lmstudio' ||
        modeKey == 'lm-studio' ||
        modeKey == 'lm_studio') {
      try {
        final conversationId = await _aiService.ensureConversationId(
          _conversationId,
        );
        if (conversationId != null) {
          _conversationId = conversationId;
          await _aiService.logMessage(
            conversationId: conversationId,
            role: 'user',
            content: message,
          );
        }
        final reply = await _lmStudioService.answer(message, mode: mode);
        if (conversationId != null && reply.isNotEmpty) {
          await _aiService.logMessage(
            conversationId: conversationId,
            role: 'assistant',
            content: reply,
          );
        }
        return reply;
      } catch (_) {
        final fallback = await _freeAiService.answer(message, mode: mode);
        return 'LM Studio not reachable, using local AI.\n\n$fallback';
      }
    }

    _conversationId ??= await _aiService.ensureConversationId(_conversationId);
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      throw Exception('Please sign in to use AI chat.');
    }
    return _aiService.sendMessage(
      conversationId: conversationId,
      message: message,
      mode: mode,
    );
  }

  _ModeExtraction _extractMode(String message) {
    final lower = message.toLowerCase();
    String? mode;
    if (lower.startsWith('short answer') || lower.contains('5 marks')) {
      mode = 'short';
    } else if (lower.startsWith('long answer') || lower.contains('10 marks')) {
      mode = 'long';
    } else if (lower.contains('simple')) {
      mode = 'simple';
    } else if (lower.contains('exam')) {
      mode = 'exam';
    }

    final cleaned = message.replaceFirst(
      RegExp(
        r'^(short answer.*?:|long answer.*?:|explain in simple language.*?:|suggest exam questions.*?:)\s*',
        caseSensitive: false,
      ),
      '',
    );

    return _ModeExtraction(mode: mode, cleaned: cleaned.trim());
  }

  @override
  void onViewDetached() {
    state.dispose();
    super.onViewDetached();
  }
}

class _ModeExtraction {
  final String? mode;
  final String cleaned;

  const _ModeExtraction({
    required this.mode,
    required this.cleaned,
  });
}
