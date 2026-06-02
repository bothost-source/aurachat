import 'package:flutter/material.dart';

class BotSettingsScreen extends StatelessWidget {
  const BotSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Bot Settings'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('My Bots'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/bot_store'),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Create New Bot'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/bot_creator'),
          ),
        ],
      ),
    );
  }
}
