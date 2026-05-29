import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/auth_provider.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text('Security'),
      ),
      body: ListView(
        children: [
          // Security Status Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.shield, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Security Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            (user?.twoFactorEnabled ?? false) && (user?.passcodeEnabled ?? false)
                                ? 'Your account is fully secured'
                                : 'Complete your security setup',
                            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: ((user?.twoFactorEnabled ?? false) ? 0.33 : 0) + ((user?.passcodeEnabled ?? false) ? 0.33 : 0) + ((user?.biometricEnabled ?? false) ? 0.34 : 0),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          _buildSectionHeader('Authentication'),
          SwitchListTile(
            title: const Text('Two-Step Verification', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            subtitle: Text('Add an extra PIN for account security', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            value: user?.twoFactorEnabled ?? false,
            onChanged: (v) => auth.toggleTwoFactor(v),
            activeColor: AppTheme.primaryGreen,
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.accentBlue.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.verified_user, color: AppTheme.accentBlue, size: 20),
            ),
          ),
          SwitchListTile(
            title: const Text('App Passcode', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            subtitle: Text('Lock the app with a PIN', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            value: user?.passcodeEnabled ?? false,
            onChanged: (v) => auth.togglePasscode(v),
            activeColor: AppTheme.primaryGreen,
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.pin, color: AppTheme.warning, size: 20),
            ),
          ),
          SwitchListTile(
            title: const Text('Biometric Lock', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            subtitle: Text('Use fingerprint or face unlock', style: TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            value: user?.biometricEnabled ?? false,
            onChanged: (v) {},
            activeColor: AppTheme.primaryGreen,
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.fingerprint, color: AppTheme.success, size: 20),
            ),
          ),

          _buildSectionHeader('Sessions'),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.accentPurple.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.devices, color: AppTheme.accentPurple, size: 20),
            ),
            title: const Text('Active Sessions', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
            subtitle: Text('${user?.activeSessions.length ?? 1} device(s) logged in', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textTertiary),
            onTap: () {},
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1.2)),
    );
  }
}
