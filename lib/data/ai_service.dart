import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class AiService {
  final SupabaseClient _client;

  AiService(this._client);

  Future<String?> ensureConversationId(
    String? currentId, {
    String? title,
  }) async {
    if (currentId != null && currentId.isNotEmpty) {
      return currentId;
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return createConversation(title: title);
  }

  Future<String> createConversation({String? title}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    final data = await _client
        .from('ai_conversations')
        .insert({
          'user_id': user.id,
          'title': title ?? 'Study Session',
        })
        .select('id')
        .single();
    return data['id']?.toString() ?? '';
  }

  Future<String> sendMessage({
    required String conversationId,
    required String message,
    String? mode,
  }) async {
    await _client.from('ai_messages').insert({
      'conversation_id': conversationId,
      'role': 'user',
      'content': message,
    });

    final response = await _client.functions.invoke(
      'ai-chat',
      body: {
        'message': message,
        'mode': mode,
        'conversation_id': conversationId,
      },
    );

    final data = response.data as Map<String, dynamic>? ?? {};
    final reply = data['reply']?.toString() ?? '';
    if (reply.isNotEmpty) {
      await _client.from('ai_messages').insert({
        'conversation_id': conversationId,
        'role': 'assistant',
        'content': reply,
      });
    }
    return reply;
  }

  Future<void> logMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _client.from('ai_messages').insert({
      'conversation_id': conversationId,
      'role': role,
      'content': trimmed,
    });
  }

  Future<List<AiHistoryItem>> fetchRecentUserMessages({
    int limit = 10,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    final conversationIds = await _fetchUserConversationIds(user.id);
    if (conversationIds.isEmpty) {
      return [];
    }
    final data = await _client
        .from('ai_messages')
        .select('content,created_at')
        .eq('role', 'user')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List<dynamic>)
        .map(
          (row) => AiHistoryItem(
            text: row['content']?.toString() ?? '',
            createdAt: row['created_at'] == null
                ? null
                : DateTime.tryParse(row['created_at'].toString()),
          ),
        )
        .where((item) => item.text.trim().isNotEmpty)
        .toList();
  }

  Future<List<AiHistoryItem>> fetchUserHistory({
    int limit = 100,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    final conversationIds = await _fetchUserConversationIds(user.id);
    if (conversationIds.isEmpty) {
      return [];
    }
    final data = await _client
        .from('ai_messages')
        .select('content,created_at')
        .eq('role', 'user')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List<dynamic>)
        .map(
          (row) => AiHistoryItem(
            text: row['content']?.toString() ?? '',
            createdAt: row['created_at'] == null
                ? null
                : DateTime.tryParse(row['created_at'].toString()),
          ),
        )
        .where((item) => item.text.trim().isNotEmpty)
        .toList();
  }

  Future<void> clearUserHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    await _client.from('ai_conversations').delete().eq('user_id', user.id);
  }

  Future<int> deleteRecentUserMessages({int limit = 10}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    final conversationIds = await _fetchUserConversationIds(user.id);
    if (conversationIds.isEmpty) {
      return 0;
    }
    final data = await _client
        .from('ai_messages')
        .select('id')
        .eq('role', 'user')
        .inFilter('conversation_id', conversationIds)
        .order('created_at', ascending: false)
        .limit(limit);
    final ids = (data as List<dynamic>)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    if (ids.isEmpty) {
      return 0;
    }
    await _client.from('ai_messages').delete().inFilter('id', ids);
    return ids.length;
  }

  Future<List<String>> _fetchUserConversationIds(String userId) async {
    final rows = await _client
        .from('ai_conversations')
        .select('id')
        .eq('user_id', userId);
    return (rows as List<dynamic>)
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
