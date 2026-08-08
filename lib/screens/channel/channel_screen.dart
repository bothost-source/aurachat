import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/cloudinary_service.dart';

class ChannelChatScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelChatScreen({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  File? _selectedImage;

  static const Color _bgDark = Color(0xFF0A0A0F);
  static const Color _bgCard = Color(0xFF1a103c);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _cyan = Color(0xFF06B6D4);

  Stream<QuerySnapshot> get _messagesStream => FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.channelId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null) throw Exception('Not authenticated');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final senderName = userData['username'] ?? 'Admin';
      final senderAvatar = userData['avatar_url'];

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await CloudinaryService.uploadImage(
          _selectedImage!,
          'aurachat/channels/${widget.channelId}'
        );
        if (imageUrl == null) throw Exception('Image upload failed');
      }

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.channelId)
          .collection('messages')
          .add({
        'text': text.isNotEmpty ? text : null,
        'image_url': imageUrl,
        'sender_id': userId,
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.channelId)
          .update({
        'last_message': text.isNotEmpty ? text : '📷 Image',
        'last_message_at': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      setState(() => _selectedImage = null);
    } catch (e) {
      _showError('Failed to send: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('HH:mm').format(timestamp.toDate());
  }

  Widget _buildMessageAvatar(String? avatarUrl, String? username) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: _purple.withOpacity(0.3),
      child: Text(
        (username ?? 'A')[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _purple.withOpacity(0.2),
                      child: const Icon(Icons.campaign, color: _purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.channelName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Channel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onPressed: () {
                        Navigator.pushNamed(context, '/channel_info', arguments: {
                          'chatId': widget.channelId,
                          'chatName': widget.channelName,
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Messages — All left-aligned like Telegram
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: _purple),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to post!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index].data() as Map<String, dynamic>;
                        final hasImage = msg['image_url'] != null;

                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _buildMessageAvatar(msg['sender_avatar'], msg['sender_name']),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        msg['sender_name'] ?? 'Admin',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatTime(msg['timestamp'] as Timestamp?),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (hasImage) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      msg['image_url'],
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          height: 200,
                                          color: Colors.white.withOpacity(0.05),
                                          child: const Center(
                                            child: CircularProgressIndicator(color: _purple),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (msg['text'] != null) const SizedBox(height: 8),
                                ],
                                if (msg['text'] != null)
                                  Text(
                                    msg['text'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Selected image preview
              if (_selectedImage != null)
                Container(
                  height: 100,
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImage!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Input area — Only show for admins/owner
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('chats').doc(widget.channelId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  
                  final chatData = snapshot.data!.data() as Map<String, dynamic>?;
                  final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
                  final userId = authProvider.user?.uid ?? authProvider.mockUserId;
                  final myRole = (chatData?['participants_data']?[userId]?['role'] ?? 'member') as String;
                  final canPost = myRole == 'owner' || myRole == 'admin';
                  
                  if (!canPost) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.white.withOpacity(0.03),
                      child: Center(
                        child: Text(
                          'Only admins can post in this channel',
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image, color: _purple),
                            onPressed: _pickImage,
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _messageController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Message...',
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isLoading ? null : _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [_purple, _cyan]),
                                shape: BoxShape.circle,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
