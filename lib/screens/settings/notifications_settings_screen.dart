import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildSectionHeader(context, 'Message Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.message_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Message Tones',
                subtitle: 'Play sound for new messages',
                value: settingsProvider.messageTones,
                onChanged: (value) => settingsProvider.setMessageTones(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.group_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Group Notifications',
                subtitle: 'Notifications for group messages',
                value: settingsProvider.groupNotifications,
                onChanged: (value) => settingsProvider.setGroupNotifications(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Channel Notifications',
                subtitle: 'Notifications for channel updates',
                value: settingsProvider.channelNotifications,
                onChanged: (value) => settingsProvider.setChannelNotifications(value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Call Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.call_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Voice & Video Calls',
                subtitle: 'Notifications for incoming calls',
                value: settingsProvider.voiceVideoCalls,
                onChanged: (value) => settingsProvider.setVoiceVideoCalls(value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'In-App Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'In-App Sounds',
                subtitle: 'Play sounds while using the app',
                value: settingsProvider.inAppSounds,
                onChanged: (value) => settingsProvider.setInAppSounds(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.vibration_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'In-App Vibrate',
                subtitle: 'Vibrate while using the app',
                value: settingsProvider.inAppVibrate,
                onChanged: (value) => settingsProvider.setInAppVibrate(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.preview_outlined,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Show Preview',
                subtitle: 'Show message preview in notifications',
                value: settingsProvider.showPreview,
                onChanged: (value) => settingsProvider.setShowPreview(value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildInfoCard(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a103c), // Dark purple card background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.15), // Purple border
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: iconColor.withOpacity(0.25)),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF8B5CF6), // Purple
        activeTrackColor: const Color(0xFF8B5CF6).withOpacity(0.3),
        inactiveThumbColor: Colors.white.withOpacity(0.5),
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a103c), // Dark purple card background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.15), // Purple border
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF8B5CF6), // Purple accent
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notification Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These settings control how you receive notifications. You can customize sounds, vibrations, and previews for different types of messages.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
