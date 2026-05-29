import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(backgroundColor: AppTheme.bgSecondary, elevation: 0, title: const Text('Data and Storage')),
      body: ListView(
        children: [
          _buildSectionHeader('Storage Usage'),
          ListTile(
            leading: const Icon(Icons.storage, color: AppTheme.accentPurple),
            title: const Text('Storage Used', style: TextStyle(color: AppTheme.textPrimary)),
            trailing: const Text('1.2 GB', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
          ),
          LinearProgressIndicator(value: 0.4, backgroundColor: AppTheme.bgElevated, valueColor: const AlwaysStoppedAnimation(AppTheme.primaryGreen)),
          _buildSectionHeader('Auto-Download'),
          SwitchListTile(title: const Text('Photos', style: TextStyle(color: AppTheme.textPrimary)), value: true, onChanged: (v) {}, activeColor: AppTheme.primaryGreen),
          SwitchListTile(title: const Text('Videos', style: TextStyle(color: AppTheme.textPrimary)), value: false, onChanged: (v) {}, activeColor: AppTheme.primaryGreen),
          SwitchListTile(title: const Text('Documents', style: TextStyle(color: AppTheme.textPrimary)), value: true, onChanged: (v) {}, activeColor: AppTheme.primaryGreen),
          _buildSectionHeader('Network'),
          ListTile(title: const Text('Proxy Settings', style: TextStyle(color: AppTheme.textPrimary)), trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textTertiary), onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1)));
}
