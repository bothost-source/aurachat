import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: chatProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: chatProvider.contacts.length,
              itemBuilder: (context, index) {
                final contact = chatProvider.contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: contact['avatar_url'] != null
                        ? NetworkImage(contact['avatar_url'])
                        : null,
                    child: contact['avatar_url'] == null
                        ? Text((contact['username'] ?? 'U')[0].toUpperCase())
                        : null,
                  ),
                  title: Text(contact['username'] ?? 'Unknown'),
                  subtitle: Text(contact['phone'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.message),
                        onPressed: () async {
                          final chat = await chatProvider.startDirectChat(contact['id']);
                          if (chat != null && context.mounted) {
                            Navigator.pushNamed(context, '/chat', arguments: chat);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call),
                        onPressed: () {},
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
