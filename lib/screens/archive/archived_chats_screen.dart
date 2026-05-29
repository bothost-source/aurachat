import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/chat_provider.dart';

class ArchivedChatsScreen extends StatelessWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final archived = context.watch<ChatProvider>().archivedChats;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(backgroundColor: AppTheme.bgSecondary, elevation: 0, title: const Text('Archived Chats')),
      body: archived.isEmpty
          ? Center(child: Text('No archived chats', style: TextStyle(color: AppTheme.textTertiary)))
          : ListView.builder(
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final chat = archived[index];
                return ListTile(
                  title: Text(chat.displayName, style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: TextButton(
                    onPressed: () => context.read<ChatProvider>().unarchiveChat(chat.id),
                    child: const Text('Unarchive', style: TextStyle(color: AppTheme.primaryGreen)),
                  ),
                );
              },
            ),
    );
  }
}
