import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  final SupabaseClient _client;

  AiService(this._client);

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
}
