import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/invitation_service.dart';
import '../../utils/verified_badge.dart';

class ChannelInfoScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? chatAvatar;

  const ChannelInfoScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.chatAvatar,
  });

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  bool _isLoading = false;

  Future<void> _shareInvitationLink() async {
    final preview = await InvitationService.getInvitationPreview(widget.chatId);
    if (preview == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active invitation link')),
        );
      }
      return;
    }

    final chatName = preview['chat_name'] ?? 'Unknown';
    final memberCount = preview['member_count'] ?? 0;
    final link = preview['link'] ?? '';

    final text = 'Join $chatName on AURA Chat!\n\n'
        'Channel\n'
        'Members: $memberCount\n\n'
        'Tap to join: $link';

    await Share.share(text);
  }

  void _startCall({required bool video}) {
    Navigator.pushNamed(context, '/call_screen', arguments: {
      'chatId': widget.chatId,
      'chatName': widget.chatName,
      'isVideo': video,
      'isGroup': true,
    });
  }

  Future<void> _showAddMembersDialog() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    List<Map<String, dynamic>> selectedUsers = [];

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Members',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by username or phone...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.isEmpty) {
                      setModalState(() => searchResults = []);
                      return;
                    }
                    final results = await _searchUsers(query);
                    setModalState(() => searchResults = results);
                  },
                ),
                const SizedBox(height: 16),
                if (selectedUsers.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedUsers.length,
                      itemBuilder: (context, index) {
                        final user = selectedUsers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  _buildMemberAvatar(user['avatar_url'], user['username']),
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user['username'] ?? 'Unknown',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: searchResults.isEmpty
                    ? Center(
                        child: Text(
                          searchController.text.isEmpty
                            ? 'Type to search users'
                            : 'No users found',
                          style: TextStyle(color: Colors.white.withOpacity(0.3)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          final isSelected = selectedUsers.any((u) => u['id'] == user['id']);
                          return ListTile(
                            leading: _buildMemberAvatar(user['avatar_url'], user['username']),
                            title: Text(
                              user['username'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              user['phone'] ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.4)),
                            ),
                            trailing: isSelected
                              ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
                              : const Icon(Icons.add_circle_outline, color: Colors.white54),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedUsers.removeWhere((u) => u['id'] == user['id']);
                                } else {
                                  selectedUsers.add(user);
                                }
                              });
                            },
                          );
                        },
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedUsers.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _addMembers(selectedUsers);
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Add ${selectedUsers.length} Member${selectedUsers.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

      final snapshot = await firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((u) => u['id'] != currentUserId)
          .toList();
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<void> _addMembers(List<Map<String, dynamic>> users) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final chatRef = firestore.collection('chats').doc(widget.chatId);

      final blockedUsers = <Map<String, dynamic>>[];
      final addedUsers = <Map<String, dynamic>>[];

      for (final user in users) {
        final userId = user['id'] as String;
        final userDoc = await firestore.collection('users').doc(userId).get();
        final privacy = userDoc.data()?['privacy_settings'] as Map<String, dynamic>?;
        final allowAddToGroup = privacy?['allow_add_to_group'] ?? true;

        if (!allowAddToGroup) {
          blockedUsers.add(user);
        } else {
          addedUsers.add(user);
          await chatRef.update({
            'participants': FieldValue.arrayUnion([userId]),
            'participants_data.$userId': {
              'role': 'member',
              'joined_at': FieldValue.serverTimestamp(),
            },
            'member_count': FieldValue.increment(1),
          });

          await firestore.collection('users').doc(userId).collection('notifications').add({
            'type': 'added_to_channel',
            'chat_id': widget.chatId,
            'chat_name': widget.chatName,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }

      if (mounted) {
        if (addedUsers.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${addedUsers.length} member(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (blockedUsers.isNotEmpty) {
          _showBlockedUsersDialog(blockedUsers);
        }
      }
    } catch (e) {
      debugPrint('Add members error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add members: $e')),
        );
      }
    }
  }

  void _showBlockedUsersDialog(List<Map<String, dynamic>> blockedUsers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Cannot Add Users', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'These users have disabled being added to groups/channels:',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 12),
            ...blockedUsers.map((user) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _buildMemberAvatar(user['avatar_url'], user['username']),
                  const SizedBox(width: 8),
                  Text(
                    user['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 16),
            const Text(
              'Send them the invitation link instead.',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareInvitationLink();
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Send Link'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberOptions(String memberId, String memberName, String memberRole, bool isMe, bool canManage) async {
    if (isMe) return;
    if (!canManage) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final myRole = await _getMyRole();
    if (myRole == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(memberName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (myRole == 'owner' && memberRole == 'member')
              ListTile(
                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6))),
                title: const Text('Promote to Admin', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); chatProvider.promoteToAdmin(widget.chatId, memberId); },
              ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.remove_circle, color: Colors.orange)),
              title: const Text('Kick', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _confirmKick(memberId, memberName); },
            ),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.block, color: Colors.red)),
              title: const Text('Ban', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _confirmBan(memberId, memberName); },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _getMyRole() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return null;

    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return (data['participants_data']?[userId]?['role'] ?? 'member') as String;
  }

  void _confirmKick(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Kick $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed from this channel.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Provider.of<ChatProvider>(context, listen: false).kickMember(widget.chatId, memberId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Kick'),
          ),
        ],
      ),
    );
  }

  void _confirmBan(String memberId, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Ban $memberName?', style: const TextStyle(color: Colors.white)),
        content: const Text('They will be removed and banned from rejoining.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Provider.of<ChatProvider>(context, listen: false).banMember(widget.chatId, memberId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
  }

  void _showSettings(String currentRole) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ChannelSettingsSheet(chatId: widget.chatId, currentRole: currentRole),
    );
  }

  Future<void> _leaveChannel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Leave Channel?', style: TextStyle(color: Colors.white)),
        content: const Text('You will no longer receive messages from this channel.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Leave')),
        ],
      ),
    );

    if (confirmed == true) {
      await Provider.of<ChatProvider>(context, listen: false).leaveChat(widget.chatId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Channel Info'),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final myRole = (data?['participants_data']?[userId]?['role'] ?? 'member') as String;
              final canManage = myRole == 'owner' || myRole == 'admin';
              final isOwner = myRole == 'owner';

              return Row(
                children: [
                  if (isOwner || myRole == 'admin') ...[
                    IconButton(
                      icon: const Icon(Icons.videocam, color: Colors.white70),
                      onPressed: () => _startCall(video: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.white70),
                      onPressed: () => _startCall(video: false),
                    ),
                  ],
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.person_add, color: Colors.white70),
                      onPressed: () => _showAddMembersDialog(),
                    ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    onPressed: _shareInvitationLink,
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: () => _showSettings(myRole),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          final memberCount = data['member_count'] ?? participants.length;
          final description = data['description'] ?? '';
          final createdByPhone = data['created_by_phone'] as String?;
          final myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;
          final canManage = myRole == 'owner' || myRole == 'admin';
          final isOwner = myRole == 'owner';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      _buildAvatar(data['avatar_url']),
                      const SizedBox(height: 12),
                      VerifiedUsername(
                        username: data['name'] ?? 'Unknown',
                        phoneNumber: createdByPhone,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        badgeSize: 16,
                        spacing: 6,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                      ],
                      const SizedBox(height: 4),
                      Text('$memberCount members \u2022 Channel', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(child: _buildActionButton(icon: Icons.share, label: 'Invite', onTap: _shareInvitationLink)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildActionButton(icon: Icons.exit_to_app, label: 'Leave', color: Colors.red, onTap: _leaveChannel)),
                  ],
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(icon: Icons.campaign, label: 'Channel Type', value: 'Broadcast'),
                      _buildInfoRow(icon: Icons.admin_panel_settings, label: 'Messaging', value: 'Admin-only'),
                      _buildInfoRow(icon: Icons.visibility, label: 'Members can', value: 'View only'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (canManage) ...[
                  Text('Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6).withOpacity(0.8), letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _buildSettingsPreview(data),
                  const SizedBox(height: 24),
                ],

                Text('Members ($memberCount)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6).withOpacity(0.8), letterSpacing: 1)),
                const SizedBox(height: 12),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Future.wait(participants.map((uid) async {
                    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                    final userData = doc.data() ?? {};
                    final role = (data['participants_data']?[uid]?['role'] ?? 'member') as String;
                    return {'uid': uid, ...userData, 'role': role};
                  })),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));

                    final users = snapshot.data!;
                    users.sort((a, b) {
                      final roleOrder = {'owner': 0, 'admin': 1, 'member': 2};
                      return (roleOrder[a['role']] ?? 3).compareTo(roleOrder[b['role']] ?? 3);
                    });

                    return Column(
                      children: users.map((user) {
                        final uid = user['uid'] as String;
                        final isMe = uid == userId;
                        final role = user['role'] as String;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _buildMemberAvatar(user['avatar_url'], user['username']),
                          title: Row(
                            children: [
                              Flexible(child: Text(user['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                              if (isMe) Padding(padding: const EdgeInsets.only(left: 8), child: Text('(You)', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12))),
                            ],
                          ),
                          subtitle: Text(
                            role == 'owner' ? 'Owner' : role == 'admin' ? 'Admin' : 'Subscriber',
                            style: TextStyle(color: role == 'owner' ? Colors.amber : role == 'admin' ? const Color(0xFF8B5CF6) : Colors.white54, fontSize: 12),
                          ),
                          trailing: !isMe && canManage && role != 'owner'
                            ? IconButton(icon: const Icon(Icons.more_vert, color: Colors.white54), onPressed: () => _showMemberOptions(uid, user['username'] ?? 'Unknown', role, isMe, canManage))
                            : null,
                          onTap: () {
                            if (!isMe) {
                              Navigator.pushNamed(context, '/public_profile', arguments: {
                                'userId': uid, 'username': user['username'], 'avatarUrl': user['avatar_url'], 'bio': user['bio'],
                              });
                            }
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: 40, backgroundImage: NetworkImage(avatarUrl), onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: const Color(0xFF1a103c),
      child: const Icon(Icons.campaign, size: 40, color: Color(0xFF8B5CF6)),
    );
  }

  Widget _buildMemberAvatar(String? avatarUrl, String? username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl), onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF1a103c),
      child: Text((username ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF8B5CF6)).withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (color ?? const Color(0xFF8B5CF6)).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? const Color(0xFF8B5CF6)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color ?? const Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7)))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSettingsPreview(Map<String, dynamic> data) {
    final settings = data['settings'] as Map<String, dynamic>? ?? {};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Column(
        children: [
          _buildSettingRow(icon: Icons.chat_bubble, label: 'Chat Enabled', value: !(settings['chat_disabled'] ?? false)),
          _buildSettingRow(icon: Icons.attach_file, label: 'File Sharing', value: !(settings['file_sharing_disabled'] ?? false)),
          _buildSettingRow(icon: Icons.poll, label: 'Polls', value: settings['polls_enabled'] ?? true),
          _buildSettingRow(icon: Icons.emoji_emotions, label: 'Reactions', value: settings['reactions_enabled'] ?? true),
        ],
      ),
    );
  }

  Widget _buildSettingRow({required IconData icon, required String label, required bool value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7)))),
          Icon(value ? Icons.check_circle : Icons.cancel, size: 18, color: value ? Colors.green : Colors.red),
        ],
      ),
    );
  }
}

