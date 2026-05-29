import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(backgroundColor: AppTheme.bgSecondary, elevation: 0, title: const Text('Account')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.phone, color: AppTheme.accentBlue), title: const Text('Change Phone Number', style: TextStyle(color: AppTheme.textPrimary)), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textTertiary), onTap: () {}),
          ListTile(leading: const Icon(Icons.delete, color: AppTheme.error), title: const Text('Delete Account', style: TextStyle(color: AppTheme.error)), onTap: () {}),
        ],
      ),
    );
  }
}
