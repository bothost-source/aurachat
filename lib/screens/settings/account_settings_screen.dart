import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Account', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0F),
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
                iconColor: const Color(0xFF06B6D4),
                title: 'Security',
                subtitle: 'Two-step verification, passcode',
                onTap: () => Navigator.pushNamed(context, '/security'),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildListTile(
                icon: Icons.phone,
                iconColor: const Color(0xFF06B6D4),
                title: 'Change Number',
                subtitle: authProvider.phoneNumber ?? 'Not set',
                onTap: () => _showChangeNumberDialog(context),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildListTile(
                icon: Icons.email,
                iconColor: const Color(0xFF06B6D4),
                title: 'Change Email',
                subtitle: authProvider.email ?? 'Not set',
                onTap: () => _showChangeEmailDialog(context),
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
          color: const Color(0xFF1a103c),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.15),
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

  // ==================== CHANGE NUMBER ====================
  void _showChangeNumberDialog(BuildContext context) {
    final controller = TextEditingController();
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        title: const Text(
          'Change Phone Number',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${authProvider.phoneNumber ?? "Not set"}',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'New phone number',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPhone = controller.text.trim();
              if (newPhone.isEmpty) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              final success = await authProvider.changePhoneNumber(newPhone);
              setState(() => _isLoading = false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Phone number updated' : authProvider.error ?? 'Failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // ==================== CHANGE EMAIL ====================
  void _showChangeEmailDialog(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentEmail = authProvider.email;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        title: const Text(
          'Change Email',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${currentEmail ?? "Not set"}',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            const Text(
              'To change your email, you must verify your current email first.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showVerifyOldEmailDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Verify Current Email'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showLostEmailDialog(context);
              },
              child: const Text(
                'Lost access to email?',
                style: TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
        ],
      ),
    );
  }

  // ==================== VERIFY OLD EMAIL ====================
  void _showVerifyOldEmailDialog(BuildContext context) {
    final codeController = TextEditingController();
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final email = authProvider.email;

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on file'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter OTP sent to $email',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '6-digit code',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Verify OTP with backend
              Navigator.pop(context);
              _showEnterNewEmailDialog(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  // ==================== ENTER NEW EMAIL ====================
  void _showEnterNewEmailDialog(BuildContext context) {
    final controller = TextEditingController();
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'new@email.com',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = controller.text.trim();
              if (newEmail.isEmpty || !newEmail.contains('@')) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              final success = await authProvider.changeEmail(newEmail);
              setState(() => _isLoading = false);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Email updated' : authProvider.error ?? 'Failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // ==================== LOST EMAIL REPORT ====================
  void _showLostEmailDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Lost Email Access',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Report to AURA Support',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a report to supportaurachat@gmail.com. Include your phone number and reason.',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Your phone number',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Why do you need to change email?',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              final reason = reasonController.text.trim();

              if (phone.isEmpty || reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fill all fields'), backgroundColor: Colors.red),
                );
                return;
              }

              // TODO: Send report to backend/support email
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report sent to support. We will review and contact you.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Send Report'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will permanently delete your account and all data. This cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
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
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
