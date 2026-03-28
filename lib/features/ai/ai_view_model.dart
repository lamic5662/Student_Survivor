class AiMessage {
  final bool isUser;
  final String text;

  const AiMessage({
    required this.isUser,
    required this.text,
  });
}

class AiViewModel {
  final List<AiMessage> messages;
  final List<String> suggestions;
  final bool isLoading;
  final String? errorMessage;

  const AiViewModel({
    required this.messages,
    required this.suggestions,
    required this.isLoading,
    required this.errorMessage,
  });

  AiViewModel copyWith({
    List<AiMessage>? messages,
    List<String>? suggestions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AiViewModel(
      messages: messages ?? this.messages,
      suggestions: suggestions ?? this.suggestions,
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
      isLoading: false,
      errorMessage: null,
    );
  }
}
