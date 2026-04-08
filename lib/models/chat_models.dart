class ChatRoom {
  final String id;
  final String name;
  final String type;
  final String semesterId;
  final String createdBy;
  final DateTime createdAt;

  const ChatRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.semesterId,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isPublic => type == 'public';
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? collegeName;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.collegeName,
    required this.body,
    required this.createdAt,
  });
}

class ChatUserSummary {
  final String id;
  final String name;
  final String email;
  final String? collegeName;

  const ChatUserSummary({
    required this.id,
    required this.name,
    required this.email,
    this.collegeName,
  });
}
