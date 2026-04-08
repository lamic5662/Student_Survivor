import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/base_view.dart';
import 'package:student_survivor/core/mvp/presenter.dart';
import 'package:student_survivor/data/ai_request.dart';
import 'package:student_survivor/data/ai_router_service.dart';
import 'package:student_survivor/data/ai_service.dart';
import 'package:student_survivor/data/free_ai_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';

abstract class AiView extends BaseView {}

class AiPresenter extends Presenter<AiView> {
  AiPresenter() {
    state = ValueNotifier(AiViewModel.initial());
    _aiService = AiService(SupabaseConfig.client);
    _freeAiService = FreeAiService(SupabaseConfig.client);
    _aiRouter = AiRouterService(SupabaseConfig.client);
    _loadConversations();
  }

  late final ValueNotifier<AiViewModel> state;
  late final AiService _aiService;
  late final FreeAiService _freeAiService;
  late final AiRouterService _aiRouter;
  String? _conversationId;
  bool _loadingConversations = false;

  Future<void> _loadConversations() async {
    if (_loadingConversations) return;
    _loadingConversations = true;
    try {
      final rows = await _aiService.fetchConversations(limit: 20);
      final conversations = rows.map((row) {
        final title = row['title']?.toString().trim();
        final created = row['created_at']?.toString();
        final updated = row['updated_at']?.toString();
        final timestamp = (updated?.isNotEmpty ?? false) ? updated : created;
        return AiConversation(
          id: row['id']?.toString() ?? '',
          title: (title == null || title.isEmpty)
              ? 'Study Session'
              : title,
          updatedAt: timestamp == null
              ? null
              : DateTime.tryParse(timestamp),
        );
      }).where((item) => item.id.isNotEmpty).toList();
      state.value = state.value.copyWith(conversations: conversations);
    } catch (_) {
      // ignore for now
    } finally {
      _loadingConversations = false;
    }
  }

  Future<void> openConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    _conversationId = conversationId;
    state.value =
        state.value.copyWith(activeConversationId: conversationId);
    try {
      final rows = await _aiService.fetchConversationMessages(conversationId);
      final messages = rows
          .map((row) => AiMessage(
                isUser: row['role']?.toString() == 'user',
                text: row['content']?.toString() ?? '',
              ))
          .where((message) => message.text.trim().isNotEmpty)
          .toList();
      state.value = state.value.copyWith(messages: messages);
    } catch (_) {
      // ignore
    }
  }

  Future<void> sendMessage(String message, {String? mode}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (_conversationId == null) {
      try {
        _conversationId =
            await _aiService.createConversation(title: _titleFrom(trimmed));
      } catch (_) {}
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
      state.value = state.value.copyWith(
        messages: messages,
        isLoading: false,
        activeConversationId: _conversationId,
      );
      await _loadConversations();
    } catch (error) {
      state.value = state.value.copyWith(
        isLoading: false,
        errorMessage: 'AI failed: $error',
      );
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    if (conversationId.isEmpty) return;
    final wasActive = _conversationId == conversationId ||
        state.value.activeConversationId == conversationId;
    state.value = state.value.copyWith(
      conversations: state.value.conversations
          .where((conversation) => conversation.id != conversationId)
          .toList(),
      activeConversationId: wasActive ? null : state.value.activeConversationId,
      messages: wasActive ? const [] : state.value.messages,
    );
    try {
      await _aiService.deleteConversation(conversationId);
      if (wasActive) {
        _conversationId = null;
      }
      await _loadConversations();
    } catch (error) {
      state.value = state.value.copyWith(
        errorMessage: 'Delete failed: $error',
      );
      await _loadConversations();
    }
  }

  Future<void> deleteAllConversations() async {
    state.value = state.value.copyWith(
      conversations: const [],
      activeConversationId: null,
      messages: const [],
      errorMessage: null,
      isLoading: false,
    );
    _conversationId = null;
    try {
      await _aiService.clearUserHistory();
      await _loadConversations();
    } catch (error) {
      state.value = state.value.copyWith(
        errorMessage: 'Delete failed: $error',
      );
      await _loadConversations();
    }
  }

  void resetConversation() {
    _conversationId = null;
    state.value = state.value.copyWith(
      messages: const [],
      activeConversationId: null,
      isLoading: false,
      errorMessage: null,
    );
  }

  String _titleFrom(String message) {
    final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return 'Study Session';
    return normalized.length > 42 ? '${normalized.substring(0, 42)}…' : normalized;
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
    _conversationId ??= await _aiService.ensureConversationId(_conversationId);
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) {
      throw Exception('Please sign in to use AI chat.');
    }
    await _aiService.logMessage(
      conversationId: conversationId,
      role: 'user',
      content: message,
    );
    try {
      final timeout = _isProgrammingQuery(message)
          ? const Duration(milliseconds: 20000)
          : const Duration(milliseconds: 12000);
      final reply = await _aiRouter.send(
        AiRequest(
          feature: AiFeature.tutor,
          systemPrompt: _buildSystemPrompt(mode),
          userPrompt: message,
          temperature: 0.3,
          timeout: timeout,
          metadata: {
            'mode': mode,
          },
        ),
      );
      if (reply.isNotEmpty) {
        await _aiService.logMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: reply,
        );
      }
      return reply;
    } catch (_) {
      final fallback = await _freeAiService.answer(message, mode: mode);
      if (fallback.isNotEmpty) {
        await _aiService.logMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: fallback,
        );
      }
      return 'Cloud AI unavailable, using offline AI.\n\n$fallback';
    }
  }

  String _buildSystemPrompt(String? mode) {
    const base =
        'You are a concise study assistant for BCA TU students. Answer clearly, '
        'using headings or bullet points when helpful.';
    if (mode == null) {
      return base;
    }
    final normalized = mode.toLowerCase();
    if (normalized.contains('short')) {
      return '$base Provide a short 5-mark style answer.';
    }
    if (normalized.contains('long')) {
      return '$base Provide a detailed 10-mark style answer.';
    }
    if (normalized.contains('simple')) {
      return '$base Explain in very simple language.';
    }
    if (normalized.contains('exam')) {
      return '$base Suggest important exam questions related to the topic.';
    }
    return base;
  }

  bool _isProgrammingQuery(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('code') ||
        lower.contains('program') ||
        lower.contains('compile') ||
        lower.contains('debug') ||
        lower.contains('error') ||
        lower.contains('stack trace') ||
        lower.contains('algorithm') ||
        lower.contains('syntax')) {
      return true;
    }
    if (message.contains('```')) return true;
    if (message.contains('{') && message.contains('}')) return true;
    if (message.contains(';') && message.contains('(')) return true;
    return false;
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
