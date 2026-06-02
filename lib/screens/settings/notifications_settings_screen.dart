import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Message Notifications'),

          _buildToggleTile(
            context,
            icon: Icons.message_outlined,
            title: 'Message Tones',
            subtitle: 'Play sound for new messages',
            value: settingsProvider.messageTones,
            onChanged: (value) => settingsProvider.setMessageTones(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.group_outlined,
            title: 'Group Notifications',
            subtitle: 'Notifications for group messages',
            value: settingsProvider.groupNotifications,
            onChanged: (value) => settingsProvider.setGroupNotifications(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.campaign_outlined,
            title: 'Channel Notifications',
            subtitle: 'Notifications for channel updates',
            value: settingsProvider.channelNotifications,
            onChanged: (value) => settingsProvider.setChannelNotifications(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Call Notifications'),

          _buildToggleTile(
            context,
            icon: Icons.call_outlined,
            title: 'Voice & Video Calls',
            subtitle: 'Notifications for incoming calls',
            value: settingsProvider.voiceVideoCalls,
            onChanged: (value) => settingsProvider.setVoiceVideoCalls(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'In-App Notifications'),

          _buildToggleTile(
            context,
            icon: Icons.volume_up_outlined,
            title: 'In-App Sounds',
            subtitle: 'Play sounds while using the app',
            value: settingsProvider.inAppSounds,
            onChanged: (value) => settingsProvider.setInAppSounds(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.vibration_outlined,
            title: 'In-App Vibrate',
            subtitle: 'Vibrate while using the app',
            value: settingsProvider.inAppVibrate,
            onChanged: (value) => settingsProvider.setInAppVibrate(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.preview_outlined,
            title: 'Show Preview',
            subtitle: 'Show message preview in notifications',
            value: settingsProvider.showPreview,
            onChanged: (value) => settingsProvider.setShowPreview(value),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Notification Settings',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These settings control how you receive notifications. You can customize sounds, vibrations, and previews for different types of messages.',
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
