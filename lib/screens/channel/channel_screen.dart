import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/cloudinary_service.dart';
import '../../services/ai_moderation_service.dart';
import '../../utils/verified_badge.dart';
import 'channel_info_screen.dart';

class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  const ChannelChatScreen({super.key, required this.channelId, required this.channelName});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isAdmin = false;
  String? _myRole;
  Map<String, dynamic>? _channelSettings;
  bool _canSend = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _setTyping(false);
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) { _setTyping(true); }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () => _setTyping(false));
  }

  Future<void> _setTyping(bool typing) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;
    _isTyping = typing;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.channelId)
        .collection('typing')
        .doc(currentUserId)
        .set({'isTyping': typing, 'name': authProvider.phoneNumber ?? 'User', 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<void> _loadPermissions() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance.collection('chats').doc(widget.channelId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final role = (data['participants_data']?[userId]?['role'] ?? 'member') as String;
      final settings = data['settings'] as Map<String, dynamic>?;

      setState(() {
        _myRole = role;
        _isAdmin = role == 'owner' || role == 'admin';
        _channelSettings = settings;
        // In channels, only owner/admin can send messages
        _canSend = _isAdmin;
      });
    }
  }

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && imageUrl == null) return;
    if (!_canSend) {
      _showPermissionDenied();
      return;
    }

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    _messageController.clear();
    _setTyping(false);

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final userData = userDoc.data();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.channelId)
        .collection('messages')
        .add({
      'text': text.isNotEmpty ? text : null,
      'imageUrl': imageUrl,
      'senderId': currentUserId,
      'senderName': userData?['username'] ?? 'Unknown',
      'senderPhoto': userData?['avatar_url'],
      'timestamp': FieldValue.serverTimestamp(),
      'type': imageUrl != null ? 'image' : 'text',
    });

    await FirebaseFirestore.instance.collection('chats').doc(widget.channelId).update({
      'lastMessage': imageUrl != null ? '📷 Photo' : text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': currentUserId,
    });

    _scrollToBottom();
  }

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only channel admins can send messages'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    if (!_canSend) { _showPermissionDenied(); return; }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (image == null) return;

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 12), Text('Uploading...'),
      ]), duration: Duration(seconds: 30)),
    );

    final mediaUrl = await CloudinaryService.uploadImage(File(image.path), 'aurachat/chats/${widget.channelId}');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (mediaUrl != null) {
      await _sendMessage(imageUrl: mediaUrl);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    if (!_isAdmin) return;
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.channelId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showMessageOptions(String messageId, String senderId) {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    final canDelete = senderId == currentUserId || _isAdmin;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(context); _deleteMessage(messageId); },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(messageId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white54),
              title: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(String messageId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Report Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Why are you reporting this?',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              final reporterId = authProvider.user?.uid ?? authProvider.mockUserId;
              if (reporterId != null) {
                final msgDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.channelId).collection('messages').doc(messageId).get();
                final msgData = msgDoc.data();
                final result = await AIModerationService.analyzeReport(
                  messageContent: msgData?['text'] ?? '',
                  reporterId: reporterId,
                  reportedUserId: msgData?['senderId'] ?? '',
                  chatId: widget.channelId,
                  messageId: messageId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Report submitted')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PhotoView(imageProvider: NetworkImage(imageUrl), minScale: PhotoViewComputedScale.contained, maxScale: PhotoViewComputedScale.covered * 2),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('chats').doc(widget.channelId).snapshots(),
          builder: (context, snapshot) {
            String name = widget.channelName;
            int count = 0;
            String? creatorPhone;
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              name = data['name'] ?? widget.channelName;
              count = data['member_count'] ?? 0;
              creatorPhone = data['created_by_phone'] as String?;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VerifiedUsername(
                  username: name,
                  phoneNumber: creatorPhone,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  badgeSize: 14,
                  spacing: 6,
                ),
                Text('$count members', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            );
          },
        ),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelInfoScreen(
                  chatId: widget.channelId,
                  chatName: widget.channelName,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Admin-only banner
          if (!_canSend)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.15),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a channel. Only admins can send messages.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Typing indicator
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('chats').doc(widget.channelId).collection('typing').where('isTyping', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
              final typings = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['timestamp'] != null && d.id != currentUserId;
              }).toList();
              if (typings.isEmpty) return const SizedBox.shrink();
              final names = typings.map((d) => (d.data() as Map<String, dynamic>)['name'] ?? 'Someone').join(', ');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                alignment: Alignment.centerLeft,
                child: Text('$names ${typings.length == 1 ? 'is' : 'are'} typing...', style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
              );
            },
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.channelId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error', style: TextStyle(color: Colors.white)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));

                final messages = snapshot.data!.docs;
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet\nAdmins will post updates here', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final data = msg.data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserId;
                    final timestamp = data['timestamp'] as Timestamp?;
                    final hasImage = data['imageUrl'] != null;

                    return GestureDetector(
                      onLongPress: () => _showMessageOptions(msg.id, data['senderId'] ?? ''),
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMe)
                                Row(
                                  children: [
                                    if (data['senderPhoto'] != null)
                                      CircleAvatar(radius: 10, backgroundImage: NetworkImage(data['senderPhoto']), onBackgroundImageError: (_, __) {}),
                                    const SizedBox(width: 6),
                                    Text(data['senderName'] ?? 'Unknown', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              if (hasImage)
                                GestureDetector(
                                  onTap: () => _showImageViewer(data['imageUrl']),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: data['imageUrl'],
                                      fit: BoxFit.cover,
                                      width: 200,
                                      placeholder: (context, url) => Container(width: 200, height: 150, color: Colors.white12, child: const Center(child: CircularProgressIndicator(color: Colors.white54))),
                                      errorWidget: (context, url, error) => Container(width: 200, height: 150, color: Colors.white12, child: const Icon(Icons.error, color: Colors.white54)),
                                    ),
                                  ),
                                ),
                              if (data['text'] != null && (data['text'] as String).isNotEmpty)
                                Text(data['text'], style: const TextStyle(color: Colors.white, fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(timestamp != null ? DateFormat('h:mm a').format(timestamp.toDate()) : '', style: TextStyle(color: isMe ? Colors.white70 : Colors.white54, fontSize: 11)),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.done_all, size: 14, color: Colors.white70),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Input (admin only)
          if (_canSend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(color: Color(0xFF1C1C1E), border: Border(top: BorderSide(color: Colors.white12))),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.attach_file, color: Colors.white54), onPressed: _pickAndSendImage),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Post an update...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _sendMessage()),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF1C1C1E), border: Border(top: BorderSide(color: Colors.white12))),
              child: const SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility, color: Colors.white54, size: 16),
                    SizedBox(width: 8),
                    Text('View-only mode', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
