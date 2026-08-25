import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/status_service.dart';
import '../../services/app_localizations.dart';
import 'package:video_player/video_player.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<Map<String, dynamic>> _statuses = [];
  bool _isLoading = true;
  int _myStatusRefreshKey = 0;

  static const Color _bgDark = Color(0xFF0A0A0F);
  static const Color _bgCard = Color(0xFF1a103c);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    _loadStatuses();
    unawaited(StatusService.deleteExpiredStatuses());
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
    } else {
      setState(() => _isLoading = false);
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
      await _refreshAll();
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
      await _refreshAll();
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
              await _refreshAll();

              setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _purple),
            child: Text(AppLocalizations.get('post') ?? 'Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    await _loadStatuses();
    setState(() => _myStatusRefreshKey++);
  }

  void _viewStatus(Map<String, dynamic> status) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    if (userId != null && status['user_id'] != userId) {
      await StatusService.markAsViewed(status['id'], userId);
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StatusViewerScreen(status: status),
        ),
      ).then((_) {
        _refreshAll();
      });
    }
  }

  void _onMyStatusTap(List<Map<String, dynamic>> myStatuses) async {
    if (myStatuses.isEmpty) {
      _showAddStatusOptions(context);
    } else {
      final latestStatus = myStatuses.first;
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        final statusWithUser = {
          ...latestStatus,
          'is_mine': true,
          'users': {
            'username': userData?['username'] ?? 'You',
            'avatar_url': userData?['avatar_url'],
          },
        };
        
        if (mounted) {
          _viewStatus(statusWithUser);
        }
      }
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

              FutureBuilder<List<Map<String, dynamic>>>(
                key: ValueKey(_myStatusRefreshKey),
                future: userId != null ? StatusService.getMyStatuses(userId) : Future.value([]),
                builder: (context, snapshot) {
                  final myStatuses = snapshot.data ?? [];
                  final hasStatus = myStatuses.isNotEmpty;
                  final latestStatus = hasStatus ? myStatuses.first : null;

                  return Padding(
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
                              gradient: hasStatus && latestStatus?['media_url'] == null
                                  ? const LinearGradient(colors: [_purple, _cyan])
                                  : null,
                              image: hasStatus && latestStatus?['media_url'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(latestStatus!['media_url']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              border: Border.all(
                                color: hasStatus ? _cyan.withOpacity(0.8) : _purple.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: !hasStatus || latestStatus?['media_url'] == null
                                ? const Icon(Icons.person, color: Colors.white70, size: 28)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showAddStatusOptions(context),
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
                          ),
                        ],
                      ),
                      title: Text(
                        'My Status',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            hasStatus
                                ? '${_getTimeAgo((latestStatus!['created_at'] as Timestamp).toDate())} • '
                                : 'Tap + to add status',
                            style: TextStyle(color: Colors.white.withOpacity(0.4)),
                          ),
                          if (hasStatus) ...[
                            Icon(
                              Icons.remove_red_eye,
                              size: 12,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${latestStatus!['view_count'] ?? 0}',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _onMyStatusTap(myStatuses),
                      onLongPress: () => _showAddStatusOptions(context),
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white12, indent: 24, endIndent: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _statuses.isEmpty ? 'No updates yet' : 'Recent Updates',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),

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
                            onRefresh: _refreshAll,
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
    final viewCount = status['view_count'] ?? 0;
    final likes = status['likes'] ?? [];

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
        subtitle: Row(
          children: [
            Text(
              timeAgo,
              style: TextStyle(color: Colors.white.withOpacity(0.4)),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.remove_red_eye,
              size: 14,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 4),
            Text(
              '$viewCount',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.favorite,
              size: 14,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(width: 4),
            Text(
              '${likes.length}',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
          ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
// STATUS VIEWER SCREEN
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
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _checkIfLiked();
  }

  void _initController() {
    final type = widget.status['type'] ?? 'image';
    final duration = _getDuration(type);

    _progressController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _progressController.forward().then((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  void _checkIfLiked() {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    final likes = widget.status['likes'] ?? [];
    setState(() => _isLiked = likes.contains(userId));
  }

  Duration _getDuration(String type) {
    switch (type) {
      case 'video':
        return const Duration(seconds: 30);
      case 'text':
        return const Duration(seconds: 5);
      case 'image':
      default:
        return const Duration(seconds: 5);
    }
  }

  void _onVideoInitialized(VideoPlayerController controller) {
    if (!mounted) return;
    final videoDuration = controller.value.duration;
    if (videoDuration.inSeconds > 0) {
      _progressController.duration = videoDuration;
      _progressController.forward(from: _progressController.value);
    }
    setState(() => _isVideoReady = true);
  }

  void _pauseProgress() {
    if (_progressController.isAnimating) {
      _progressController.stop();
    }
  }

  void _resumeProgress() {
    if (!_progressController.isCompleted) {
      _progressController.forward();
    }
  }

  Future<void> _toggleLike(String statusId) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return;

    await StatusService.toggleLike(statusId, userId);
    setState(() => _isLiked = !_isLiked);
  }

  void _showViewsList(String statusId) async {
    _pauseProgress();
    final views = await StatusService.getViews(statusId);

    if (!mounted) return;

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
            Text(
              'Viewed by ${views.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (views.isEmpty)
              Text(
                'No views yet',
                style: TextStyle(color: Colors.white.withOpacity(0.4)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: views.length,
                  itemBuilder: (context, index) {
                    final view = views[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: view['avatar_url'] != null
                            ? NetworkImage(view['avatar_url'])
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: view['avatar_url'] == null
                            ? Text(
                                (view['username'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Text(
                        view['username'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _getTimeAgo((view['viewed_at'] as Timestamp).toDate()),
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ).whenComplete(() => _resumeProgress());
  }

  void _showReplyDialog(Map<String, dynamic> status) {
    _pauseProgress();
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Reply to Status', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Type a message...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeProgress();
            },
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              final userId = authProvider.user?.uid ?? authProvider.mockUserId;
              if (userId == null) return;

              await StatusService.replyToStatus(status['id'], userId, controller.text.trim());
              Navigator.pop(context);
              _resumeProgress();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reply sent!'),
                    backgroundColor: Color(0xFF8B5CF6),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(() => _resumeProgress());
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    final isMine = status['user_id'] == userId || status['is_mine'] == true;
    final username = status['users']?['username'] ?? 'Unknown';
    final avatar = status['users']?['avatar_url'];
    final mediaUrl = status['media_url'];
    final caption = status['caption'] ?? '';
    final type = status['type'] ?? 'image';
    final viewCount = status['view_count'] ?? 0;
    final likes = status['likes'] ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        onLongPressStart: (_) => _pauseProgress(),
        onLongPressEnd: (_) => _resumeProgress(),
        child: Stack(
          children: [
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
                  : type == 'video' && mediaUrl != null
                      ? _buildVideoPlayer(mediaUrl)
                      : Image.network(
                          mediaUrl ?? '',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white30, size: 64),
                          ),
                        ),
            ),

            SafeArea(
              child: Column(
                children: [
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
                                  username.isNotEmpty ? username[0].toUpperCase() : '?',
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

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleLike(status['id']),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: _isLiked ? Colors.red : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${likes.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: isMine ? () => _showViewsList(status['id']) : null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.remove_red_eye,
                              color: isMine ? Colors.white : Colors.white.withOpacity(0.5),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$viewCount',
                              style: TextStyle(
                                color: isMine ? Colors.white : Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!isMine)
                        GestureDetector(
                          onTap: () => _showReplyDialog(status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Reply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            if (caption.isNotEmpty && type != 'text')
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    caption,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(String url) {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController!.initialize().then((_) {
      _onVideoInitialized(_videoController!);
      _videoController!.play();
    });

    return VideoPlayer(_videoController!);
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
