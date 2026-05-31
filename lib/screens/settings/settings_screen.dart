import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _showApiKey = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('ai_api_key');
    if (savedKey != null) {
      _apiKeyController.text = savedKey;
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', key);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API Key saved!'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
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
            onPressed: () {
              // TODO: Show QR code
            },
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
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (user?.isVerified ?? false) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppTheme.verifiedBlue,
                                  shape: BoxShape.circle,
                                ),
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
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
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
            subtitle: user?.isVerified ?? false
                ? 'Verified account'
                : 'Apply for verification (\$4.99)',
            trailing: user?.isVerified ?? false
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.verifiedBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.verifiedBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              if (!(user?.isVerified ?? false)) {
                _showVerificationDialog();
              }
            },
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
            onTap: () => _showAppearanceDialog(themeProvider),
          ),
          _buildSettingTile(
            icon: Icons.language,
            iconColor: AppTheme.accentCyan,
            title: 'Language',
            subtitle: 'English (device default)',
            onTap: () => _showLanguageDialog(),
          ),

          // NEW: AI API Key Section
          _buildSectionHeader('AI Settings'),
          _buildApiKeySection(),

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
            onTap: () => _showHelpDialog(),
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
            onTap: () => _showPrivacyPolicy(),
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
            onTap: () => _showDeleteAccountDialog(),
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

  // NEW: API Key Section
  Widget _buildApiKeySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key, color: AppTheme.primaryGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI API Key',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Add your API key to use AI features. Get a FREE key from Google AI Studio.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: !_showApiKey,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste API key here',
              hintStyle: TextStyle(color: AppTheme.textTertiary),
              filled: true,
              fillColor: AppTheme.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _showApiKey ? Icons.visibility_off : Icons.visibility,
                  color: AppTheme.textTertiary,
                ),
                onPressed: () => setState(() => _showApiKey = !_showApiKey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save API Key'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.bgModal,
                  title: const Text(
                    'How to Get API Key',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStep('1', 'Go to aistudio.google.com'),
                      _buildStep('2', 'Sign in with Google'),
                      _buildStep('3', 'Click "Get API Key"'),
                      _buildStep('4', 'Copy and paste it here'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Got it',
                        style: TextStyle(color: AppTheme.primaryGreen),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              'Where do I get an API key?',
              style: TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // NEW: Verification Purchase Dialog
  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text(
          'Get Verified',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 64, color: AppTheme.verifiedBlue),
            const SizedBox(height: 16),
            const Text(
              'Verified Badge',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get verified and unlock all premium features:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            _buildPremiumFeature(Icons.check_circle, 'Verified badge on profile'),
            _buildPremiumFeature(Icons.wallpaper, 'All premium wallpapers'),
            _buildPremiumFeature(Icons.sticker, 'All sticker packs'),
            _buildPremiumFeature(Icons.timer, '48h & 3-day status duration'),
            const SizedBox(height: 16),
            const Text(
              '\$4.99 one-time',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Process payment
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment processing...'),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Buy Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // NEW: Appearance Dialog
  void _showAppearanceDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Appearance', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode, color: AppTheme.textPrimary),
              title: const Text('Dark Theme', style: TextStyle(color: AppTheme.textPrimary)),
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.toggleTheme(),
                activeColor: AppTheme.primaryGreen,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode, color: AppTheme.textPrimary),
              title: const Text('Light Theme', style: TextStyle(color: AppTheme.textPrimary)),
              trailing: Switch(
                value: !themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.toggleTheme(),
                activeColor: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // NEW: Language Dialog
  void _showLanguageDialog() {
    final languages = ['English', 'Spanish', 'French', 'German', 'Chinese', 'Arabic', 'Hindi'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Language', style: TextStyle(color: AppTheme.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(languages[index], style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Language changed to ${languages[index]}')),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Help Dialog
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Help Center', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHelpItem(Icons.question_answer, 'FAQ', 'Common questions'),
            _buildHelpItem(Icons.email, 'Email Support', 'support@tarrific.chat'),
            _buildHelpItem(Icons.chat, 'Live Chat', 'Chat with our team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary)),
      onTap: () {},
    );
  }

  // NEW: Privacy Policy
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Privacy Policy', style: TextStyle(color: AppTheme.textPrimary)),
        content: const SingleChildScrollView(
          child: Text(
            'TARRIFIC CHAT respects your privacy. We encrypt all messages and do not share your data with third parties.\n\n'
            'Key points:\n'
            '• Messages are encrypted end-to-end\n'
            '• We do not sell your data\n'
            '• You can delete your account anytime\n'
            '• AI processing is done securely',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // NEW: Delete Account Dialog
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgModal,
        title: const Text('Delete Account?', style: TextStyle(color: AppTheme.error)),
        content: const Text(
          'This will permanently delete your account and all data. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Delete account
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requested'),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textTertiary,
          letterSpacing: 1.2,
        ),
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
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary))
          : null,
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
        content: const Text(
          'You will need to log in again to access your messages.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
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

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}
