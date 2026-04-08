import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/chat_models.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService(this._client);

  Future<ChatRoom?> getOrCreatePublicRoom({
    required String semesterId,
    required String semesterName,
  }) async {
    final row = await _client
        .from('chat_rooms')
        .select()
        .eq('semester_id', semesterId)
        .eq('type', 'public')
        .maybeSingle();
    if (row != null) {
      return _mapRoom(row);
    }
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final created = await _client
          .from('chat_rooms')
          .insert({
            'type': 'public',
            'semester_id': semesterId,
            'name': '$semesterName Public Chat',
            'created_by': user.id,
          })
          .select()
          .maybeSingle();
      if (created != null) {
        return _mapRoom(created);
      }
    } catch (_) {
      // Another user might have created the public room; refetch.
    }
    final fallback = await _client
        .from('chat_rooms')
        .select()
        .eq('semester_id', semesterId)
        .eq('type', 'public')
        .maybeSingle();
    if (fallback == null) return null;
    return _mapRoom(fallback);
  }

  Future<List<ChatRoom>> fetchGroupRooms() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('chat_members')
        .select('room:chat_rooms(*)')
        .eq('user_id', user.id);
    final rooms = <ChatRoom>[];
    for (final row in rows as List<dynamic>) {
      final room = row['room'];
      if (room is Map<String, dynamic>) {
        rooms.add(_mapRoom(room));
      }
    }
    rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rooms;
  }

  Future<List<ChatMessage>> fetchMessages(String roomId,
      {int limit = 50}) async {
    final rows = await _client
        .from('chat_messages')
        .select(
          'id,room_id,sender_id,body,created_at,'
          'sender:profiles(full_name,college_name)',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .limit(limit);
    return (rows as List<dynamic>)
        .map((row) => _mapMessage(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendMessage({
    required String roomId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('chat_messages').insert({
      'room_id': roomId,
      'sender_id': user.id,
      'body': body,
    });
  }

  Future<List<ChatUserSummary>> fetchSemesterUsers(String semesterId) async {
    final rows = await _client
        .from('profiles')
        .select('id,full_name,email,college_name')
        .eq('semester_id', semesterId)
        .order('full_name', ascending: true);
    return (rows as List<dynamic>)
        .map((row) => ChatUserSummary(
              id: row['id']?.toString() ?? '',
              name: row['full_name']?.toString().trim().isNotEmpty == true
                  ? row['full_name']?.toString() ?? 'Student'
                  : 'Student',
              email: row['email']?.toString() ?? '',
              collegeName: row['college_name']?.toString(),
            ))
        .where((user) => user.id.isNotEmpty)
        .toList();
  }

  Future<ChatRoom?> createGroup({
    required String semesterId,
    required String name,
    required List<String> memberIds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final created = await _client
        .from('chat_rooms')
        .insert({
          'type': 'group',
          'semester_id': semesterId,
          'name': name,
          'created_by': user.id,
        })
        .select()
        .maybeSingle();
    if (created == null) return null;
    final room = _mapRoom(created);

    final members = <Map<String, dynamic>>[];
    members.add({
      'room_id': room.id,
      'user_id': user.id,
      'role': 'admin',
    });
    for (final id in memberIds) {
      if (id == user.id) continue;
      members.add({
        'room_id': room.id,
        'user_id': id,
        'role': 'member',
      });
    }
    if (members.isNotEmpty) {
      await _client.from('chat_members').insert(members);
    }
    return room;
  }

  Future<void> addMembers({
    required String roomId,
    required List<String> memberIds,
  }) async {
    if (memberIds.isEmpty) return;
    final rows = memberIds
        .map((id) => {
              'room_id': roomId,
              'user_id': id,
              'role': 'member',
            })
        .toList();
    await _client.from('chat_members').insert(rows);
  }

  Future<List<ChatUserSummary>> fetchRoomMembers(String roomId) async {
    final rows = await _client
        .from('chat_members')
        .select('user:profiles(id,full_name,email,college_name)')
        .eq('room_id', roomId);
    final members = <ChatUserSummary>[];
    for (final row in rows as List<dynamic>) {
      final user = row['user'];
      if (user is Map<String, dynamic>) {
        final id = user['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        members.add(
          ChatUserSummary(
            id: id,
            name: user['full_name']?.toString().trim().isNotEmpty == true
                ? user['full_name']?.toString() ?? 'Student'
                : 'Student',
            email: user['email']?.toString() ?? '',
            collegeName: user['college_name']?.toString(),
          ),
        );
      }
    }
    return members;
  }

  ChatRoom _mapRoom(Map<String, dynamic> row) {
    return ChatRoom(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Chat',
      type: row['type']?.toString() ?? 'public',
      semesterId: row['semester_id']?.toString() ?? '',
      createdBy: row['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  ChatMessage _mapMessage(Map<String, dynamic> row) {
    final sender = row['sender'];
    final senderName = sender is Map<String, dynamic>
        ? sender['full_name']?.toString() ?? 'Student'
        : 'Student';
    final collegeName = sender is Map<String, dynamic>
        ? sender['college_name']?.toString()
        : null;
    return ChatMessage(
      id: row['id']?.toString() ?? '',
      roomId: row['room_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      senderName: senderName.isNotEmpty ? senderName : 'Student',
      collegeName: collegeName,
      body: row['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
