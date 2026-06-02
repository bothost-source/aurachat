import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

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
        final unreadCount = chat['unread_count'] ?? 0;
        final lastMessage = chat['last_message'];
        final lastMessageAt = chat['last_message_at'] != null
            ? DateTime.parse(chat['last_message_at'])
            : null;

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
                CircleAvatar(
                  radius: 28,
                  backgroundImage: chat['avatar_url'] != null
                      ? NetworkImage(chat['avatar_url'])
                      : null,
                  child: chat['avatar_url'] == null
                      ? Icon(
                          chat['type'] == 'group' || chat['type'] == 'channel'
                              ? Icons.group
                              : Icons.person,
                        )
                      : null,
                ),
                if (chat['type'] == 'group' || chat['type'] == 'channel')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        chat['type'] == 'channel' ? Icons.campaign : Icons.group,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatId: chat['id'],
                    chatName: chat['name'],
                    chatAvatar: chat['avatar_url'],
                    isGroup: chat['type'] == 'group' || chat['type'] == 'channel',
                  ),
                ),
              );
            },
          ),
        );
      },
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
