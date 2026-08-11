import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../providers/settings_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  String _selectedRingtone = 'default';
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlaying = false;

  final List<Map<String, dynamic>> _ringtones = [
    {'id': 'default', 'name': 'AURA Default', 'file': 'audio/ringtone_ambition.mp3'},
    {'id': 'phonk', 'name': 'phonk Vibes', 'file': 'audio/ringtone_phonk.mp3'},
    {'id': 'fadded', 'name': 'fadded Phone', 'file': 'audio/ringtone_fadded.mp3'},
    {'id': 'pop', 'name': 'pop', 'file': 'audio/ringtone_pop.mp3'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRingtone();
  }

  Future<void> _loadRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedRingtone = prefs.getString('call_ringtone') ?? 'default';
    });
  }

  Future<void> _setRingtone(String ringtoneId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('call_ringtone', ringtoneId);
    setState(() => _selectedRingtone = ringtoneId);
  }

  Future<void> _previewRingtone(String filePath) async {
    if (_isPlaying) {
      await _previewPlayer.stop();
      setState(() => _isPlaying = false);
      return;
    }

    try {
      await _previewPlayer.play(AssetSource(filePath));
      setState(() => _isPlaying = true);

      _previewPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      debugPrint('Preview error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringtone file not found. Add MP3 to assets/audio/')),
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings.authorizationStatus == AuthorizationStatus.authorized
                ? 'Notifications enabled'
                : 'Notifications permission denied. Enable in settings.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildSectionHeader(context, 'Message Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.message_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Message Tones',
                subtitle: 'Play sound for new messages',
                value: settingsProvider.messageTones,
                onChanged: (value) => settingsProvider.setMessageTones(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.group_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Group Notifications',
                subtitle: 'Notifications for group messages',
                value: settingsProvider.groupNotifications,
                onChanged: (value) => settingsProvider.setGroupNotifications(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.campaign_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Channel Notifications',
                subtitle: 'Notifications for channel updates',
                value: settingsProvider.channelNotifications,
                onChanged: (value) => settingsProvider.setChannelNotifications(value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Call Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.call_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Voice & Video Calls',
                subtitle: 'Notifications for incoming calls',
                value: settingsProvider.voiceVideoCalls,
                onChanged: (value) => settingsProvider.setVoiceVideoCalls(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              // NEW: Ringtone picker
              _buildRingtoneTile(context),
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'In-App Notifications'),

          _buildCard(
            children: [
              _buildToggleTile(
                context,
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'In-App Sounds',
                subtitle: 'Play sounds while using the app',
                value: settingsProvider.inAppSounds,
                onChanged: (value) => settingsProvider.setInAppSounds(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.vibration_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'In-App Vibrate',
                subtitle: 'Vibrate while using the app',
                value: settingsProvider.inAppVibrate,
                onChanged: (value) => settingsProvider.setInAppVibrate(value),
              ),
              const Divider(height: 1, color: Color(0xFF2A1A4E), indent: 72),
              _buildToggleTile(
                context,
                icon: Icons.preview_outlined,
                iconColor: const Color(0xFF06B6D4),
                title: 'Show Preview',
                subtitle: 'Show message preview in notifications',
                value: settingsProvider.showPreview,
                onChanged: (value) => settingsProvider.setShowPreview(value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // NEW: System notification permission button
          _buildCard(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
                  ),
                  child: const Icon(Icons.settings_applications, color: Color(0xFF8B5CF6), size: 22),
                ),
                title: const Text(
                  'System Notification Settings',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  'Open device notification settings',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                onTap: _requestNotificationPermission,
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildInfoCard(context),
        ],
      ),
    );
  }

  // NEW: Ringtone picker tile
  Widget _buildRingtoneTile(BuildContext context) {
    final selectedName = _ringtones.firstWhere(
      (r) => r['id'] == _selectedRingtone,
      orElse: () => _ringtones[0],
    )['name'];

    return InkWell(
      onTap: () => _showRingtonePicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
              ),
              child: const Icon(Icons.music_note, color: Color(0xFF8B5CF6), size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call Ringtone',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedName,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  // NEW: Ringtone picker bottom sheet
  void _showRingtonePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Call Ringtone',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a ringtone for incoming calls',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
                const SizedBox(height: 24),
                ..._ringtones.map((ringtone) {
                  final isSelected = _selectedRingtone == ringtone['id'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6).withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8B5CF6)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF8B5CF6).withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.music_note : Icons.music_note_outlined,
                          color: isSelected ? const Color(0xFF8B5CF6) : Colors.white54,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        ringtone['name'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying && isSelected ? Icons.stop : Icons.play_arrow,
                              color: Colors.white54,
                            ),
                            onPressed: () => _previewRingtone(ringtone['file']),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
                          else
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.white54),
                              onPressed: () {
                                _setRingtone(ringtone['id']);
                                setModalState(() {});
                              },
                            ),
                        ],
                      ),
                      onTap: () {
                        _setRingtone(ringtone['id']);
                        setModalState(() {});
                      },
                    ),
                  );
                }).toList(),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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
    return Container(
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
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
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
        style: const TextStyle(
          color: Colors.white,
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
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF8B5CF6),
        activeTrackColor: const Color(0xFF8B5CF6).withOpacity(0.3),
        inactiveThumbColor: Colors.white.withOpacity(0.5),
        inactiveTrackColor: Colors.white.withOpacity(0.1),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a103c),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.25),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF8B5CF6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notification Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These settings control how you receive notifications. You can customize sounds, vibrations, and previews for different types of messages.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
