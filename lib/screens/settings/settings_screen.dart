import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile Header
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 32,
              backgroundImage: authProvider.userPhotoUrl != null
                  ? NetworkImage(authProvider.userPhotoUrl!)
                  : null,
              child: authProvider.userPhotoUrl == null
                  ? Icon(
                      Icons.person,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    )
                  : null,
            ),
            title: Text(
              authProvider.userName ?? 'Your Name',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            subtitle: Text(
              authProvider.phoneNumber ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            trailing: const Icon(Icons.qr_code),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),

          const Divider(),

          // Settings Categories
          _buildSettingsTile(
            context,
            icon: Icons.key,
            title: 'Account',
            subtitle: 'Security, change number',
            onTap: () => Navigator.pushNamed(context, '/account_settings'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Block contacts, disappearing messages',
            onTap: () => Navigator.pushNamed(context, '/privacy_settings'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.face,
            title: 'Avatar',
            subtitle: 'Create, edit, profile photo',
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.chat_bubble_outline,
            title: 'Chats',
            subtitle: 'Theme, wallpapers, chat history',
            onTap: () => Navigator.pushNamed(context, '/data_storage'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Message, group & call tones',
            onTap: () => Navigator.pushNamed(context, '/notifications_settings'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.storage_outlined,
            title: 'Storage and Data',
            subtitle: 'Network usage, auto-download',
            onTap: () => Navigator.pushNamed(context, '/data_storage'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.language,
            title: 'App Language',
            subtitle: 'English (device default)',
            onTap: () => Navigator.pushNamed(context, '/language'),
          ),

          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: 'Help',
            subtitle: 'Help center, contact us, privacy policy',
            onTap: () {},
          ),

          const Divider(),

          // Invite Friends
          ListTile(
            leading: Icon(
              Icons.people_outline,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text('Invite Friends'),
            onTap: () => Navigator.pushNamed(context, '/invite_friends'),
          ),

          // App Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'TARRIFIC CHAT',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Version 1.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
