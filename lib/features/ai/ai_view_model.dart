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

  const AiViewModel({
    required this.messages,
    required this.suggestions,
  });
}
