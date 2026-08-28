import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/verified_badge.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: userId)
            .orderBy('last_message_at', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final chats = snapshot.data!.docs;

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              chat['id'] = chats[index].id;

              final isGroupOrChannel = ['group', 'channel'].contains(chat['type']);
              final lastMessage = chat['last_message'] ?? '';
              final lastMessageType = chat['last_message_type'] ?? 'text';
              
              // FIXED: Robust timestamp parsing
              DateTime? lastMessageAt;
              if (chat['last_message_at'] != null) {
                final val = chat['last_message_at'];
                if (val is DateTime) {
                  lastMessageAt = val;
                } else if (val is Timestamp) {
                  lastMessageAt = val.toDate();
                } else if (val is String) {
                  lastMessageAt = DateTime.tryParse(val)?.toLocal();
                } else {
                  lastMessageAt = DateTime.tryParse(val.toString())?.toLocal();
                }
              }

              final unreadCount = chat['unread_count'] ?? 0;
              final isPinned = chat['is_pinned'] ?? false;

              if (isGroupOrChannel) {
                return _buildGroupOrChannelTile(
                  context,
                  chat,
                  lastMessage,
                  lastMessageType,
                  lastMessageAt,
                  unreadCount,
                  isPinned,
                );
              } else {
                return _buildDirectChatTile(
                  context,
                  chat,
                  lastMessage,
                  lastMessageType,
                  lastMessageAt,
                  unreadCount,
                  isPinned,
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildGroupOrChannelTile(
    BuildContext context,
    Map<String, dynamic> chat,
    String lastMessage,
    String lastMessageType,
    DateTime? lastMessageAt,
    int unreadCount,
    bool isPinned,
  ) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final name = chat['name'] ?? 'Unknown';
    final avatarUrl = chat['avatar_url'] as String?;
    final type = chat['type'] as String? ?? 'group';
    final createdByEmail = chat['created_by_email'] as String?; // FIXED: phone → email

    return GestureDetector(
      onLongPress: () => _showChatOptions(context, chat, true),
      child: Slidable(
        key: ValueKey(chat['id']),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => chatProvider.archiveChat(chat['id']),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.archive,
              label: 'Archive',
            ),
            SlidableAction(
              onPressed: (_) => _showDeleteDialog(context, chat['id']),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Stack(
            children: [
              _buildAvatar(avatarUrl, name, type == 'channel'),
              if (isPinned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: VerifiedUsername(
                  username: name,
                  email: createdByEmail, // FIXED: phoneNumber → email
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  badgeSize: 14,
                  spacing: 4,
                ),
              ),
              if (lastMessageAt != null)
                Text(
                  _formatChatListTime(lastMessageAt),
                  style: TextStyle(
                    color: unreadCount > 0
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          subtitle: Row(
            children: [
              Expanded(
                child: Text(
                  _getMessagePreview(lastMessage, lastMessageType),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unreadCount > 0
                        ? Colors.white.withOpacity(0.8)
                        : Colors.white.withOpacity(0.5),
                    fontSize: 13,
                    fontWeight: unreadCount > 0
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          onTap: () {
            if (type == 'channel') {
              Navigator.pushNamed(
                context,
                '/channel',
                arguments: {
                  'channelId': chat['id'],
                  'channelName': name,
                },
              );
            } else {
              Navigator.pushNamed(
                context,
                '/chat',
                arguments: {
                  'chatId': chat['id'],
                  'chatName': name,
                  'isGroup': true,
                },
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDirectChatTile(
    BuildContext context,
    Map<String, dynamic> chat,
    String lastMessage,
    String lastMessageType,
    DateTime? lastMessageAt,
    int unreadCount,
    bool isPinned,
  ) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    // Get the other participant
    final participants = List<String>.from(chat['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != userId,
      orElse: () => '',
    );

    if (otherUserId.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['display_name'] ?? userData['username'] ?? 'Unknown';
        final avatarUrl = userData['avatar_url'] as String?;
        final email = userData['email'] as String?; // FIXED: phone → email
        final isOnline = userData['is_online'] as bool? ?? false;

        return GestureDetector(
          onLongPress: () => _showDirectChatOptions(context, chat['id'], displayName),
          child: Slidable(
            key: ValueKey(chat['id']),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) => chatProvider.archiveChat(chat['id']),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  icon: Icons.archive,
                  label: 'Archive',
                ),
                SlidableAction(
                  onPressed: (_) => _showDeleteDialog(context, chat['id']),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Stack(
                children: [
                  _buildAvatar(avatarUrl, displayName, false),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0A0A0F),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  if (isPinned)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: VerifiedUsername(
                      username: displayName,
                      email: email, // FIXED: phoneNumber → email
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      badgeSize: 14,
                      spacing: 4,
                    ),
                  ),
                  if (lastMessageAt != null)
                    Text(
                      _formatChatListTime(lastMessageAt),
                      style: TextStyle(
                        color: unreadCount > 0
                            ? const Color(0xFF8B5CF6)
                            : Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      _getMessagePreview(lastMessage, lastMessageType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unreadCount > 0
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {
                    'chatId': chat['id'],
                    'chatName': displayName,
                    'isGroup': false,
                    'otherUserId': otherUserId,
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String? url, String name, bool isChannel) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF1a103c),
      child: Icon(
        isChannel ? Icons.campaign : Icons.person,
        color: const Color(0xFF8B5CF6),
        size: 24,
      ),
    );
  }

  String _getMessagePreview(String message, String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎤 Voice message';
      case 'file':
        return '📎 File';
      case 'location':
        return '📍 Location';
      default:
        return message;
    }
  }

  // FIXED: Improved time formatting
  String _formatChatListTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = today.difference(messageDate).inDays;

    // Today
    if (diffDays == 0) {
      final diffMinutes = now.difference(dateTime).inMinutes;
      if (diffMinutes < 1) {
        return 'Now';
      } else if (diffMinutes < 60) {
        return '${diffMinutes}m';
      } else {
        // Show time for anything older than 1 hour today
        final hour = dateTime.hour.toString().padLeft(2, '0');
        final minute = dateTime.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }
    } 
    // Yesterday
    else if (diffDays == 1) {
      return 'Yesterday';
    } 
    // Within last 7 days
    else if (diffDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } 
    // This year
    else if (dateTime.year == now.year) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    } 
    // Different year
    else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
    }
  }

  void _showChatOptions(BuildContext context, Map<String, dynamic> chat, bool isGroup) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
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
            ListTile(
              leading: const Icon(Icons.push_pin, color: Color(0xFF8B5CF6)),
              title: const Text('Pin Chat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false)
                    .togglePinChat(chat['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.blue),
              title: const Text('Archive', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false)
                    .archiveChat(chat['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, chat['id']);
              },
            ),
            if (isGroup)
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.orange),
                title: const Text('Leave Group', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _showLeaveDialog(context, chat['id']);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showDirectChatOptions(BuildContext context, String chatId, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
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
            ListTile(
              leading: const Icon(Icons.push_pin, color: Color(0xFF8B5CF6)),
              title: const Text('Pin Chat', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false)
                    .togglePinChat(chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive, color: Colors.blue),
              title: const Text('Archive', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false)
                    .archiveChat(chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, chatId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orange),
              title: const Text('Block User', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog(context, chatId, userName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Delete Chat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete the chat from your list. Messages will still be visible to other participants.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false)
                  .deleteChat(chatId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Leave Group?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will no longer receive messages from this group.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false)
                  .leaveChat(chatId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String chatId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text('Block $userName?', style: const TextStyle(color: Colors.white)),
        content: Text(
          'You will no longer receive messages from $userName.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement block functionality
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}
