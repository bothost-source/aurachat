import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
      appBar: AppBar(
        title: const Text('Storage and Data', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0F), // Purple theme dark background
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Media Auto-Download'),

          _buildSwitchTile(
            title: 'Photos',
            subtitle: 'Auto-download photos',
            value: settingsProvider.autoDownloadMedia,
            onChanged: (value) => settingsProvider.setAutoDownloadMedia(value),
          ),

          _buildSwitchTile(
            title: 'Documents',
            subtitle: 'Auto-download documents',
            value: settingsProvider.autoDownloadDocuments,
            onChanged: (value) => settingsProvider.setAutoDownloadDocuments(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Storage Usage'),

          _buildListTile(
            icon: Icons.folder,
            title: 'Manage Storage',
            subtitle: 'View and free up space',
            onTap: () {},
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Gallery'),

          _buildSwitchTile(
            title: 'Save to Gallery',
            subtitle: 'Save media to device gallery',
            value: settingsProvider.saveToGallery,
            onChanged: (value) => settingsProvider.setSaveToGallery(value),
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8B5CF6), // Purple accent
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF8B5CF6), // Purple accent
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF8B5CF6)), // Purple accent
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5))),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }
}
