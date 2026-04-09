import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/data/chat_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/chat_models.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoom room;

  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _service = ChatService(SupabaseConfig.client);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  RealtimeChannel? _channel;
  List<ChatMessage> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final messages = await _service.fetchMessages(widget.room.id, limit: 120);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 24,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _subscribe() {
    _channel?.unsubscribe();
    _channel = SupabaseConfig.client
        .channel('chat_room_${widget.room.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: widget.room.id,
        ),
        callback: (payload) {
          _loadMessages();
        },
      )
      ..subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _service.sendMessage(roomId: widget.room.id, body: text);
    _scrollToBottom();
  }

  Future<void> _showMembers() async {
    final members = await _service.fetchRoomMembers(widget.room.id);
    final allUsers = await _service.fetchSemesterUsers(widget.room.semesterId);
    final current = SupabaseConfig.client.auth.currentUser;
    final existingIds = members.map((m) => m.id).toSet();
    final available = allUsers
        .where((u) => !existingIds.contains(u.id) && u.id != current?.id)
        .toList();
    if (!mounted) return;
    final selected = <String>{};
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Group members', 'समूह सदस्य'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (members.isNotEmpty)
                    ...members.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white70),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style:
                                        const TextStyle(color: Colors.white),
                                  ),
                                  if ((member.collegeName ?? '').isNotEmpty)
                                    Text(
                                      member.collegeName!,
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('Add members', 'सदस्य थप्नुहोस्'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (available.isEmpty)
                    Text(
                      context.tr(
                        'No more classmates to add.',
                        'थप्न सकिने सहपाठी छैन।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white54),
                    )
                  else
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        itemCount: available.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Color(0xFF1E2A44)),
                        itemBuilder: (context, index) {
                          final user = available[index];
                          final checked = selected.contains(user.id);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(user.id);
                                } else {
                                  selected.remove(user.id);
                                }
                              });
                            },
                            activeColor: const Color(0xFF4FA3C7),
                            title: Text(
                              user.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              [
                                user.email,
                                if ((user.collegeName ?? '').isNotEmpty)
                                  user.collegeName!,
                              ].join(' • '),
                              style: const TextStyle(color: Colors.white54),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (available.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selected.isEmpty) return;
                          Navigator.of(context).pop();
                          await _service.addMembers(
                            roomId: widget.room.id,
                            memberIds: selected.toList(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FA3C7),
                          foregroundColor: const Color(0xFF0B1220),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.tr('Add selected', 'छानिएका थप्नुहोस्'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = SupabaseConfig.client.auth.currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: Text(
          widget.room.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        actions: [
          if (!widget.room.isPublic)
            IconButton(
              onPressed: _showMembers,
              icon: const Icon(Icons.group, color: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = currentUser?.id == message.senderId;
                      return _ChatBubble(message: message, isMe: isMe);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0B1220),
                border: Border(top: BorderSide(color: Color(0xFF1E2A44))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocus,
                      style: const TextStyle(color: Colors.white),
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: context.tr(
                          'Write a message...',
                          'सन्देश लेख्नुहोस्...',
                        ),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Color(0xFF4FA3C7)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        isMe ? const Color(0xFF1E3A8A) : const Color(0xFF111827);
    final tag = [
      isMe ? context.tr('You', 'तपाईं') : message.senderName,
      if ((message.collegeName ?? '').isNotEmpty) message.collegeName!,
    ].join(' • ');
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF4FA3C7),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              message.body,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
