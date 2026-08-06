import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
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

  // Theme colors
  static const Color _bgDark = Color(0xFF0A0A0F);
  static const Color _bgCard = Color(0xFF1a103c);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    if (userId != null) {
      final statuses = await StatusService.getContactStatuses(userId);
      setState(() {
        _statuses = statuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1080);
    if (picked == null) return;

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
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

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
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
        backgroundColor: _bgCard,
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

              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              final userId = authProvider.user?.uid ?? authProvider.mockUserId;
              if (userId == null) return;

              Navigator.pop(context);
              setState(() => _isLoading = true);

              await StatusService.createTextStatus(userId, controller.text.trim());
              await _loadStatuses();

              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            child: Text(AppLocalizations.get('post') ?? 'Post'),
          ),
        ],
      ),
    );
  }

  void _viewStatus(Map<String, dynamic> status) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    // Mark as viewed (if not mine)
    if (userId != null && status['user_id'] != userId) {
      await StatusService.markAsViewed(status['id'], userId);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusViewerScreen(status: status),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgDark, _bgCard, Color(0xFF0f172a)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [_purple, _cyan],
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
                      onPressed: () => Navigator.pushNamed(context, '/global_search'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onPressed: () => _showStatusMenu(context),
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
                          gradient: const LinearGradient(colors: [_purple, _cyan]),
                          border: Border.all(
                            color: _purple.withOpacity(0.5),
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
                            color: _purple,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bgDark, width: 2),
                          ),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  title: const Text(
                    'My Status',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tap to add status',
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
                    _statuses.isEmpty ? 'No contacts yet' : 'Recent Updates',
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
                        child: CircularProgressIndicator(color: _purple),
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
                                  'No status updates',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Save contacts to see their status',
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
                            color: _purple,
                            backgroundColor: _bgCard,
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
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple, _cyan]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(0.4),
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
    final createdAt = (status['created_at'] as Timestamp).toDate();
    final timeAgo = _getTimeAgo(createdAt);
    final isMine = status['is_mine'] == true;

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
                ? const LinearGradient(colors: [_purple, _cyan])
                : null,
            image: avatar != null
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null,
            border: Border.all(
              color: isMine ? _purple.withOpacity(0.5) : _cyan.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: avatar == null ? const Icon(Icons.person, color: Colors.white70) : null,
        ),
        title: Text(
          isMine ? 'You' : username,
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
                  color: _purple.withOpacity(0.2),
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
        onTap: () => _viewStatus(status),
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
      backgroundColor: _bgCard,
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
              label: 'Camera',
              onTap: () => Navigator.pop(context),
            ),
            _buildOptionTile(
              icon: Icons.photo_library,
              label: 'Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            _buildOptionTile(
              icon: Icons.videocam,
              label: 'Video',
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            _buildOptionTile(
              icon: Icons.text_fields,
              label: 'Text Status',
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

  void _showStatusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgCard,
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

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _purple,
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

// ============================================================================
// STATUS VIEWER SCREEN — Full screen like WhatsApp stories
// ============================================================================
class StatusViewerScreen extends StatefulWidget {
  final Map<String, dynamic> status;

  const StatusViewerScreen({super.key, required this.status});

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward().then((_) => Navigator.pop(context));
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final username = status['users']?['username'] ?? 'Unknown';
    final avatar = status['users']?['avatar_url'];
    final mediaUrl = status['media_url'];
    final caption = status['caption'] ?? '';
    final type = status['type'] ?? 'image';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            // Media content
            Center(
              child: type == 'text'
                  ? Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Image.network(
                      mediaUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),

            // Top bar with progress
            SafeArea(
              child: Column(
                children: [
                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressController.value,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      );
                    },
                  ),

                  // User info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                          backgroundColor: const Color(0xFF8B5CF6),
                          child: avatar == null
                              ? Text(
                                  username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getTimeAgo((status['created_at'] as Timestamp).toDate()),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