class ChannelSettingsSheet extends StatefulWidget {
  final String chatId;
  final String currentRole;
  const ChannelSettingsSheet({super.key, required this.chatId, required this.currentRole});

  @override
  State<ChannelSettingsSheet> createState() => _ChannelSettingsSheetState();
}

class _ChannelSettingsSheetState extends State<ChannelSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final settings = data['settings'] as Map<String, dynamic>? ?? {};
        final isOwner = widget.currentRole == 'owner';

        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Channel Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildToggle(label: 'Disable Chat', subtitle: 'Only admins can send messages', value: settings['chat_disabled'] ?? false, onChanged: (v) => _updateSetting('chat_disabled', v)),
                    _buildToggle(label: 'Disable File Sharing', subtitle: 'Prevent members from sending files', value: settings['file_sharing_disabled'] ?? false, onChanged: (v) => _updateSetting('file_sharing_disabled', v)),
                    _buildToggle(label: 'Enable Polls', value: settings['polls_enabled'] ?? true, onChanged: (v) => _updateSetting('polls_enabled', v)),
                    _buildToggle(label: 'Enable Reactions', value: settings['reactions_enabled'] ?? true, onChanged: (v) => _updateSetting('reactions_enabled', v)),
                    _buildToggle(label: 'Allow Forwarding', value: settings['forwarding_enabled'] ?? true, onChanged: (v) => _updateSetting('forwarding_enabled', v)),
                    if (isOwner)
                      _buildToggle(label: 'Enable Voice Chat', value: settings['voice_chat_enabled'] ?? false, onChanged: (v) => _updateSetting('voice_chat_enabled', v)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggle({required String label, String? subtitle, required bool value, required ValueChanged<bool>? onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)) : null,
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF8B5CF6),
      ),
    );
  }

  Future<void> _updateSetting(String key, bool value) async {
    await Provider.of<ChatProvider>(context, listen: false).toggleSetting(widget.chatId, key, value);
  }
}
