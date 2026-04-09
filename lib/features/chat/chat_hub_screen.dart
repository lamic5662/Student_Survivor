import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/chat_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';
import 'package:student_survivor/models/chat_models.dart';
import 'package:student_survivor/features/chat/chat_room_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key});

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  final ChatService _service = ChatService(SupabaseConfig.client);
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  bool _loading = true;
  ChatRoom? _publicRoom;
  List<ChatRoom> _groupRooms = [];
  List<ChatUserSummary> _onlineUsers = [];
  String? _semesterId;
  RealtimeChannel? _presenceChannel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  Future<void> _loadFor(UserProfile profile) async {
    if (profile.semester.id.isEmpty) {
      setState(() {
        _loading = false;
        _publicRoom = null;
        _groupRooms = [];
        _onlineUsers = [];
      });
      return;
    }
    setState(() => _loading = true);
    final publicRoom = await _service.getOrCreatePublicRoom(
      semesterId: profile.semester.id,
      semesterName: profile.semester.name,
    );
    final groups = await _service.fetchGroupRooms();
    if (!mounted) return;
    setState(() {
      _publicRoom = publicRoom;
      _groupRooms = groups;
      _loading = false;
    });
  }

  void _maybeLoad(UserProfile profile) {
    if (_semesterId == profile.semester.id) {
      return;
    }
    _semesterId = profile.semester.id;
    _subscribePresence(profile);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFor(profile));
  }

  void _subscribePresence(UserProfile profile) {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null || profile.semester.id.isEmpty) return;
    _presenceChannel?.unsubscribe();
    _presenceChannel = SupabaseConfig.client.channel(
      'semester_presence_${profile.semester.id}',
      opts: RealtimeChannelConfig(
        key: user.id,
        enabled: true,
      ),
    )
      ..onPresenceSync((payload) => _updatePresence())
      ..onPresenceJoin((payload) => _updatePresence())
      ..onPresenceLeave((payload) => _updatePresence());

    _presenceChannel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _presenceChannel!.track({
          'user_id': user.id,
          'name': profile.name,
          'email': profile.email,
          'college_name': profile.collegeName,
        });
      }
    });
  }

  void _updatePresence() {
    final state = _presenceChannel?.presenceState() ?? <SinglePresenceState>[];
    final users = <String, ChatUserSummary>{};
    for (final entry in state) {
      for (final presence in entry.presences) {
        final payload = presence.payload as Map;
        final id = payload['user_id']?.toString() ?? entry.key;
        if (id.isEmpty) continue;
        users[id] = ChatUserSummary(
          id: id,
          name: payload['name']?.toString() ?? 'Student',
          email: payload['email']?.toString() ?? '',
          collegeName: payload['college_name']?.toString(),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _onlineUsers = users.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  void _openRoom(ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(room: room),
      ),
    );
  }

  Future<void> _showCreateGroup(UserProfile profile) async {
    if (profile.semester.id.isEmpty) return;
    final currentUser = SupabaseConfig.client.auth.currentUser;
    if (currentUser == null) return;
    final users = await _service.fetchSemesterUsers(profile.semester.id);
    final selectable = users.where((user) => user.id != currentUser.id).toList();
    if (!mounted) return;

    final nameController = TextEditingController();
    final emailController = TextEditingController();
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
                    context.tr('Create group chat', 'समूह च्याट बनाउनुहोस्'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.tr('Group name', 'समूह नाम'),
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText:
                                context.tr('Add by email', 'इमेलबाट थप्नुहोस्'),
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final email =
                              emailController.text.trim().toLowerCase();
                          if (email.isEmpty) return;
                          final match = selectable.firstWhere(
                            (user) => user.email.toLowerCase() == email,
                            orElse: () => const ChatUserSummary(
                              id: '',
                              name: '',
                              email: '',
                            ),
                          );
                          if (match.id.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.tr(
                                    'No student found with that email.',
                                    'त्यो इमेल भएको विद्यार्थी भेटिएन।',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() {
                            selected.add(match.id);
                          });
                        },
                        icon: const Icon(Icons.person_add_alt_1,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Add members', 'सदस्य थप्नुहोस्'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (selectable.isEmpty)
                    Text(
                      context.tr(
                        'No classmates found in this semester.',
                        'यो सेमेस्टरमा सहपाठी भेटिएन।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white54),
                    )
                  else
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        itemCount: selectable.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: Color(0xFF1E2A44)),
                        itemBuilder: (context, index) {
                          final user = selectable[index];
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(
                                  'Enter a group name.',
                                  'समूह नाम लेख्नुहोस्।',
                                ),
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop();
                        final room = await _service.createGroup(
                          semesterId: profile.semester.id,
                          name: name,
                          memberIds: selected.toList(),
                        );
                        if (!mounted || room == null) return;
                        await _loadFor(profile);
                        _openRoom(room);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4FA3C7),
                        foregroundColor: const Color(0xFF0B1220),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        context.tr('Create group', 'समूह बनाउनुहोस्'),
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
    return ValueListenableBuilder<UserProfile>(
      valueListenable: AppState.profile,
      builder: (context, profile, _) {
        _maybeLoad(profile);
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: const Color(0xFF070B14),
          appBar: AppBar(
            title: AnimatedOpacity(
              opacity: _showTitle ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                context.tr('Semester Chat', 'सेमेस्टर च्याट'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: _ChatBackdrop()),
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.of(context).padding.top +
                      kToolbarHeight -
                      12,
                  20,
                  28,
                ),
                children: [
                  if (profile.semester.id.isEmpty)
                    _GameCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                              'Select your semester first',
                              'पहिला सेमेस्टर चयन गर्नुहोस्',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'Chat is available after you choose a semester.',
                              'सेमेस्टर चयन गरेपछि मात्रै च्याट उपलब्ध हुन्छ।',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  else if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _GameCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111B2E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF1E2A44)),
                                ),
                                child: const Icon(Icons.public,
                                    color: Color(0xFF4FA3C7)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr(
                                        'Public semester chat',
                                        'सार्वजनिक सेमेस्टर च्याट',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.tr(
                                        'Only students from ${profile.semester.name}.',
                                        'केवल ${profile.semester.name} का विद्यार्थीहरू।',
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _publicRoom == null
                                  ? null
                                  : () => _openRoom(_publicRoom!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4FA3C7),
                                foregroundColor: const Color(0xFF0B1220),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                context.tr('Enter chat', 'च्याट खोल्नुहोस्'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _GameCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.circle,
                                  color: Color(0xFF22C55E), size: 10),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('Online now', 'अनलाइन विद्यार्थी'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const Spacer(),
                              Text(
                                '${_onlineUsers.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_onlineUsers.isEmpty)
                            Text(
                              context.tr(
                                'No classmates online yet.',
                                'अहिले कोही अनलाइन छैन।',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white54),
                            )
                          else
                            SizedBox(
                              height: _onlineUsers.length > 5 ? 120 : null,
                              child: SingleChildScrollView(
                                physics: _onlineUsers.length > 5
                                    ? const BouncingScrollPhysics()
                                    : const NeverScrollableScrollPhysics(),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _onlineUsers
                                      .map(
                                        (user) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: const Color(0xFF1E2A44),
                                            ),
                                          ),
                                      child: Text(
                                        [
                                          user.name,
                                          if ((user.collegeName ?? '')
                                              .isNotEmpty)
                                            user.collegeName!,
                                        ].join(' • '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('Your groups', 'तपाईंका समूहहरू'),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showCreateGroup(profile),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            context.tr('Create group', 'समूह बनाउनुहोस्'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_groupRooms.isEmpty)
                      Text(
                        context.tr(
                          'No private groups yet.',
                          'हाल निजी समूह छैन।',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white54),
                      )
                    else
                      ..._groupRooms.map(
                        (room) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GameCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111B2E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFF1E2A44)),
                                  ),
                                  child: const Icon(Icons.group,
                                      color: Color(0xFF4FA3C7)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr(
                                          'Private group chat',
                                          'निजी समूह च्याट',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _openRoom(room),
                                  icon: const Icon(Icons.arrow_forward_ios,
                                      color: Colors.white70, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B1220),
            Color(0xFF0B1B2A),
            Color(0xFF06090F),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _ChatGridPainter(),
      ),
    );
  }
}

class _ChatGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF4FA3C7),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}
