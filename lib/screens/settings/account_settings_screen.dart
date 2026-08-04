import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Account Settings'),

          _buildCard(
            children: [
              _buildListTile(
                icon: Icons.security,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Security',
                subtitle: 'Two-step verification, passcode',
                onTap: () => Navigator.pushNamed(context, '/security'),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildListTile(
                icon: Icons.phone,
                iconColor: const Color(0xFF06B6D4), // Cyan accent
                title: 'Change Number',
                subtitle: authProvider.phoneNumber ?? '',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildCard(
            children: [
              _buildListTile(
                icon: Icons.delete_outline,
                iconColor: Colors.redAccent,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                titleColor: Colors.redAccent,
                showTrailing: false,
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
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
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF06B6D4),
    Color titleColor = Colors.white,
    bool showTrailing = true,
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
        style: TextStyle(
          color: titleColor,
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
      trailing: showTrailing
          ? Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 20)
          : null,
      onTap: onTap,
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c), // Dark purple
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Color(0xFFFF6B6B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
                final success = await authProvider.deleteAccount();
                if (context.mounted) {
                  if (success) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF1a103c),
                        content: Text(
                          authProvider.error ?? 'Deletion failed',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
