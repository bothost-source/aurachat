import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../utils/verified_badge.dart';
import '../../services/call_service.dart';
import '../call/call_screen.dart';
import 'chat_screen.dart';
import '../channel/channel_screen.dart';
import '../channel/channel_info_screen.dart';
import '../groups/group_info_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuraAuthProvider>(context);

    if (chatProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final chats = chatProvider.chats.where((chat) => 
      !(chat['is_archived'] ?? false)
    ).toList();

    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No chats yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new conversation!',
              style: TextStyle(color: Colors.grey.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final chatType = chat['type'] as String? ?? 'direct';
        final unreadCount = chat['unread_count'] ?? 0;
        final lastMessage = chat['last_message'];

        // FIX: Properly handle Firestore Timestamp, DateTime, and String
        final lastMessageAt = chat['last_message_at'] != null
            ? (chat['last_message_at'] is DateTime 
                ? chat['last_message_at'] as DateTime
                : chat['last_message_at'] is Timestamp
                    ? (chat['last_message_at'] as Timestamp).toDate()
                    : DateTime.tryParse(chat['last_message_at'].toString()))
            : null;

        final memberCount = chat['participants_count'] ?? 0;
        final createdByPhone = chat['created_by_phone'] as String?;
        final role = chat['role'] as String? ?? 'member';
        final isGroup = chatType == 'group';
        final isChannel = chatType == 'channel';
        final isGroupOrChannel = isGroup || isChannel;

        // FIX: For direct chats, fetch the other user's data from Firestore
        if (!isGroupOrChannel) {
          final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
          final participants = List<String>.from(chat['participants'] ?? []);
          final otherUserId = participants.firstWhere(
            (id) => id != currentUserId,
            orElse: () => '',
          );

          if (otherUserId.isNotEmpty) {
            return _DirectChatTile(
              chat: chat,
              otherUserId: otherUserId,
              currentUserId: currentUserId!,
              unreadCount: unreadCount,
              lastMessage: lastMessage,
              lastMessageAt: lastMessageAt,
              onTap: () {
                chatProvider.markMessagesAsRead(chat['id']);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: chat['id'],
                      chatName: chat['name'],
                      chatAvatar: chat['avatar_url'],
                      isGroup: false,
                    ),
                  ),
                );
              },
              onArchive: () => chatProvider.archiveChat(chat['id']),
              onDelete: () => _showDeleteDialog(context, chat['id']),
            );
          }
        }

        // Group/Channel tile (unchanged logic)
        return Slidable(
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
            leading: Stack(
              children: [
                _buildAvatar(chat),
                if (isGroupOrChannel)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0A0A0F), width: 1.5),
                      ),
                      child: Icon(
                        isChannel ? Icons.campaign : Icons.group,
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
                  child: isGroupOrChannel
                    ? VerifiedUsername(
                        username: chat['name'] ?? 'Unknown',
                        phoneNumber: createdByPhone,
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                        badgeSize: 14,
                        spacing: 6,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        chat['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
                if (lastMessageAt != null)
                  Text(
                    _formatChatListTime(lastMessageAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: unreadCount > 0
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                if (isGroupOrChannel) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isChannel 
                          ? Colors.orange.withOpacity(0.2) 
                          : Theme.of(context).primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isChannel ? 'CHANNEL' : 'GROUP',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isChannel ? Colors.orange : Theme.of(context).primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '$memberCount',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.people,
                    size: 12,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  // FIX: Format last message text properly
                  child: Text(
                    _formatLastMessage(lastMessage, chat['last_message_type'] as String?),
                    style: TextStyle(
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: unreadCount > 0 ? null : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: () {
              chatProvider.markMessagesAsRead(chat['id']);
              if (isChannel) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChannelChatScreen(
                      channelId: chat['id'],
                      channelName: chat['name'] ?? 'Channel',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatId: chat['id'],
                      chatName: chat['name'],
                      chatAvatar: chat['avatar_url'],
                      isGroup: isGroup,
                    ),
                  ),
                );
              }
            },
            onLongPress: () => _showChatOptions(context, chat, isGroupOrChannel),
          ),
        );
      },
    );
  }

  // FIX: Format last message text for display
  String _formatLastMessage(String? lastMessage, String? type) {
    if (lastMessage == null || lastMessage.isEmpty) return 'No messages yet';
    
    // If it's a media file name, show friendly label
    if (type == 'image' || lastMessage.endsWith('.jpg') || lastMessage.endsWith('.jpeg') || lastMessage.endsWith('.png')) {
      return '📷 Photo';
    }
    if (type == 'video' || lastMessage.endsWith('.mp4') || lastMessage.endsWith('.mov')) {
      return '🎥 Video';
    }
    if (type == 'audio' || lastMessage.endsWith('.m4a') || lastMessage.endsWith('.mp3')) {
      return '🎤 Voice Message';
    }
    if (type == 'file') {
      return '📎 ${lastMessage.split('/').last}';
    }
    
    return lastMessage;
  }

  String _formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = today.difference(messageDate).inDays;

    // FIX: Today — show time for older messages, "Now" only for very recent
    if (diffDays == 0) {
      final diffMinutes = now.difference(dateTime).inMinutes;
      if (diffMinutes < 1) {
        return 'Now';
      } else if (diffMinutes < 60) {
        return '${diffMinutes}m ago';
      } else {
        // Show actual time instead of "Xh ago"
        return _formatTimeOnly(dateTime);
      }
    } 
    // FIX: Yesterday
    else if (diffDays == 1) {
      return 'Yesterday';
    } 
    // This week
    else if (diffDays < 7) {
      return _getDayName(dateTime.weekday);
    } 
    // This year
    else if (dateTime.year == now.year) {
      return '${_getMonthName(dateTime.month)} ${dateTime.day}';
    } 
    // Different year
    else {
      return '${_getMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    }
  }
  
  String _formatTimeOnly(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildAvatar(Map<String, dynamic> chat) {
    final avatarUrl = chat['avatar_url'] as String?;
    final chatType = chat['type'] as String? ?? 'direct';
    final isGroupOrChannel = chatType == 'group' || chatType == 'channel';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      child: Icon(
        isGroupOrChannel ? Icons.group : Icons.person,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  // NEW: Show options menu on long-press for any chat type
  void _showChatOptions(BuildContext context, Map<String, dynamic> chat, bool isGroupOrChannel) {
    final chatId = chat['id'] as String;
    final chatName = chat['name'] as String? ?? 'Unknown';
    final chatType = chat['type'] as String? ?? 'direct';
    final isArchived = chat['is_archived'] == true;
    final role = chat['role'] as String? ?? 'member';
    final isOwner = role == 'owner';

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
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Chat name header
            Text(
              chatName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              isGroupOrChannel
                ? (chatType == 'channel' ? 'Channel' : 'Group')
                : 'Direct Message',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
            const Divider(color: Colors.white10, height: 24),
            
            // Mark as read / unread
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.done_all, color: Color(0xFF06B6D4)),
              ),
              title: const Text('Mark as Read', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false).markMessagesAsRead(chatId);
              },
            ),
            
            // Archive / Unarchive
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.blue,
                ),
              ),
              title: Text(
                isArchived ? 'Unarchive' : 'Archive',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                if (isArchived) {
                  Provider.of<ChatProvider>(context, listen: false).unarchiveChat(chatId);
                } else {
                  Provider.of<ChatProvider>(context, listen: false).archiveChat(chatId);
                }
              },
            ),
            
            // Mute / Unmute notifications
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off, color: Colors.orange),
              ),
              title: const Text('Mute Notifications', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement mute logic
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              },
            ),
            
            // Info (for groups/channels)
            if (isGroupOrChannel) ...[
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline, color: Color(0xFF8B5CF6)),
                ),
                title: const Text('Info', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  if (chatType == 'channel') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChannelInfoScreen(
                          chatId: chatId,
                          chatName: chatName,
                          chatAvatar: chat['avatar_url'],
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupInfoScreen(
                          chatId: chatId,
                          chatName: chatName,
                          chatAvatar: chat['avatar_url'],
                          isChannel: false,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
            
            // Delete (owner-only for groups/channels)
            if (!isGroupOrChannel || isOwner) ...[
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(context, chatId);
                },
              ),
            ],
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This chat will be removed from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatProvider>(context, listen: false).deleteChat(chatId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NEW: Direct chat tile that fetches other user's data from Firestore
// ============================================================================
class _DirectChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String otherUserId;
  final String currentUserId;
  final int unreadCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _DirectChatTile({
    required this.chat,
    required this.otherUserId,
    required this.currentUserId,
    required this.unreadCount,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.onTap,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;

        // FIX: Get name from user document, not chat document
        final displayName = userData?['display_name'] as String? ??
                           userData?['name'] as String? ??
                           userData?['username'] as String? ??
                           'Unknown';

        final avatarUrl = userData?['avatar_url'] as String?;
        final phone = userData?['phone'] as String?;

        return Slidable(
          key: ValueKey(chat['id']),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => onArchive(),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                icon: Icons.archive,
                label: 'Archive',
              ),
              SlidableAction(
                onPressed: (_) => onDelete(),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Delete',
              ),
            ],
          ),
          child: ListTile(
            leading: _buildUserAvatar(avatarUrl),
            title: Row(
              children: [
                Expanded(
                  child: VerifiedUsername(
                    username: displayName,
                    phoneNumber: phone,
                    style: TextStyle(
                      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                      fontSize: 15,
                    ),
                    badgeSize: 14,
                    spacing: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lastMessageAt != null)
                  Text(
                    _formatTime(lastMessageAt!),
                    style: TextStyle(
                      fontSize: 12,
                      color: unreadCount > 0
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatLastMessage(lastMessage, chat['last_message_type'] as String?),
                    style: TextStyle(
                      fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                      color: unreadCount > 0 ? null : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            onTap: onTap,
            onLongPress: () => _showDirectChatOptions(context),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
      child: const Icon(
        Icons.person,
        color: Color(0xFF8B5CF6),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diffDays = today.difference(messageDate).inDays;

    // FIX: Today
    if (diffDays == 0) {
      final diffMinutes = now.difference(dateTime).inMinutes;
      if (diffMinutes < 1) return 'Now';
      if (diffMinutes < 60) return '${diffMinutes}m ago';
      // Show actual time instead of "Xh ago"
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } 
    // FIX: Yesterday
    else if (diffDays == 1) {
      return 'Yesterday';
    } 
    // This week
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

  String _formatLastMessage(String? lastMessage, String? type) {
    if (lastMessage == null || lastMessage.isEmpty) return 'No messages yet';
    
    if (type == 'image' || lastMessage.endsWith('.jpg') || lastMessage.endsWith('.jpeg') || lastMessage.endsWith('.png')) {
      return '📷 Photo';
    }
    if (type == 'video' || lastMessage.endsWith('.mp4') || lastMessage.endsWith('.mov')) {
      return '🎥 Video';
    }
    if (type == 'audio' || lastMessage.endsWith('.m4a') || lastMessage.endsWith('.mp3')) {
      return '🎤 Voice Message';
    }
    if (type == 'file') {
      return '📎 ${lastMessage.split('/').last}';
    }
    
    return lastMessage;
  }

  void _showDirectChatOptions(BuildContext context) {
    final chatId = chat['id'] as String;
    final isArchived = chat['is_archived'] == true;

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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              chat['name'] ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Direct Message',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
            const Divider(color: Colors.white10, height: 24),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.done_all, color: Color(0xFF06B6D4)),
              ),
              title: const Text('Mark as Read', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Provider.of<ChatProvider>(context, listen: false).markMessagesAsRead(chatId);
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.blue,
                ),
              ),
              title: Text(
                isArchived ? 'Unarchive' : 'Archive',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                if (isArchived) {
                  Provider.of<ChatProvider>(context, listen: false).unarchiveChat(chatId);
                } else {
                  Provider.of<ChatProvider>(context, listen: false).archiveChat(chatId);
                }
              },
            ),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off, color: Colors.orange),
              ),
              title: const Text('Mute Notifications', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifications muted')),
                );
              },
            ),
            
            const Divider(color: Colors.white10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
   
