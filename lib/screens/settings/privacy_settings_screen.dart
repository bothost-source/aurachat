import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Who Can See My Info'),

          _buildToggleTile(
            context,
            icon: Icons.phone_outlined,
            title: 'Phone Number',
            subtitle: 'Show my phone number to others',
            value: settingsProvider.phoneNumberVisible,
            onChanged: (value) => settingsProvider.setPhoneNumberVisible(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.access_time_outlined,
            title: 'Last Seen',
            subtitle: 'Show when I was last online',
            value: settingsProvider.lastSeenVisible,
            onChanged: (value) => settingsProvider.setLastSeenVisible(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.photo_outlined,
            title: 'Profile Photo',
            subtitle: 'Show my profile photo to others',
            value: settingsProvider.profilePhotoVisible,
            onChanged: (value) => settingsProvider.setProfilePhotoVisible(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Messaging'),

          _buildToggleTile(
            context,
            icon: Icons.forward_to_inbox_outlined,
            title: 'Forwarded Messages',
            subtitle: 'Allow others to forward my messages',
            value: settingsProvider.forwardedMessages,
            onChanged: (value) => settingsProvider.setForwardedMessages(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.group_add_outlined,
            title: 'Add to Groups',
            subtitle: 'Allow others to add me to groups',
            value: settingsProvider.addToGroups,
            onChanged: (value) => settingsProvider.setAddToGroups(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.call_outlined,
            title: 'Voice & Video Calls',
            subtitle: 'Allow others to call me',
            value: settingsProvider.voiceVideoCallsVisible,
            onChanged: (value) => settingsProvider.setVoiceVideoCallsVisible(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Find Me'),

          _buildToggleTile(
            context,
            icon: Icons.phone_android_outlined,
            title: 'Find by Phone Number',
            subtitle: 'People can find me using my phone',
            value: settingsProvider.findByPhone,
            onChanged: (value) => settingsProvider.setFindByPhone(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.alternate_email_outlined,
            title: 'Find by Username',
            subtitle: 'People can find me using my username',
            value: settingsProvider.findByUsername,
            onChanged: (value) => settingsProvider.setFindByUsername(value),
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
                      'Privacy Info',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'These settings control your visibility and how others can interact with you. Changes are saved locally and synced to your account when online.',
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
