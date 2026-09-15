import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../screens/status/status_screen.dart';
import '../../screens/calls/call_screen.dart';
import '../../services/call_service.dart';
import '../../services/app_localizations.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;


  // USER CACHE — resolves direct-chat participants

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _inFlight = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentIndex = _tabController.index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider =
          Provider.of<AuraAuthProvider>(context, listen: false);
      final chatProvider =
          Provider.of<ChatProvider>(context, listen: false);

      if (authProvider.mockUserId != null) {
        chatProvider.setMockUser(authProvider.mockUserId!);
      } else {
        chatProvider.loadChats();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  // HELPERS

  String get _myUid {
    final auth = Provider.of<AuraAuthProvider>(context, listen: false);
    final fromProvider = auth.currentUserId ?? auth.mockUserId;
    if (fromProvider != null && fromProvider.isNotEmpty) {
      return fromProvider;
    }
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  Future<void> _fetchOtherUser(String uid) async {
    if (uid.isEmpty) return;
    if (_userCache.containsKey(uid)) return;
    if (_inFlight.contains(uid)) return;

    _inFlight.add(uid);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        _userCache[uid] = {
          'uid': uid,
          'username': (d['username'] ?? '') as String,
          'display_name': (d['display_name'] ??
                  d['username'] ??
                  d['name'] ??
                  'Unknown') as String,
          'avatar_url': d['avatar_url'],
          'email': d['email'],
          'is_bot': d['is_bot'] == true,
        };
      } else {
        _userCache[uid] = {
          'uid': uid,
          'username': '',
          'display_name': 'User',
          'avatar_url': null,
          'email': null,
          'is_bot': false,
        };
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('fetchOtherUser error ($uid): $e');
      _userCache[uid] = {
        'uid': uid,
        'username': '',
        'display_name': 'User',
        'avatar_url': null,
        'email': null,
        'is_bot': false,
      };
      if (mounted) setState(() {});
    } finally {
      _inFlight.remove(uid);
    }
  }


  // BUILD

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF0A0A0F),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
                  title: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ).createShader(bounds),
                    child: const Text(
                      'AURA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.1),
                          const Color(0xFF06B6D4).withOpacity(0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/global_search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onPressed: () => _showMenu(context),
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.4),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(text: AppLocalizations.get('chats')),
                    Tab(text: AppLocalizations.get('status')),
                    Tab(text: AppLocalizations.get('calls')),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildChatsTab(),
              _buildStatusTab(),
              _buildCallsTab(),
            ],
          ),
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget? _buildFAB() {
    switch (_currentIndex) {
      case 0:
        return _glowFAB(
          icon: Icons.chat_bubble,
          onPressed: () => _showNewChatOptions(context),
        );
      case 1:
        return _glowFAB(
          icon: Icons.camera_alt,
          onPressed: () => _showAddStatusOptions(context),
        );
      case 2:
        return _glowFAB(
          icon: Icons.add_call,
          onPressed: () => _showNewCallOptions(context),
        );
      default:
        return null;
    }
  }

  Widget _glowFAB({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }


  // CHATS TAB

  Widget _buildChatsTab() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
            ),
          );
        }

        if (chatProvider.chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.white.withOpacity(0.1),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.get('no_chats'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.get('start_conversation'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: chatProvider.chats.length,
          itemBuilder: (context, index) {
            return _buildChatTile(chatProvider.chats[index]);
          },
        );
      },
    );
  }


  // CHAT TILE

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final chatId = chat['id'] as String? ?? '';
    final chatType = chat['type'] as String? ?? 'direct';
    final isGroup = chatType == 'group';
    final isChannel = chatType == 'channel';
    final isBot = chatType == 'bot' || chat['is_bot'] == true;
    final isDirect = chatType == 'direct';

    final myUid = _myUid;

   
    String name;
    String? avatar;
    String? otherUserId;

    if (isDirect) {
      final participants = List<String>.from(chat['participants'] ?? []);
      otherUserId = participants.firstWhere(
        (id) => id != myUid,
        orElse: () => '',
      );

      if (otherUserId.isNotEmpty && !_userCache.containsKey(otherUserId)) {
        // Kick off async; setState will rebuild when it lands
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchOtherUser(otherUserId!);
        });
      }

      final cached =
          otherUserId.isNotEmpty ? _userCache[otherUserId] : null;

      if (cached != null) {
        name = cached['display_name'] as String? ?? 'User';
        avatar = cached['avatar_url'] as String?;
      } else {
        name = 'Loading...';
        avatar = null;
      }
    } else {
      name = (chat['name'] ?? chat['title'] ?? 'Unknown') as String;
      avatar = chat['avatar_url'] as String?;
    }

    final lastMessage = chat['last_message'] ?? '';

    // ─── Unread count (correct field) ──────────────────────────
    final unreadCounts = chat['unread_counts'] as Map<String, dynamic>?;
    final unread = (unreadCounts?[myUid] as num?)?.toInt() ?? 0;

    // ─── Route ─────────────────────────────────────────────────
    String route;
    Map<String, dynamic> routeArgs;
    if (isBot) {
      route = '/bot';
      routeArgs = {'chatId': chatId, 'botName': name};
    } else if (isChannel) {
      route = '/channel';
      routeArgs = {'channelId': chatId, 'channelName': name};
    } else {
      route = '/chat';
      routeArgs = {
        'chatId': chatId,
        'chatName': name,
        'chatAvatar': avatar,
        'isGroup': isGroup,
        'otherUserId': otherUserId,
      };
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF1a103c),
            backgroundImage: (avatar != null && avatar.isNotEmpty)
                ? NetworkImage(avatar)
                : null,
            onBackgroundImageError: (_, __) {},
            child: (avatar == null || avatar.isEmpty)
                ? Icon(
                    isChannel
                        ? Icons.campaign
                        : isGroup
                            ? Icons.group
                            : isBot
                                ? Icons.smart_toy
                                : Icons.person,
                    color: const Color(0xFF8B5CF6),
                    size: 22,
                  )
                : null,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isChannel) _pill('CHANNEL', const Color(0xFF8B5CF6)),
            if (isGroup) _pill('GROUP', const Color(0xFF06B6D4)),
            if (isBot) _pill('BOT', const Color(0xFF8B5CF6)),
          ],
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unread > 0
                ? Colors.white.withOpacity(0.75)
                : Colors.white.withOpacity(0.4),
            fontSize: 13,
            fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Now',
              style: TextStyle(
                color: unread > 0
                    ? const Color(0xFF8B5CF6)
                    : Colors.white.withOpacity(0.3),
                fontSize: 11,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          Navigator.pushNamed(context, route, arguments: routeArgs);
        },
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab() => const StatusScreen();

  Widget _buildCallsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap + to start a call',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }


  // NEW CHAT SHEET

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.person_add,
              label: AppLocalizations.get('new_chat'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/global_search');
              },
            ),
            _buildOptionTile(
              icon: Icons.group_add,
              label: AppLocalizations.get('new_group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_group');
              },
            ),
            _buildOptionTile(
              icon: Icons.campaign,
              label: AppLocalizations.get('new_channel'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_channel');
              },
            ),
          ],
        ),
      ),
    );
  }


  // STATUS SHEET

  void _showAddStatusOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.camera_alt,
              label: AppLocalizations.get('camera'),
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.photo_library,
              label: AppLocalizations.get('gallery'),
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.text_fields,
              label: AppLocalizations.get('text_status'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }


  // NEW CALL SHEET

  void _showNewCallOptions(BuildContext context) {
    final channelName = CallService.generateChannelName();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Text(
                    'Share this code to join',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    channelName,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.person_search,
              label: 'Call from Contacts',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CallScreen.pick()),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.phone,
              label: 'Start Voice Call',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen.active(
                      channelName: channelName,
                      isVideoCall: false,
                      targetUserId: 'unknown',
                      targetUserName: 'Unknown',
                    ),
                  ),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.videocam,
              label: 'Start Video Call',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen.active(
                      channelName: channelName,
                      isVideoCall: true,
                      targetUserId: 'unknown',
                      targetUserName: 'Unknown',
                    ),
                  ),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.dialpad,
              label: 'Join by Code',
              onTap: () {
                Navigator.pop(context);
                _showCallCodeDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCallCodeDialog(BuildContext context) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Join Call', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: codeController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter channel name...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen.active(
                      channelName: code,
                      isVideoCall: true,
                      targetUserId: 'unknown',
                      targetUserName: 'Unknown',
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }


  // ⋮ MENU

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _handle(),
              const SizedBox(height: 18),
              _menuTile(
                icon: Icons.bookmark,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Saved Messages',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/saved_messages');
                },
              ),
              _menuTile(
                icon: Icons.settings,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Settings',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              _menuTile(
                icon: Icons.person,
                iconColor: const Color(0xFF06B6D4),
                label: 'Profile',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              _menuTile(
                icon: Icons.smart_toy,
                iconColor: const Color(0xFF8B5CF6),
                label: 'BotCreator',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, '/bot_creator');
                },
              ),
              _menuTile(
                icon: Icons.logout,
                iconColor: const Color(0xFFEF4444),
                label: 'Log Out',
                labelColor: const Color(0xFFEF4444),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _confirmSignOut(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Log out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will need to sign in again to use AURA Chat.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    final authProvider =
        Provider.of<AuraAuthProvider>(context, listen: false);
    try {
      await authProvider.signOut();
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }


  // SHARED UI

  Widget _handle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF8B5CF6),
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
