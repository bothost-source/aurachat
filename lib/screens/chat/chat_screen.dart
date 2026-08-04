import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/ai_moderation_service.dart';
import '../../utils/verified_badge.dart';
import '../groups/group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;
  final String? chatAvatar;
  final bool isGroup;

  const ChatScreen({
    super.key,
    this.chatId,
    this.chatName,
    this.chatAvatar,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _editController = TextEditingController();
  final _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _showEmojiPicker = false;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messageSubscription;
  bool _isLoading = true;
  String? _replyingTo;
  String? _editingMessageId;

  String? _chatId;
  String? _chatName;
  String? _chatAvatar;
  bool _isGroup = false;
  String? _creatorPhone;
  String? _myRole;
  Map<String, dynamic>? _chatSettings;
  bool _canSend = true;
  bool _canSendFiles = true;
  bool _isAnnouncementsOnly = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _chatId = args['chatId'] as String?;
      _chatName = args['chatName'] as String?;
      _chatAvatar = args['chatAvatar'] as String?;
      _isGroup = args['isGroup'] as bool? ?? false;
    }

    if (_chatId != null && _messages.isEmpty && _isLoading) {
      _loadMessages();
      _subscribeToMessages();
      _loadChatInfo();
      _subscribeToChatInfo();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChatInfo() async {
    if (_chatId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
        final userId = authProvider.user?.uid ?? authProvider.mockUserId;

        if (mounted) {
          setState(() {
            _creatorPhone = data['created_by_phone'] as String?;
            _chatSettings = data['settings'] as Map<String, dynamic>?;
            _myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;

            final isAdmin = _myRole == 'owner' || _myRole == 'admin';
            _canSend = !(_chatSettings?['chat_disabled'] == true && !isAdmin);
            _canSendFiles = !(_chatSettings?['file_sharing_disabled'] == true && !isAdmin);
            _isAnnouncementsOnly = _chatSettings?['announcements_only'] == true && !isAdmin;
          });
        }
      }
    } catch (e) {
      debugPrint('Load chat info error: $e');
    }
  }

  void _subscribeToChatInfo() {
    if (_chatId == null) return;
    FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .snapshots()
        .listen((doc) {
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
        final userId = authProvider.user?.uid ?? authProvider.mockUserId;

        setState(() {
          _chatSettings = data['settings'] as Map<String, dynamic>?;
          _myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;

          final isAdmin = _myRole == 'owner' || _myRole == 'admin';
          _canSend = !(_chatSettings?['chat_disabled'] == true && !isAdmin);
          _canSendFiles = !(_chatSettings?['file_sharing_disabled'] == true && !isAdmin);
          _isAnnouncementsOnly = _chatSettings?['announcements_only'] == true && !isAdmin;
        });
      }
    });
  }

  Future<void> _loadMessages() async {
    if (_chatId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .orderBy('created_at', descending: false)
          .get();

      final List<Map<String, dynamic>> loadedMessages = [];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['sender_id'] as String?;

        if (senderId != null) {
          final userDoc = await firestore.collection('users').doc(senderId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            data['users'] = {
              'username': userData['username'],
              'avatar_url': userData['avatar_url'],
              'bio': userData['bio'],
              'phone_number': userData['phone'],
            };
          }
        }

        loadedMessages.add({
          'id': doc.id,
          ...data,
          'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
        });
      }

      setState(() {
        _messages = loadedMessages;
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    if (_chatId == null) return;

    final firestore = FirebaseFirestore.instance;
    _messageSubscription = firestore
        .collection('chats')
        .doc(_chatId!)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snapshot) async {
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final data = doc.data()!;
            final messageId = doc.id;

            if (change.type == DocumentChangeType.added) {
              final exists = _messages.any((m) => m['id'] == messageId);
              if (!exists) {
                final senderId = data['sender_id'] as String?;
                if (senderId != null) {
                  final userDoc = await firestore.collection('users').doc(senderId).get();
                  if (userDoc.exists) {
                    final userData = userDoc.data()!;
                    data['users'] = {
                      'username': userData['username'],
                      'avatar_url': userData['avatar_url'],
                      'bio': userData['bio'],
                      'phone_number': userData['phone'],
                    };
                  }
                }

                setState(() {
                  _messages.add({
                    'id': messageId,
                    ...data,
                    'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
                  });
                });
                _scrollToBottom();
              }
            } else if (change.type == DocumentChangeType.modified) {
              setState(() {
                final index = _messages.indexWhere((m) => m['id'] == messageId);
                if (index >= 0) {
                  _messages[index] = {
                    'id': messageId,
                    ...data,
                    'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
                  };
                }
              });
            } else if (change.type == DocumentChangeType.removed) {
              setState(() {
                _messages.removeWhere((m) => m['id'] == messageId);
              });
            }
          }
        });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendTextMessage() async {
    if (!_canSend || _isAnnouncementsOnly) {
      _showPermissionDenied();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _showEmojiPicker = false);

    await _sendMessage(type: 'text', content: text);
  }

  Future<void> _sendMessage({
  required String type,
  required String content,
  String? mediaUrl,
  String? fileName,
  String? fileSize,
}) async {
  try {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final firestore = FirebaseFirestore.instance;
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;

    if (userId == null || _chatId == null) return;

    final messageId = const Uuid().v4();

    final message = {
      'id': messageId,
      'chat_id': _chatId!,
      'sender_id': userId,
      'type': type,
      'chat_type': _isGroup ? 'group' : 'direct',
      'content': content,
      'media_url': mediaUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'reply_to': _replyingTo,
      'created_at': FieldValue.serverTimestamp(),
      'is_read': false,
      'is_edited': false,
      'sent_to_fcm': false, // ← NEW: flag for Cloud Function to pick up
    };

    await firestore
        .collection('chats')
        .doc(_chatId!)
        .collection('messages')
        .doc(messageId)
        .set(message);

    await firestore.collection('chats').doc(_chatId!).update({
      'last_message': content,
      'last_message_at': FieldValue.serverTimestamp(),
    });

    setState(() => _replyingTo = null);
    _scrollToBottom();
  } catch (e) {
    debugPrint('Send message error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }
}

  void _showPermissionDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only admins can send messages in this chat'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _editMessage(String messageId, String newContent) async {
    if (newContent.trim().isEmpty) return;

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newContent.trim(),
        'is_edited': true,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _editingMessageId = null;
        _editController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message edited')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edit failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  void _showEditDialog(String messageId, String currentContent) {
    _editController.text = currentContent;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: _editController,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _editController.clear();
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editMessage(messageId, _editController.text);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            if (isMe && message['type'] == 'text') ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                ),
                title: const Text('Edit', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message['id'], message['content'] ?? '');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.delete, color: Colors.red),
                ),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message['id']);
                },
              ),
            ],
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.reply, color: Color(0xFF06B6D4)),
              ),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = message['id']);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.report, color: Colors.orange),
              ),
              title: const Text('Report', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(Map<String, dynamic> message) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Report Message', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this message?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add details (optional)...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
              final reporterId = authProvider.user?.uid ?? authProvider.mockUserId;

              if (reporterId != null) {
                final result = await AIModerationService.analyzeReport(
                  messageContent: message['content'] ?? '',
                  reporterId: reporterId,
                  reportedUserId: message['sender_id'] ?? '',
                  chatId: _chatId ?? '',
                  messageId: message['id'] ?? '',
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Report submitted')),
                  );
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

  Future<void> _pickImage() async {
    if (!_canSendFiles) {
      _showPermissionDenied();
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      await _uploadAndSendMedia(file: File(pickedFile.path), type: 'image');
    }
  }

  Future<void> _takePhoto() async {
    if (!_canSendFiles) {
      _showPermissionDenied();
      return;
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      await _uploadAndSendMedia(file: File(pickedFile.path), type: 'image');
    }
  }

  Future<void> _pickFile() async {
    if (!_canSendFiles) {
      _showPermissionDenied();
      return;
    }
    final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        await _uploadAndSendMedia(
          file: File(file.path!),
          type: 'file',
          fileName: file.name,
          fileSize: _formatFileSize(file.size),
        );
      }
    }
  }

  Future<void> _uploadAndSendMedia({
    required File file,
    required String type,
    String? fileName,
    String? fileSize,
  }) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Uploading...'),
          ]),
          duration: Duration(seconds: 30),
        ),
      );

      final mediaUrl = await CloudinaryService.uploadImage(file, 'aurachat/chats/$_chatId');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mediaUrl == null) throw Exception('Upload failed');

      await _sendMessage(
        type: type,
        content: fileName ?? 'Image',
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _playAudio(String messageId, String audioUrl) async {
    try {
      if (_currentlyPlayingAudioId == messageId) {
        await _audioPlayer.stop();
        setState(() { _isPlayingAudio = false; _currentlyPlayingAudioId = null; });
      } else {
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
        setState(() { _isPlayingAudio = true; _currentlyPlayingAudioId = messageId; });
        _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() { _isPlayingAudio = false; _currentlyPlayingAudioId = null; });
          }
        });
      }
    } catch (e) {
      debugPrint('Play audio error: $e');
    }
  }

  Future<void> _openFile(String url, String? fileName) async {
    try {
      final dir = await getTemporaryDirectory();
      final ext = fileName?.split('.').last ?? 'file';
      final localPath = '${dir.path}/${const Uuid().v4()}.$ext';
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final file = File(localPath);
      await response.pipe(file.openWrite());
      await OpenFilex.open(localPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open file: $e')));
    }
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
            PhotoView(
              imageProvider: NetworkImage(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
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
    final isAdmin = _myRole == 'owner' || _myRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _isGroup && _chatId != null
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(
                    chatId: _chatId!,
                    chatName: _chatName ?? 'Group',
                    chatAvatar: _chatAvatar,
                    isChannel: false,
                  ),
                ),
              )
            : null,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 10)],
                ),
                child: _buildChatAvatar(_chatAvatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VerifiedUsername(
                      username: _chatName ?? 'Chat',
                      phoneNumber: _isGroup ? _creatorPhone : null,
                      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      badgeSize: 14,
                      spacing: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _isGroup ? '$_myRole \u2022 Tap for info' : 'Online',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF06B6D4).withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Colors.white70), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call, color: Colors.white70), onPressed: () {}),
          if (_isGroup && _chatId != null)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white70),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupInfoScreen(
                    chatId: _chatId!,
                    chatName: _chatName ?? 'Group',
                    chatAvatar: _chatAvatar,
                    isChannel: false,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_canSend || _isAnnouncementsOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAnnouncementsOnly
                        ? 'Announcements only - only admins can send messages'
                        : 'Chat is disabled by admin',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6))))
              : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == currentUserId;
                      final showAvatar = !isMe && (index == 0 || _messages[index - 1]['sender_id'] != message['sender_id']);

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(message, isMe),
                        child: _buildMessageBubble(context, message: message, isMe: isMe, showAvatar: showAvatar),
                      );
                    },
                  ),
          ),

          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1a103c),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Replying to message', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) => _messageController.text += emoji.emoji,
                config: Config(
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7, emojiSizeMax: 32, verticalSpacing: 0, horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero, recentsLimit: 28, replaceEmojiOnLimitExceed: false,
                    noRecents: const Text('No Recents', style: TextStyle(fontSize: 20, color: Colors.black26)),
                    loadingIndicator: const SizedBox.shrink(), buttonMode: ButtonMode.MATERIAL,
                  ),
                  categoryViewConfig: const CategoryViewConfig(
                    initCategory: Category.RECENT, tabIndicatorAnimDuration: kTabScrollDuration, categoryIcons: CategoryIcons(),
                  ),
                  skinToneConfig: const SkinToneConfig(enabled: true, dialogBackgroundColor: Colors.white, indicatorColor: Colors.grey),
                  searchViewConfig: const SearchViewConfig(backgroundColor: Colors.white, buttonIconColor: Colors.grey),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: const Color(0xFF0A0A0F), buttonIconColor: const Color(0xFF8B5CF6),
                    buttonColor: const Color(0xFF8B5CF6), showBackspaceButton: true, showSearchViewButton: true,
                  ),
                ),
              ),
            ),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1a103c).withOpacity(0.8),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70),
                    onPressed: _canSend && !_isAnnouncementsOnly ? () => _showAttachmentMenu(context) : _showPermissionDenied,
                  ),
                  IconButton(
                    icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.white70),
                    onPressed: () {
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                      if (_showEmojiPicker) FocusScope.of(context).unfocus();
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _canSend && !_isAnnouncementsOnly ? 'Message' : 'Only admins can send messages',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendTextMessage(),
                        onTap: () { if (_showEmojiPicker) setState(() => _showEmojiPicker = false); },
                        enabled: _canSend && !_isAnnouncementsOnly,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _canSend && !_isAnnouncementsOnly && _messageController.text.trim().isNotEmpty
                        ? _sendTextMessage
                        : _showPermissionDenied,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: const Color(0xFF1a103c),
        child: Icon(_isGroup ? Icons.group : Icons.person, size: 20, color: const Color(0xFF8B5CF6)),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFF1a103c),
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _buildMessageAvatar(String? avatarUrl, String? username) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        ),
        child: Center(
          child: Text((username ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover, onError: (_, __) {}),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, {required Map<String, dynamic> message, required bool isMe, required bool showAvatar}) {
    final type = message['type'] ?? 'text';
    final content = message['content'] ?? '';
    final mediaUrl = message['media_url'];
    final createdAt = DateTime.parse(message['created_at']);
    final user = message['users'];
    final isEdited = message['is_edited'] == true;
    final senderId = message['sender_id'] as String?;
    final senderPhone = user?['phone_number'] as String?;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 4, left: isMe ? 64 : (showAvatar ? 8 : 40), right: isMe ? 8 : 64),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && showAvatar)
              GestureDetector(
                onTap: senderId != null
                  ? () => Navigator.pushNamed(context, '/public_profile', arguments: {
                      'userId': senderId, 'username': user?['username'], 'avatarUrl': user?['avatar_url'], 'bio': user?['bio'],
                    })
                  : null,
                child: _buildMessageAvatar(user?['avatar_url'], user?['username']),
              ),
            if (!isMe && !showAvatar) const SizedBox(width: 32),

            Flexible(
              child: Container(
                padding: type == 'text' ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10) : const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: isMe
                    ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: isMe ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomRight: isMe ? const Radius.circular(4) : null,
                    bottomLeft: !isMe ? const Radius.circular(4) : null,
                  ),
                  border: !isMe ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGroup && !isMe && showAvatar)
                      GestureDetector(
                        onTap: senderId != null
                          ? () => Navigator.pushNamed(context, '/public_profile', arguments: {
                              'userId': senderId, 'username': user?['username'], 'avatarUrl': user?['avatar_url'], 'bio': user?['bio'],
                            })
                          : null,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: VerifiedUsername(
                            username: user?['username'] ?? 'Unknown',
                            phoneNumber: senderPhone,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6).withOpacity(0.9)),
                            badgeSize: 12, spacing: 4,
                          ),
                        ),
                      ),

                    if (message['reply_to'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text('Replying to...', style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey)),
                      ),

                    if (type == 'text')
                      Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9), fontSize: 15))
                    else if (type == 'image' && mediaUrl != null)
                      GestureDetector(
                        onTap: () => _showImageViewer(mediaUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl, width: 200, height: 200, fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 200, height: 200, color: Colors.white.withOpacity(0.1),
                              child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)))),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 200, height: 200, color: Colors.white.withOpacity(0.1),
                              child: const Icon(Icons.error, color: Colors.white54),
                            ),
                          ),
                        ),
                      )
                    else if (type == 'audio' && mediaUrl != null)
                      _buildAudioPlayer(messageId: message['id'], audioUrl: mediaUrl, isMe: isMe)
                    else if (type == 'file')
                      _buildFileMessage(content: content, mediaUrl: mediaUrl, fileName: message['file_name'], fileSize: message['file_size'], isMe: isMe),

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('HH:mm').format(createdAt), style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4))),
                        if (isEdited) ...[
                          const SizedBox(width: 4),
                          Text('edited', style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3), fontStyle: FontStyle.italic)),
                        ],
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(message['is_read'] == true ? Icons.done_all : Icons.done, size: 14, color: message['is_read'] == true ? Colors.white : Colors.white.withOpacity(0.7)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer({required String messageId, required String audioUrl, required bool isMe}) {
    final isPlaying = _currentlyPlayingAudioId == messageId && _isPlayingAudio;
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: isMe ? Colors.white : const Color(0xFF8B5CF6), size: 28),
            onPressed: () => _playAudio(messageId, audioUrl),
          ),
          Expanded(
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.2) : const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Center(child: Text('Voice Message', style: TextStyle(fontSize: 12, color: isMe ? Colors.white : Colors.white.withOpacity(0.8)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileMessage({required String content, required String? mediaUrl, required String? fileName, required String? fileSize, required bool isMe}) {
    return GestureDetector(
      onTap: mediaUrl != null ? () => _openFile(mediaUrl, fileName) : null,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: !isMe ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : const Color(0xFF8B5CF6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName ?? content, style: TextStyle(fontWeight: FontWeight.w500, color: isMe ? Colors.white : Colors.white.withOpacity(0.9)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (fileSize != null)
                    Text(fileSize, style: TextStyle(fontSize: 12, color: isMe ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
            Icon(Icons.download, color: isMe ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4), size: 20),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentButton(icon: Icons.photo, label: 'Gallery', color: const Color(0xFF8B5CF6), onTap: () { Navigator.pop(context); _pickImage(); }),
                _buildAttachmentButton(icon: Icons.camera_alt, label: 'Camera', color: const Color(0xFF06B6D4), onTap: () { Navigator.pop(context); _takePhoto(); }),
                _buildAttachmentButton(icon: Icons.insert_drive_file, label: 'Document', color: Colors.blue, onTap: () { Navigator.pop(context); _pickFile(); }),
                _buildAttachmentButton(icon: Icons.location_on, label: 'Location', color: Colors.green, onTap: () { Navigator.pop(context); }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: color)),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
