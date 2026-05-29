import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: AppTheme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile Header
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/public_profile'),
            child: Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.bgSecondary,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Icon(Icons.person, size: 28, color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.displayName ?? 'Your Name',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            if (user?.isVerified ?? false) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: AppTheme.verifiedBlue, shape: BoxShape.circle),
                                child: const Icon(Icons.check, size: 10, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.handle ?? '@username',
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        if (user?.bio != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            user!.bio!,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textTertiary),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingTile(
            icon: Icons.lock_outline,
            iconColor: AppTheme.accentBlue,
            title: 'Privacy',
            subtitle: 'Phone number, last seen, profile photo',
            onTap: () => Navigator.pushNamed(context, '/privacy_settings'),
          ),
          _buildSettingTile(
            icon: Icons.security,
            iconColor: AppTheme.success,
            title: 'Security',
            subtitle: 'Two-step verification, passcode, biometric',
            onTap: () => Navigator.pushNamed(context, '/security'),
          ),
          _buildSettingTile(
            icon: Icons.verified_user_outlined,
            iconColor: AppTheme.verifiedBlue,
            title: 'Verification',
            subtitle: user?.isVerified ?? false ? 'Verified account' : 'Apply for verification',
            trailing: user?.isVerified ?? false
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.verifiedBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('VERIFIED', style: TextStyle(fontSize: 10, color: AppTheme.verifiedBlue, fontWeight: FontWeight.bold)),
                  )
                : null,
            onTap: () {},
          ),

          // Preferences Section
          _buildSectionHeader('Preferences'),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            iconColor: AppTheme.warning,
            title: 'Notifications',
            subtitle: 'Message tones, group notifications',
            onTap: () => Navigator.pushNamed(context, '/notifications_settings'),
          ),
          _buildSettingTile(
            icon: Icons.storage_outlined,
            iconColor: AppTheme.accentPurple,
            title: 'Data and Storage',
            subtitle: 'Network usage, auto-download',
            onTap: () => Navigator.pushNamed(context, '/data_storage'),
          ),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            iconColor: AppTheme.accentPink,
            title: 'Appearance',
            subtitle: 'Theme, chat background, font size',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.language,
            iconColor: AppTheme.accentCyan,
            title: 'Language',
            subtitle: 'English (device default)',
            onTap: () {},
          ),

          // Bots & AI Section
          _buildSectionHeader('Bots & AI'),
          _buildSettingTile(
            icon: Icons.smart_toy_outlined,
            iconColor: AppTheme.primaryGreen,
            title: 'My Bots',
            subtitle: 'Manage your created bots',
            onTap: () => Navigator.pushNamed(context, '/bot_settings'),
          ),
          _buildSettingTile(
            icon: Icons.auto_awesome,
            iconColor: AppTheme.accentCyan,
            title: 'AI Studio',
            subtitle: 'Chatbot, Writer, Image, Voice',
            onTap: () => Navigator.pushNamed(context, '/ai_studio'),
          ),
          _buildSettingTile(
            icon: Icons.storefront_outlined,
            iconColor: AppTheme.accentOrange,
            title: 'Bot Store',
            subtitle: 'Discover and add bots',
            onTap: () => Navigator.pushNamed(context, '/bot_store'),
          ),

          // Help & Support
          _buildSectionHeader('Help'),
          _buildSettingTile(
            icon: Icons.help_outline,
            iconColor: AppTheme.info,
            title: 'Help Center',
            subtitle: 'FAQ, contact support',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.policy_outlined,
            iconColor: AppTheme.textSecondary,
            title: 'Terms of Service',
            subtitle: 'Read our terms and guidelines',
            onTap: () => Navigator.pushNamed(context, '/terms'),
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.textSecondary,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {},
          ),
          _buildSettingTile(
            icon: Icons.report_outlined,
            iconColor: AppTheme.error,
            title: 'Report a Problem',
            subtitle: 'Flag issues or violations',
            onTap: () => Navigator.pushNamed(context, '/report'),
          ),
          _buildSettingTile(
            icon: Icons.gavel_outlined,
            iconColor: AppTheme.warning,
            title: 'Appeal Restriction',
            subtitle: 'Contest account actions',
            onTap: () => Navigator.pushNamed(context, '/appeal'),
          ),

          // Danger Zone
          _buildSectionHeader('Account Actions'),
          _buildSettingTile(
            icon: Icons.logout,
            iconColor: AppTheme.error,
            title: 'Log Out',
            titleColor: AppTheme.error,
            onTap: () => _showLogoutDialog(context, auth),
          ),
          _buildSettingTile(
            icon: Icons.delete_forever,
            iconColor: AppTheme.error,
            title: 'Delete Account',
            titleColor: AppTheme.error,
            subtitle: 'Permanently remove your account',
            onTap: () {},
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'TARRIFIC CHAT v1.0.0',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor ?? AppTheme.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary)) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('You will need to log in again to access your messages.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              auth.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
