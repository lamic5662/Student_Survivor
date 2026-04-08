import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class AiService {
  final SupabaseClient _client;

  AiService(this._client);

  static const String _conversationCacheKey = 'ai_conversations_v1';
  static const String _messageCachePrefix = 'ai_messages_v1_';

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
    final id = data['id']?.toString() ?? '';
    if (id.isNotEmpty) {
      await _appendCachedConversation(
        userId: user.id,
        conversation: {
          'id': id,
          'title': title ?? 'Study Session',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
    }
    return id;
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
    await _appendCachedMessage(
      conversationId: conversationId,
      role: 'user',
      content: message,
    );

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
      await _appendCachedMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: reply,
      );
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
    await _appendCachedMessage(
      conversationId: conversationId,
      role: role,
      content: trimmed,
    );
  }

  Future<List<AiHistoryItem>> fetchRecentUserMessages({
    int limit = 10,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    try {
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
    } catch (_) {
      return _loadCachedHistory(user.id, limit: limit);
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversations({
    int limit = 20,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    try {
      final rows = await _client
          .from('ai_conversations')
          .select('id,title,created_at,updated_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      final conversations = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      await _cacheConversations(user.id, conversations);
      return conversations;
    } catch (_) {
      final cached = await _loadCachedConversations(user.id);
      if (cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversationMessages(
    String conversationId, {
    int limit = 200,
  }) async {
    if (conversationId.isEmpty) {
      return [];
    }
    try {
      final rows = await _client
          .from('ai_messages')
          .select('role,content,created_at')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);
      final messages = (rows as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      await _cacheMessages(conversationId, messages);
      return messages;
    } catch (_) {
      final cached = await _loadCachedMessages(conversationId);
      if (cached.isNotEmpty) {
        return cached.take(limit).toList();
      }
      rethrow;
    }
  }

  Future<List<AiHistoryItem>> fetchUserHistory({
    int limit = 100,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return [];
    }
    try {
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
    } catch (_) {
      return _loadCachedHistory(user.id, limit: limit);
    }
  }

  Future<void> clearUserHistory() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    final conversationIds = await _fetchUserConversationIds(user.id);
    if (conversationIds.isNotEmpty) {
      await _client
          .from('ai_messages')
          .delete()
          .inFilter('conversation_id', conversationIds);
    }
    await _client.from('ai_conversations').delete().eq('user_id', user.id);
    await _cacheConversations(user.id, const []);
    for (final id in conversationIds) {
      await _clearCachedMessages(id);
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated.');
    }
    if (conversationId.isEmpty) return;
    await _client
        .from('ai_messages')
        .delete()
        .eq('conversation_id', conversationId);
    await _client
        .from('ai_conversations')
        .delete()
        .eq('id', conversationId)
        .eq('user_id', user.id);
    await _removeCachedConversation(user.id, conversationId);
    await _clearCachedMessages(conversationId);
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

  Future<void> _cacheConversations(
    String userId,
    List<Map<String, dynamic>> conversations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${userId}_$_conversationCacheKey',
        jsonEncode(conversations),
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadCachedConversations(
    String userId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${userId}_$_conversationCacheKey');
      if (raw == null || raw.isEmpty) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _cacheMessages(
    String conversationId,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_messageCachePrefix$conversationId',
        jsonEncode(messages),
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _loadCachedMessages(
    String conversationId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_messageCachePrefix$conversationId');
      if (raw == null || raw.isEmpty) return [];
      final data = jsonDecode(raw) as List<dynamic>;
      return data
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _appendCachedConversation({
    required String userId,
    required Map<String, dynamic> conversation,
  }) async {
    final list = await _loadCachedConversations(userId);
    list.removeWhere((item) => item['id'] == conversation['id']);
    list.insert(0, conversation);
    await _cacheConversations(userId, list);
  }

  Future<void> _appendCachedMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    try {
      final list = await _loadCachedMessages(conversationId);
      list.add({
        'role': role,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (list.length > 200) {
        list.removeRange(0, list.length - 200);
      }
      await _cacheMessages(conversationId, list);
    } catch (_) {}
  }

  Future<List<AiHistoryItem>> _loadCachedHistory(
    String userId, {
    required int limit,
  }) async {
    final conversations = await _loadCachedConversations(userId);
    if (conversations.isEmpty) return [];
    final items = <AiHistoryItem>[];
    for (final convo in conversations) {
      final id = convo['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final messages = await _loadCachedMessages(id);
      for (final message in messages) {
        if (message['role']?.toString() != 'user') continue;
        final text = message['content']?.toString() ?? '';
        if (text.trim().isEmpty) continue;
        final createdAt = message['created_at'] == null
            ? null
            : DateTime.tryParse(message['created_at'].toString());
        items.add(AiHistoryItem(text: text, createdAt: createdAt));
      }
    }
    items.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return items.take(limit).toList();
  }

  Future<void> _removeCachedConversation(
    String userId,
    String conversationId,
  ) async {
    try {
      final list = await _loadCachedConversations(userId);
      list.removeWhere((item) => item['id'] == conversationId);
      await _cacheConversations(userId, list);
    } catch (_) {}
  }

  Future<void> _clearCachedMessages(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_messageCachePrefix$conversationId');
    } catch (_) {}
  }
}
