import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class DataStorageScreen extends StatelessWidget {
  const DataStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Storage and Data'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Media Auto-Download'),

          SwitchListTile(
            title: const Text('Photos'),
            subtitle: const Text('Auto-download photos'),
            value: settingsProvider.autoDownloadMedia,
            onChanged: (value) => settingsProvider.setAutoDownloadMedia(value),
          ),

          SwitchListTile(
            title: const Text('Documents'),
            subtitle: const Text('Auto-download documents'),
            value: settingsProvider.autoDownloadDocuments,
            onChanged: (value) => settingsProvider.setAutoDownloadDocuments(value),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Storage Usage'),

          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Manage Storage'),
            subtitle: const Text('View and free up space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Gallery'),

          SwitchListTile(
            title: const Text('Save to Gallery'),
            subtitle: const Text('Save media to device gallery'),
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
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
