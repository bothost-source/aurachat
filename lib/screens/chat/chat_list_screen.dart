import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../utils/verified_badge.dart';
import 'chat_screen.dart';
import '../channel/channel_screen.dart';
import '../channel/channel_info_screen.dart';
import '../groups/group_info_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
        final lastMessageAt = chat['last_message_at'] != null
            ? (chat['last_message_at'] is DateTime 
                ? chat['last_message_at'] as DateTime
                : DateTime.tryParse(chat['last_message_at'].toString()))
            : null;
        final memberCount = chat['participants_count'] ?? 0;
        final createdByPhone = chat['created_by_phone'] as String?;
        final role = chat['role'] as String? ?? 'member';
        final isGroup = chatType == 'group';
        final isChannel = chatType == 'channel';
        final isGroupOrChannel = isGroup || isChannel;

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
                    timeago.format(lastMessageAt),
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
                  child: Text(
                    lastMessage ?? 'No messages yet',
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
            onLongPress: isGroupOrChannel
              ? () {
                  if (isChannel) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChannelInfoScreen(
                          chatId: chat['id'],
                          chatName: chat['name'] ?? 'Unknown',
                          chatAvatar: chat['avatar_url'],
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupInfoScreen(
                          chatId: chat['id'],
                          chatName: chat['name'] ?? 'Unknown',
                          chatAvatar: chat['avatar_url'],
                          isChannel: false,
                        ),
                      ),
                    );
                  }
                }
              : null,
          ),
        );
      },
    );
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
