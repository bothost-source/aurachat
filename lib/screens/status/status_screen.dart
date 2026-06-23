import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/status_service.dart';
import '../../services/app_localizations.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> _statuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    final statuses = await StatusService.getActiveStatuses();
    setState(() {
      _statuses = statuses;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080);
    if (picked == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? authProvider.mockUserId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    final url = await StatusService.uploadStatusMedia(File(picked.path), userId, 'image');
    if (url != null) {
      await StatusService.createMediaStatus(userId, url, 'image');
      await _loadStatuses();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? authProvider.mockUserId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    final url = await StatusService.uploadStatusMedia(File(picked.path), userId, 'video');
    if (url != null) {
      await StatusService.createMediaStatus(userId, url, 'video');
      await _loadStatuses();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _addTextStatus() async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: Text(AppLocalizations.get('text_status'), style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLength: 140,
          decoration: InputDecoration(
            hintText: "What's on your mind?",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.get('cancel'), style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userId = authProvider.user?.id ?? authProvider.mockUserId;
              if (userId == null) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              await StatusService.createTextStatus(userId, controller.text.trim());
              await _loadStatuses();
              
              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: Text(AppLocalizations.get('post') ?? 'Post'),
          ),
        ],
      ),
    );
  }

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.settings,
              label: AppLocalizations.get('settings') ?? 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            _buildOptionTile(
              icon: Icons.privacy_tip,
              label: AppLocalizations.get('privacy') ?? 'Privacy',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/privacy_settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.user?.id ?? authProvider.mockUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ).createShader(bounds),
                    child: const Text(
                      'AURA',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () {
                      Navigator.pushNamed(context, '/global_search');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onPressed: () {
                      _showStatusMenu(context);
                    },
                  ),
                ],
              ),
            ),

            // My Status
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                        ),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.person, color: Colors.white70, size: 28),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0A0A0F),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.add, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  AppLocalizations.get('my_status'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  AppLocalizations.get('tap_add_status'),
                  style: TextStyle(color: Colors.white.withOpacity(0.4)),
                ),
                onTap: () => _showAddStatusOptions(context),
              ),
            ),

            const Divider(color: Colors.white12, indent: 24, endIndent: 24),

            // Recent updates
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.get('recent_updates'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.4),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Statuses list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                      ),
                    )
                  : _statuses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.circle_outlined,
                                size: 64,
                                color: Colors.white.withOpacity(0.1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.get('no_status_updates'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocalizations.get('tap_share_first_status'),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadStatuses,
                          color: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF1a103c),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _statuses.length,
                            itemBuilder: (context, index) {
                              final status = _statuses[index];
                              return _buildStatusItem(status);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddStatusOptions(context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.camera_alt, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatusItem(Map<String, dynamic> status) {
    final username = status['users']?['username'] ?? 'Unknown';
    final avatar = status['users']?['avatar_url'];
    final mediaUrl = status['media_url'];
    final caption = status['caption'] ?? '';
    final type = status['type'] ?? 'image';
    final createdAt = DateTime.parse(status['created_at']);
    final timeAgo = _getTimeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: avatar == null
                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)])
                : null,
            image: avatar != null
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null,
          ),
          child: avatar == null ? const Icon(Icons.person, color: Colors.white70) : null,
        ),
        title: Text(
          username,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          timeAgo,
          style: TextStyle(color: Colors.white.withOpacity(0.4)),
        ),
        trailing: type == 'text'
            ? Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    caption.length > 20 ? '${caption.substring(0, 20)}...' : caption,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    color: Colors.white.withOpacity(0.1),
                    child: const Icon(Icons.image, color: Colors.white30),
                  ),
                ),
              ),
        onTap: () {
          // TODO: View full status
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showAddStatusOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.camera_alt,
              label: AppLocalizations.get('camera'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _buildOptionTile(
              icon: Icons.photo_library,
              label: AppLocalizations.get('gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            _buildOptionTile(
              icon: Icons.videocam,
              label: AppLocalizations.get('video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            _buildOptionTile(
              icon: Icons.text_fields,
              label: AppLocalizations.get('text_status'),
              onTap: () {
                Navigator.pop(context);
                _addTextStatus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF8B5CF6),
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}
