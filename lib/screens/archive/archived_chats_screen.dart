import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final archivedChats = chatProvider.chats.where((chat) => 
      chat['is_archived'] == true
    ).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Archived Chats'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: archivedChats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive,
                    size: 80,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No archived chats',
                    style: TextStyle(color: Colors.grey.withOpacity(0.7)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: archivedChats.length,
              itemBuilder: (context, index) {
                final chat = archivedChats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: chat['avatar_url'] != null
                        ? NetworkImage(chat['avatar_url'])
                        : null,
                    child: chat['avatar_url'] == null
                        ? const Icon(Icons.chat)
                        : null,
                  ),
                  title: Text(chat['name'] ?? 'Unknown'),
                  subtitle: Text(chat['last_message'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.unarchive),
                    onPressed: () => chatProvider.unarchiveChat(chat['id']),
                  ),
                );
              },
            ),
    );
  }
}
