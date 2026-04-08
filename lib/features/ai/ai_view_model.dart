class AiMessage {
  final bool isUser;
  final String text;

  const AiMessage({
    required this.isUser,
    required this.text,
  });
}

class AiConversation {
  final String id;
  final String title;
  final DateTime? updatedAt;

  const AiConversation({
    required this.id,
    required this.title,
    required this.updatedAt,
  });
}

class AiViewModel {
  final List<AiMessage> messages;
  final List<String> suggestions;
  final List<AiConversation> conversations;
  final String? activeConversationId;
  final bool isLoading;
  final String? errorMessage;

  const AiViewModel({
    required this.messages,
    required this.suggestions,
    required this.conversations,
    required this.activeConversationId,
    required this.isLoading,
    required this.errorMessage,
  });

  AiViewModel copyWith({
    List<AiMessage>? messages,
    List<String>? suggestions,
    List<AiConversation>? conversations,
    String? activeConversationId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiViewModel(
      messages: messages ?? this.messages,
      suggestions: suggestions ?? this.suggestions,
      conversations: conversations ?? this.conversations,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  factory AiViewModel.initial() {
    return const AiViewModel(
      messages: [],
      suggestions: [
        'Short answer (5 marks)',
        'Long answer (10 marks)',
        'Explain in simple language',
        'Suggest exam questions',
      ],
      conversations: [],
      activeConversationId: null,
      isLoading: false,
      errorMessage: null,
    );
  }
}
