import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _editController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final Record _audioRecorder = Record();

  bool _showEmojiPicker = false;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messageSubscription;
  StreamSubscription? _blockSubscription;
  StreamSubscription? _otherUserSubscription;
  StreamSubscription? _typingSubscription;
  bool _isLoading = true;
  String? _replyingTo;
  String? _replyingToContent;
  String? _replyingToSender;
  String? _editingMessageId;

  // Voice note recording
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  String? _recordingPath;
  int _recordingSeconds = 0;

  // Video players cache
  final Map<String, VideoPlayerController> _videoControllers = {};

  // Search
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  int _currentSearchIndex = -1;

  // Pinned messages
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _showPinned = false;

  // Selection mode
  List<String> _selectedMessages = [];
  bool _isSelectionMode = false;

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
  bool _isBlocked = false;
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;
  String? _otherUserId;
  bool _otherUserTyping = false;
  String? _otherUserStatus;
  Timer? _typingTimer;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _audioDuration = d);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _audioPosition = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlayingAudio = state.playing);
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            _currentlyPlayingAudioId = null;
            _audioPosition = Duration.zero;
          });
        }
      }
    });
  }

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
      _loadPinnedMessages();
      if (!_isGroup) {
        _checkBlockStatus();
        _subscribeToBlockStatus();
        _subscribeToOtherUserStatus();
        _subscribeToTyping();
      }
      _setOnlineStatus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _setOfflineStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _editController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _messageSubscription?.cancel();
    _blockSubscription?.cancel();
    _otherUserSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _statusTimer?.cancel();
    _recordingTimer?.cancel();
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _stopTyping();
    _setOfflineStatus();
    super.dispose();
  }

  /// Set user as online
  Future<void> _setOnlineStatus() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': 'Online',
      'last_seen': FieldValue.serverTimestamp(),
      'is_online': true,
    });

    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'last_seen': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Set user as offline
  Future<void> _setOfflineStatus() async {
    _statusTimer?.cancel();
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': 'Last seen ${_formatLastSeen(DateTime.now())}',
      'is_online': false,
      'last_seen': FieldValue.serverTimestamp(),
    });
  }

  String _formatLastSeen(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, HH:mm').format(time);
  }

  /// Check initial block status
  Future<void> _checkBlockStatus() async {
    if (_isGroup || _chatId == null) return;

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (currentUserId == null) return;

      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .get();

      if (!chatDoc.exists) return;

      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      _otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');

      if (_otherUserId == null || _otherUserId!.isEmpty) return;

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final otherUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .get();

      final myBlocked = List<String>.from(currentUserDoc.data()?['blocked_users'] ?? []);
      final theirBlocked = List<String>.from(otherUserDoc.data()?['blocked_users'] ?? []);

      if (mounted) {
        setState(() {
          _iBlockedThem = myBlocked.contains(_otherUserId);
          _theyBlockedMe = theirBlocked.contains(currentUserId);
          _isBlocked = _iBlockedThem || _theyBlockedMe;
        });
      }
    } catch (e) {
      debugPrint('Block check error: $e');
    }
  }

  /// Real-time block status listener
  void _subscribeToBlockStatus() {
    if (_isGroup || _chatId == null) return;

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null || _otherUserId == null) return;

    final myUserStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots();

    _blockSubscription = myUserStream.listen((myDoc) async {
      if (!mounted) return;
      final myBlocked = List<String>.from(myDoc.data()?['blocked_users'] ?? []);

      final theirDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_otherUserId)
          .get();
      final theirBlocked = List<String>.from(theirDoc.data()?['blocked_users'] ?? []);

      setState(() {
        _iBlockedThem = myBlocked.contains(_otherUserId);
        _theyBlockedMe = theirBlocked.contains(currentUserId);
        _isBlocked = _iBlockedThem || _theyBlockedMe;
      });
    });
  }

  /// Listen to other user's status (online/typing) — HIDDEN if blocked
  void _subscribeToOtherUserStatus() {
    if (_isGroup || _otherUserId == null) return;

    _otherUserSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_otherUserId)
        .snapshots()
        .listen((doc) {
      if (!mounted || !doc.exists) return;

      if (_iBlockedThem || _theyBlockedMe) {
        setState(() {
          _otherUserStatus = null;
          _otherUserTyping = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final isOnline = data['is_online'] as bool? ?? false;
      final lastSeen = data['last_seen'] as Timestamp?;

      setState(() {
        if (isOnline) {
          _otherUserStatus = 'Online';
        } else if (lastSeen != null) {
          _otherUserStatus = 'Last seen ${_formatLastSeen(lastSeen.toDate())}';
        } else {
          _otherUserStatus = null;
        }
      });
    });
  }

  /// Listen to typing indicators — HIDDEN if blocked
  void _subscribeToTyping() {
    if (_isGroup || _chatId == null || _otherUserId == null) return;

    _typingSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('typing')
        .doc(_otherUserId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;

      if (_iBlockedThem || _theyBlockedMe) {
        setState(() => _otherUserTyping = false);
        return;
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final typedAt = timestamp.toDate();
          final now = DateTime.now();
          setState(() {
            _otherUserTyping = now.difference(typedAt).inSeconds < 5;
          });
        }
      } else {
        setState(() => _otherUserTyping = false);
      }
    });
  }

  /// Send typing indicator
  void _startTyping() {
    if (_isGroup || _chatId == null || _isBlocked) return;

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);

    FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('typing')
        .doc(currentUserId)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Remove typing indicator
  void _stopTyping() {
    if (_isGroup || _chatId == null) return;

    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('typing')
        .doc(currentUserId)
        .delete();
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
          .where('deleted_for_everyone', isEqualTo: false)
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
        .where('deleted_for_everyone', isEqualTo: false)
        .orderBy('created_at', descending: true)  // FIX: descending to get newest first
        .limit(100)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;
          
          final List<Map<String, dynamic>> newMessages = [];
          
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final messageId = doc.id;
            final senderId = data['sender_id'] as String?;
            
            // Skip if deleted for me
            final deletedFor = List<String>.from(data['deleted_for'] ?? []);
            final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
            final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
            if (deletedFor.contains(currentUserId)) continue;

            // Get sender info
            Map<String, dynamic>? userData;
            if (senderId != null) {
              final userDoc = await firestore.collection('users').doc(senderId).get();
              if (userDoc.exists) {
                final u = userDoc.data()!;
                userData = {
                  'username': u['username'],
                  'avatar_url': u['avatar_url'],
                  'bio': u['bio'],
                  'phone_number': u['phone'],
                };
              }
            }

            newMessages.add({
              'id': messageId,
              ...data,
              'users': userData ?? {
                'username': 'Unknown',
                'avatar_url': null,
                'bio': null,
                'phone_number': null,
              },
              'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
            });
          }

          // Reverse to show oldest at bottom (like chat apps)
          newMessages.sort((a, b) => 
            DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']))
          );

          setState(() {
            _messages = newMessages;
            _isLoading = false;
          });
          
          _scrollToBottom();
        }, onError: (e) {
          debugPrint('Message subscription error: $e');
          setState(() => _isLoading = false);
        });
  }

  Future<void> _loadPinnedMessages() async {
    if (_chatId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('pinned_messages')
          .orderBy('pinned_at', descending: true)
          .limit(3)
          .get();

      final pinned = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'message_id': data['message_id'],
        };
      }).toList();

      setState(() => _pinnedMessages = pinned);
    } catch (e) {
      debugPrint('Load pinned error: $e');
    }
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

  void _scrollToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m['id'] == messageId);
    if (index >= 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        index * 80.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _sendTextMessage() async {
    if (!_canSend || _isAnnouncementsOnly) {
      _showPermissionDenied();
      return;
    }

    if (!_isGroup && _isBlocked) {
      _showBlockedWarning();
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() => _showEmojiPicker = false);
    _stopTyping();

    await _sendMessage(type: 'text', content: text);
  }

  Future<void> _sendMessage({
    required String type,
    required String content,
    String? mediaUrl,
    String? fileName,
    String? fileSize,
    int? duration,
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
        'duration': duration,
        'reply_to': _replyingTo,
        'reply_to_content': _replyingToContent,
        'reply_to_sender': _replyingToSender,
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false,
        'is_edited': false,
        'deleted_for_everyone': false,
        'deleted_for': [],
        'reactions': {},
        'sent_to_fcm': false,
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

      setState(() {
        _replyingTo = null;
        _replyingToContent = null;
        _replyingToSender = null;
      });
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

  void _showBlockedWarning() {
    String message;
    if (_iBlockedThem) {
      message = 'You blocked this user. Unblock them to send messages.';
    } else if (_theyBlockedMe) {
      message = 'This user blocked you. You cannot send messages.';
    } else {
      message = 'You cannot message this user.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
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

  Future<void> _toggleReaction(String messageId, String emoji) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;

      final messageRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId);

      final doc = await messageRef.get();
      if (!doc.exists) return;

      final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
      final users = List<String>.from(reactions[emoji] ?? []);

      if (users.contains(userId)) {
        users.remove(userId);
        if (users.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = users;
        }
      } else {
        users.add(userId);
        reactions[emoji] = users;
      }

      await messageRef.update({'reactions': reactions});
    } catch (e) {
      debugPrint('Reaction error: $e');
    }
  }

    void _showReactionPicker(String messageId) {
    final allReactions = [
      '❤️', '👍', '👎', '😂', '😮', '😢', '🎉', '🔥',
      '👏', '🙏', '💯', '⭐', '🤔', '🤬', '🤡', '💀',
      '🫡', '🥳', '😍', '🤯', '🫠', '🤮', '🤧', '🥱',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a103c),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              'Reactions',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Emoji grid - 8 per row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: allReactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleReaction(messageId, emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

    void _forwardMessage(Map<String, dynamic> message) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    // Get all chats this user is in
    final chatsSnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('last_message_at', descending: true)
        .get();

    if (!mounted) return;

    // Show chat picker bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.forward, color: Color(0xFF8B5CF6), size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Forward to...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              // Chat list
              Expanded(
                child: chatsSnapshot.docs.isEmpty
                  ? Center(
                      child: Text(
                        'No chats found',
                        style: TextStyle(color: Colors.white.withOpacity(0.3)),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: chatsSnapshot.docs.length,
                      itemBuilder: (context, index) {
                        final chatDoc = chatsSnapshot.docs[index];
                        final chatData = chatDoc.data();
                        final chatId = chatDoc.id;
                        
                        // Skip current chat
                        if (chatId == _chatId) return const SizedBox.shrink();

                        final isGroup = chatData['is_group'] == true || chatData['type'] == 'group';
                        final isChannel = chatData['type'] == 'channel';
                        final chatName = chatData['name'] ?? chatData['title'] ?? 'Unknown';
                        final chatAvatar = chatData['avatar_url'] as String?;
                        
                        // Get other participant for DM
                        String? otherUserName;
                        String? otherUserAvatar;
                        if (!isGroup && !isChannel) {
                          final participants = List<String>.from(chatData['participants'] ?? []);
                          final otherId = participants.firstWhere(
                            (id) => id != currentUserId,
                            orElse: () => '',
                          );
                          if (otherId.isNotEmpty) {
                            // Try to get from participants_data
                            final pData = chatData['participants_data']?[otherId];
                            if (pData != null) {
                              otherUserName = pData['username'] ?? pData['name'];
                              otherUserAvatar = pData['avatar_url'];
                            }
                          }
                        }

                        final displayName = isGroup || isChannel ? chatName : (otherUserName ?? chatName);
                        final displayAvatar = isGroup || isChannel ? chatAvatar : otherUserAvatar;

                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: displayAvatar == null
                                ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)])
                                : null,
                              image: displayAvatar != null
                                ? DecorationImage(image: NetworkImage(displayAvatar), fit: BoxFit.cover)
                                : null,
                            ),
                            child: displayAvatar == null
                              ? Icon(
                                  isGroup ? Icons.group : isChannel ? Icons.campaign : Icons.person,
                                  color: Colors.white70,
                                  size: 20,
                                )
                              : null,
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isGroup ? 'Group' : isChannel ? 'Channel' : 'Direct Message',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Send',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await _sendForwardedMessage(message, chatId);
                          },
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendForwardedMessage(Map<String, dynamic> originalMessage, String targetChatId) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (currentUserId == null) return;

      final messageType = originalMessage['type'] ?? 'text';
      final originalContent = originalMessage['content'] ?? '';
      final originalMediaUrl = originalMessage['media_url'] as String?;
      final originalFileName = originalMessage['file_name'] as String?;
      final originalFileSize = originalMessage['file_size'] as String?;
      final originalDuration = originalMessage['duration'] as int?;

      // Build forward content
      String forwardContent;
      if (messageType == 'text') {
        forwardContent = originalContent;
      } else if (messageType == 'image') {
        forwardContent = '📷 Photo';
      } else if (messageType == 'video') {
        forwardContent = '🎥 Video';
      } else if (messageType == 'audio') {
        forwardContent = '🎤 Voice Message';
      } else {
        forwardContent = '📎 ${originalFileName ?? 'File'}';
      }

      final newMessage = {
        'chat_id': targetChatId,
        'sender_id': currentUserId,
        'type': messageType,
        'content': forwardContent,
        'media_url': originalMediaUrl,
        'file_name': originalFileName,
        'file_size': originalFileSize,
        'duration': originalDuration,
        'forwarded_from': _chatId,
        'forwarded_by': currentUserId,
        'forwarded_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false,
        'deleted_for_everyone': false,
        'deleted_for': [],
        'reactions': {},
        'is_edited': false,
      };

      await FirebaseFirestore.instance
        .collection('chats')
        .doc(targetChatId)
        .collection('messages')
        .add(newMessage);

      // Update last message in chat
      await FirebaseFirestore.instance.collection('chats').doc(targetChatId).update({
        'last_message': forwardContent,
        'last_message_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message forwarded'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Forward error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forward failed: $e')),
        );
      }
    }
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _pinMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('pinned_messages')
          .doc(messageId)
          .set({
        'message_id': messageId,
        'pinned_at': FieldValue.serverTimestamp(),
        'pinned_by': Provider.of<AuraAuthProvider>(context, listen: false).user?.uid,
      });
      _loadPinnedMessages();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message pinned')),
        );
      }
    } catch (e) {
      debugPrint('Pin error: $e');
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('pinned_messages')
          .doc(messageId)
          .delete();
      _loadPinnedMessages();
    } catch (e) {
      debugPrint('Unpin error: $e');
    }
  }

  void _searchMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = -1;
      });
      return;
    }

    final results = _messages.where((m) {
      final content = m['content']?.toString().toLowerCase() ?? '';
      return content.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
    });

    if (results.isNotEmpty) {
      _scrollToMessage(results[0]['id']);
    }
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]['id']);
  }

  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]['id']);
  }

     Future<void> _deleteMessageForEveryone(String messageId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // ── GET MESSAGE DATA TO CHECK FOR MEDIA ──
      final messageDoc = await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId)
          .get();
      
      final messageData = messageDoc.data();
      final mediaUrl = messageData?['media_url'] as String?;
      final messageType = messageData?['type'] as String?;

      // ── DELETE MEDIA FROM CLOUDINARY IF EXISTS ──
      if (mediaUrl != null && mediaUrl.isNotEmpty && 
          (messageType == 'image' || messageType == 'video' || messageType == 'audio' || messageType == 'file')) {
        await CloudinaryService.deleteFile(mediaUrl);
      }
      // ── END CLOUDINARY DELETE ──

      // ── MARK MESSAGE AS DELETED ──
      await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId)
          .update({
        'deleted_for_everyone': true,
        'content': 'This message was deleted',
        'media_url': null,
        'file_name': null,
        'file_size': null,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted for everyone')),
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

  Future<void> _deleteMessageForMe(String messageId) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (currentUserId == null) return;

      final firestore = FirebaseFirestore.instance;
      await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .doc(messageId)
          .update({
        'deleted_for': FieldValue.arrayUnion([currentUserId]),
      });

      setState(() {
        _messages.removeWhere((m) => m['id'] == messageId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted for you')),
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
    final isDeleted = message['deleted_for_everyone'] == true;
    final isText = message['type'] == 'text';
    final canEdit = isMe && isText && !isDeleted;
    final type = message['type'] ?? 'text';
    final mediaUrl = message['media_url'] as String?;
    final senderId = message['sender_id'] as String?;
    final user = message['users'];

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
            
            // Quick reactions row at top
            if (!isDeleted) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['❤️', '👍', '😂', '😮', '🎉', '🔥'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _toggleReaction(message['id'], emoji);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white10),
            ],
            
            if (canEdit) ...[
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
            ],
            
            if (!isDeleted && isText) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.copy, color: Color(0xFF06B6D4)),
                ),
                title: const Text('Copy', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessage(message['content'] ?? '');
                },
              ),
            ],
            
            if (!isDeleted) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.forward, color: Color(0xFF10B981)),
                ),
                title: const Text('Forward', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessage(message);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.push_pin, color: Colors.orange),
                ),
                title: const Text('Pin', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pinMessage(message['id']);
                },
              ),
            ],
            
            if (!isDeleted && mediaUrl != null && (type == 'image' || type == 'video' || type == 'audio')) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.download, color: Color(0xFF06B6D4)),
                ),
                title: const Text('Download', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _downloadMedia(mediaUrl, message['file_name'] ?? 'download');
                },
              ),
            ],
            
            if (isMe) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_forever, color: Colors.red),
                ),
                title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteForEveryone(message['id']);
                },
              ),
            ],
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text('Delete for Me', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(message['id']);
              },
            ),
            
            if (!isDeleted) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.reply, color: Color(0xFF06B6D4)),
                ),
                title: const Text('Reply', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingTo = message['id'];
                    _replyingToContent = message['content'] ?? message['file_name'] ?? 'Media';
                    _replyingToSender = message['users']?['username'] ?? 'Unknown';
                  });
                },
              ),
            ],
            
            // Report - always available
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
            
            if (!isDeleted && !isMe) ...[
              const Divider(color: Colors.white10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Color(0xFF10B981)),
                ),
                title: const Text('View Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  if (senderId != null) {
                    Navigator.pushNamed(context, '/public_profile', arguments: {
                      'userId': senderId,
                      'username': user?['username'] ?? 'Unknown',
                      'avatar_url': user?['avatar_url'],
                      'bio': user?['bio'],
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForEveryone(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete for Everyone?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete the message for all participants. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessageForEveryone(messageId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
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

  // ==================== MEDIA PICKING & UPLOAD ====================

  Future<void> _pickImage() async {
    if (!_canSendFiles) { _showPermissionDenied(); return; }
    if (!_isGroup && _isBlocked) { _showBlockedWarning(); return; }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      await _uploadAndSendMedia(file: File(pickedFile.path), type: 'image');
    }
  }

  Future<void> _takePhoto() async {
    if (!_canSendFiles) { _showPermissionDenied(); return; }
    if (!_isGroup && _isBlocked) { _showBlockedWarning(); return; }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (pickedFile != null) {
      await _uploadAndSendMedia(file: File(pickedFile.path), type: 'image');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (!_canSendFiles) { _showPermissionDenied(); return; }
    if (!_isGroup && _isBlocked) { _showBlockedWarning(); return; }
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final size = await file.length();
      await _uploadAndSendMedia(
        file: file,
        type: 'video',
        fileName: pickedFile.name,
        fileSize: _formatFileSize(size.toInt()),
      );
    }
  }

  Future<void> _recordVideo() async {
    if (!_canSendFiles) { _showPermissionDenied(); return; }
    if (!_isGroup && _isBlocked) { _showBlockedWarning(); return; }
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final size = await file.length();
      await _uploadAndSendMedia(
        file: file,
        type: 'video',
        fileName: pickedFile.name,
        fileSize: _formatFileSize(size.toInt()),
      );
    }
  }

  Future<void> _pickFile() async {
    if (!_canSendFiles) { _showPermissionDenied(); return; }
    if (!_isGroup && _isBlocked) { _showBlockedWarning(); return; }
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
    int? duration,
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
          duration: Duration(seconds: 60),
        ),
      );

      String? mediaUrl;
      
      // FIX: Use appropriate upload method for each file type
      if (type == 'image') {
        mediaUrl = await CloudinaryService.uploadImage(file, 'aurachat/chats/$_chatId');
      } else if (type == 'video') {
        mediaUrl = await CloudinaryService.uploadVideo(file, 'aurachat/chats/$_chatId');
      } else if (type == 'audio') {
        mediaUrl = await CloudinaryService.uploadAudio(file, 'aurachat/chats/$_chatId');
      } else {
        // file/document
        mediaUrl = await CloudinaryService.uploadFile(file, 'aurachat/chats/$_chatId');
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (mediaUrl == null) throw Exception('Upload failed - no URL returned');

      await _sendMessage(
        type: type,
        content: fileName ?? (type == 'image' ? 'Image' : type == 'video' ? 'Video' : type == 'audio' ? 'Voice Message' : 'File'),
        mediaUrl: mediaUrl,
        fileName: fileName,
        fileSize: fileSize,
        duration: duration,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  // ==================== VOICE NOTE RECORDING ====================

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingStartTime = DateTime.now();
        _recordingSeconds = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      await _audioRecorder.dispose();
      setState(() => _isRecording = false);

      if (path != null) {
        final file = File(path);
        final size = await file.length();
        await _uploadAndSendMedia(
          file: file,
          type: 'audio',
          fileName: 'Voice Message',
          fileSize: _formatFileSize(size.toInt()),
          duration: _recordingSeconds,
        );
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      await _audioRecorder.dispose();
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) await file.delete();
      }
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingSeconds = 0;
      });
    } catch (e) {
      debugPrint('Cancel recording error: $e');
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ==================== AUDIO PLAYBACK ====================

  Future<void> _playAudio(String messageId, String audioUrl) async {
    try {
      if (_currentlyPlayingAudioId == messageId) {
        if (_isPlayingAudio) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.play();
        }
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
        setState(() {
          _currentlyPlayingAudioId = messageId;
          _audioPosition = Duration.zero;
        });
      }
    } catch (e) {
      debugPrint('Play audio error: $e');
    }
  }

  // ==================== FILE & DOWNLOAD ====================

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

    Future<void> _downloadMedia(String url, String fileName) async {
    try {
      // FIX: Request photos permission for images/videos
      final isImage = fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.png');
      final isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mov');
      
      PermissionStatus status;
      if (isImage || isVideo) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
      
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied. Enable in settings.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download failed');

      // FIX: Save to public Downloads directory
      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download/AURA');
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }
      
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final filePath = '${saveDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads/AURA/$fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  // ==================== IMAGE VIEWER ====================

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
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () {
                    _downloadMedia(imageUrl, 'image_${DateTime.now().millisecondsSinceEpoch}.jpg');
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== VIDEO PLAYER ====================

  VideoPlayerController _getVideoController(String url) {
    if (!_videoControllers.containsKey(url)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      });
      _videoControllers[url] = controller;
    }
    return _videoControllers[url]!;
  }

  // ==================== DATE HELPERS ====================

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final currentDate = DateTime.parse(_messages[index]['created_at']);
    final prevDate = DateTime.parse(_messages[index - 1]['created_at']);
    return !_isSameDay(currentDate, prevDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, yesterday)) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
    final isAdmin = _myRole == 'owner' || _myRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _isSearching
          ? _buildSearchAppBar()
          : AppBar(
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
                  : !_isGroup && _otherUserId != null && !_isBlocked
                    ? () => Navigator.pushNamed(context, '/public_profile', arguments: {
                        'userId': _otherUserId,
                        'username': _chatName,
                        'avatar_url': _chatAvatar,
                      })
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
                          if (!_isGroup) ...[
                            if (_isBlocked)
                              Text(
                                _iBlockedThem ? 'You blocked this user' : 'Blocked',
                                style: TextStyle(fontSize: 12, color: Colors.red.withOpacity(0.8)),
                              )
                            else if (_otherUserTyping)
                              const Text(
                                'typing...',
                                style: TextStyle(fontSize: 12, color: Color(0xFF06B6D4), fontStyle: FontStyle.italic),
                              )
                            else if (_otherUserStatus != null)
                              Text(
                                _otherUserStatus!,
                                style: TextStyle(fontSize: 12, color: const Color(0xFF06B6D4).withOpacity(0.8)),
                              )
                            else
                              Text(
                                'Online',
                                style: TextStyle(fontSize: 12, color: const Color(0xFF06B6D4).withOpacity(0.8)),
                              ),
                          ] else ...[
                            Text(
                              '$_myRole \u2022 Tap for info',
                              style: TextStyle(fontSize: 12, color: const Color(0xFF06B6D4).withOpacity(0.8)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white70),
                  onPressed: () => setState(() => _isSearching = true),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.white70), 
                  onPressed: (_isBlocked && !_isGroup) ? _showBlockedWarning : () {}
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.white70), 
                  onPressed: (_isBlocked && !_isGroup) ? _showBlockedWarning : () {}
                ),
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
          // Pinned messages banner
          if (_pinnedMessages.isNotEmpty && _showPinned)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF1a103c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Pinned Messages',
                        style: TextStyle(
                          color: Colors.orange.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showPinned = false),
                        child: const Icon(Icons.close, size: 16, color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._pinnedMessages.map((pinned) {
                    final message = _messages.firstWhere(
                      (m) => m['id'] == pinned['message_id'],
                      orElse: () => {'content': 'Message not found'},
                    );
                    return GestureDetector(
                      onTap: () => _scrollToMessage(pinned['message_id']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Text(
                          message['content']?.toString() ?? 'Media',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

          if (!_isGroup && _isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.red.withOpacity(0.15),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _iBlockedThem
                        ? 'You blocked this user. Unblock them from their profile to chat.'
                        : 'This user blocked you. You cannot send messages.',
                      style: TextStyle(color: Colors.red.withOpacity(0.9), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

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

          if (!_isGroup && !_isBlocked && _otherUserTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, top: 8),
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildDot(0),
                          _buildDot(1),
                          _buildDot(2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'typing',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
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
                      final isDeleted = message['deleted_for_everyone'] == true;
                      final showDate = _shouldShowDateSeparator(index);

                      return Column(
                        children: [
                          if (showDate)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDateSeparator(DateTime.parse(message['created_at'])),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          GestureDetector(
                            onDoubleTap: () => _showReactionPicker(message['id']),
                            onLongPress: () => _showMessageOptions(message, isMe),
                            child: _buildMessageBubble(
                              context, 
                              message: message, 
                              isMe: isMe, 
                              showAvatar: showAvatar,
                              isDeleted: isDeleted,
                            ),
                          ),
                        ],
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
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyingToSender ?? 'Unknown',
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _replyingToContent ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                    onPressed: () => setState(() {
                      _replyingTo = null;
                      _replyingToContent = null;
                      _replyingToSender = null;
                    }),
                  ),
                ],
              ),
            ),

          // Recording indicator
          if (_isRecording)
            _buildRecordingIndicator(),

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
                    onPressed: (_canSend && !_isAnnouncementsOnly && !(_isBlocked && !_isGroup))
                      ? () => _showAttachmentMenu(context) 
                      : null,
                  ),
                  IconButton(
                    icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.white70),
                    onPressed: (_canSend && !_isAnnouncementsOnly && !(_isBlocked && !_isGroup))
                      ? () {
                          setState(() => _showEmojiPicker = !_showEmojiPicker);
                          if (_showEmojiPicker) FocusScope.of(context).unfocus();
                        }
                      : null,
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
                          hintText: _isBlocked && !_isGroup
                            ? 'You cannot message this user'
                            : !_canSend || _isAnnouncementsOnly
                              ? 'Only admins can send messages'
                              : 'Message',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onChanged: (_) => _startTyping(),
                        onSubmitted: (_) => _sendTextMessage(),
                        onTap: () { if (_showEmojiPicker) setState(() => _showEmojiPicker = false); },
                        enabled: _canSend && !_isAnnouncementsOnly && !(_isBlocked && !_isGroup),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic or Send button
                  if (_messageController.text.trim().isEmpty && !_isRecording)
                    GestureDetector(
                      onLongPressStart: (_) => _startRecording(),
                      onLongPressEnd: (_) => _stopRecordingAndSend(),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: (_isBlocked && !_isGroup) || !_canSend || _isAnnouncementsOnly
                              ? [Colors.grey, Colors.grey]
                              : [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.mic, color: Colors.white, size: 20),
                          onPressed: null,
                        ),
                      ),
                    )
                  else if (!_isRecording)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: (_isBlocked && !_isGroup) || !_canSend || _isAnnouncementsOnly || _messageController.text.trim().isEmpty
                            ? [Colors.grey, Colors.grey]
                            : [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                        onPressed: (_canSend && !_isAnnouncementsOnly && _messageController.text.trim().isNotEmpty && !(_isBlocked && !_isGroup))
                          ? _sendTextMessage
                          : null,
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

  /// Search AppBar
  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white70),
        onPressed: () => setState(() {
          _isSearching = false;
          _searchResults = [];
          _currentSearchIndex = -1;
          _searchController.clear();
        }),
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
        ),
        onChanged: _searchMessages,
      ),
      actions: [
        if (_searchResults.isNotEmpty) ...[
          Text(
            '${_currentSearchIndex + 1}/${_searchResults.length}',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
            onPressed: _previousSearchResult,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
            onPressed: _nextSearchResult,
          ),
        ],
      ],
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6),
        borderRadius: BorderRadius.circular(3),
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
      backgroundImage: CachedNetworkImageProvider(avatarUrl),
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
    return CachedNetworkImage(
      imageUrl: avatarUrl,
      imageBuilder: (context, imageProvider) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      ),
      placeholder: (context, url) => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        ),
        child: const Center(
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
        ),
        child: Center(
          child: Text((username ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

    Widget _buildMessageBubble(BuildContext context, {
    required Map<String, dynamic> message, 
    required bool isMe, 
    required bool showAvatar,
    required bool isDeleted,
  }) {
    final type = message['type'] ?? 'text';
    final content = message['content'] ?? '';
    final mediaUrl = message['media_url'];
    final createdAt = DateTime.parse(message['created_at']);
    final user = message['users'];
    final isEdited = message['is_edited'] == true;
    final senderId = message['sender_id'] as String?;
    final senderPhone = user?['phone_number'] as String?;
    final reactions = Map<String, dynamic>.from(message['reactions'] ?? {});

    // FIX: More space between messages
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: reactions.isNotEmpty ? 16 : 8,  // FIX: Extra space for reactions
          left: isMe ? 64 : (showAvatar ? 8 : 40), 
          right: isMe ? 8 : 64,
          top: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe && showAvatar)
              GestureDetector(
                onTap: senderId != null
                  ? () => Navigator.pushNamed(context, '/public_profile', arguments: {
                      'userId': senderId, 
                      'username': user?['username'], 
                      'avatar_url': user?['avatar_url'], 
                      'bio': user?['bio'],
                    })
                  : null,
                child: _buildMessageAvatar(user?['avatar_url'], user?['username']),
              ),
            if (!isMe && !showAvatar) const SizedBox(width: 32),

            Flexible(
              child: GestureDetector(
                // FIX: Double-tap shows quick reaction bar instead of full picker
                onDoubleTap: () => _showReactionPicker(message['id']),
                onLongPress: () => _showMessageOptions(message, isMe),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
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
                          // FIX: Show sender name for ALL non-me messages in groups (not just when avatar shows)
                          if (_isGroup && !isMe)
                            GestureDetector(
                              onTap: senderId != null
                                ? () => Navigator.pushNamed(context, '/public_profile', arguments: {
                                    'userId': senderId, 
                                    'username': user?['username'], 
                                    'avatar_url': user?['avatar_url'], 
                                    'bio': user?['bio'],
                                  })
                                : null,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: VerifiedUsername(
                                  username: user?['username'] ?? 'Unknown',
                                  phoneNumber: senderPhone,
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.w600, 
                                    color: const Color(0xFF8B5CF6).withOpacity(0.9),
                                  ),
                                  badgeSize: 12, 
                                  spacing: 4,
                                ),
                              ),
                            ),

                          if (message['reply_to'] != null)
                            GestureDetector(
                              onTap: () => _scrollToMessage(message['reply_to']),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(color: const Color(0xFF8B5CF6), width: 3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['reply_to_sender'] ?? 'Unknown',
                                      style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message['reply_to_content'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (isDeleted)
                            Text(
                              'This message was deleted',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontStyle: FontStyle.italic),
                            )
                          else if (type == 'text')
                            Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9), fontSize: 15))
                          else if (type == 'image' && mediaUrl != null)
                            GestureDetector(
                              onTap: () => _showImageViewer(mediaUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: mediaUrl, 
                                  width: 200, 
                                  height: 200, 
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 200, 
                                    height: 200, 
                                    color: Colors.white.withOpacity(0.1),
                                    child: const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)))),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 200, 
                                    height: 200, 
                                    color: Colors.white.withOpacity(0.1),
                                    child: const Icon(Icons.error, color: Colors.white54),
                                  ),
                                ),
                              ),
                            )
                          else if (type == 'audio' && mediaUrl != null)
                            _buildVoiceNoteBubble(
                              messageId: message['id'],
                              audioUrl: mediaUrl,
                              duration: message['duration'] as int?,
                              isMe: isMe,
                            )
                          else if (type == 'video' && mediaUrl != null)
                            _buildVideoBubble(videoUrl: mediaUrl, isMe: isMe)
                          else if (type == 'file')
                            _buildFileMessage(
                              content: content, 
                              mediaUrl: mediaUrl, 
                              fileName: message['file_name'], 
                              fileSize: message['file_size'], 
                              isMe: isMe,
                            )
                          else if (type == 'link_preview' && mediaUrl != null)
                            _buildLinkPreviewBubble(
                              link: content,
                              previewData: message['preview_data'] ?? {},
                              isMe: isMe,
                            ),

                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(createdAt), 
                                style: TextStyle(
                                  fontSize: 10, 
                                  color: isMe ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4),
                                ),
                              ),
                              if (isEdited && !isDeleted) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'edited', 
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: isMe ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3), 
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (isMe && !isDeleted) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  message['is_read'] == true ? Icons.done_all : Icons.done, 
                                  size: 14, 
                                  color: message['is_read'] == true ? Colors.white : Colors.white.withOpacity(0.7),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // FIX: Reaction bar with count + "more" button
                    if (reactions.isNotEmpty)
                      Positioned(
                        bottom: -12,
                        right: isMe ? null : 0,
                        left: isMe ? 0 : null,
                        child: GestureDetector(
                          onTap: () => _showReactionPicker(message['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a103c),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Show max 5 reactions, then "more" button
                                ...reactions.entries.take(5).map((entry) {
                                  final emoji = entry.key;
                                  final count = (entry.value as List).length;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: Text('$emoji${count > 1 ? count : ''}', style: const TextStyle(fontSize: 12)),
                                  );
                                }),
                                if (reactions.length > 5)
                                  Container(
                                    margin: const EdgeInsets.only(left: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '+${reactions.length - 5}',
                                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildVoiceNoteBubble({required String messageId, required String audioUrl, int? duration, required bool isMe}) {
    final isCurrent = _currentlyPlayingAudioId == messageId;
    final position = isCurrent ? _audioPosition : Duration.zero;
    final totalDuration = isCurrent && _audioDuration != Duration.zero
        ? _audioDuration
        : Duration(seconds: duration ?? 0);
    final progress = totalDuration.inMilliseconds > 0
        ? position.inMilliseconds / totalDuration.inMilliseconds
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playAudio(messageId, audioUrl),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.25) : const Color(0xFF8B5CF6).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCurrent && _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                color: isMe ? Colors.white : const Color(0xFF8B5CF6),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 28,
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: isMe ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: isMe ? Colors.white : const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCurrent ? '${fmt(position)} / ${fmt(totalDuration)}' : fmt(totalDuration),
                  style: TextStyle(fontSize: 11, color: isMe ? Colors.white.withOpacity(0.8) : Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBubble({required String videoUrl, required bool isMe}) {
    if (!_videoControllers.containsKey(videoUrl)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      controller.initialize().then((_) { if (mounted) setState(() {}); });
      _videoControllers[videoUrl] = controller;
    }
    final controller = _videoControllers[videoUrl]!;
    final isInitialized = controller.value.isInitialized;

    return GestureDetector(
      onTap: () {
        if (isInitialized) {
          setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 240,
          height: 180,
          color: Colors.black,
          child: isInitialized
            ? Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(controller),
                  if (!controller.value.isPlaying)
                    Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                    ),
                ],
              )
            : const Center(
                child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)))),
              ),
        ),
      ),
    );
  }
  
  Widget _buildLinkPreviewBubble({
  required String link,
  required Map<String, dynamic> previewData,
  required bool isMe,
}) {
  final title = previewData['title'] ?? 'Join Group';
  final description = previewData['description'] ?? '';
  final imageUrl = previewData['image_url'] as String?;
  final memberCount = previewData['member_count'] ?? 0;
  final chatType = previewData['type'] ?? 'group';

  return GestureDetector(
    onTap: () {
      // Handle link tap
      final uri = Uri.parse(link);
      final code = uri.pathSegments.last;
      Navigator.pushNamed(context, '/invitation', arguments: {
        'code': code,
      });
    },
    child: Container(
      width: 260,
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group image
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: 260,
                height: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 260,
                  height: 140,
                  color: Colors.white.withOpacity(0.05),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 260,
                  height: 140,
                  color: const Color(0xFF1a103c),
                  child: Icon(
                    chatType == 'channel' ? Icons.campaign : Icons.group,
                    size: 50,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF1a103c),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Icon(
                chatType == 'channel' ? Icons.campaign : Icons.group,
                size: 50,
                color: const Color(0xFF8B5CF6),
              ),
            ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chatType.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$memberCount members',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Join Group',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildRecordingIndicator() {
    String fmt(int s) {
      final m = (s ~/ 60).toString().padLeft(2, '0');
      final sec = (s % 60).toString().padLeft(2, '0');
      return '$m:$sec';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Text(
              'Recording ${fmt(_recordingSeconds)}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _stopRecordingAndSend,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Send', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
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
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildAttachmentButton(icon: Icons.photo, label: 'Gallery', color: const Color(0xFF8B5CF6), onTap: () { Navigator.pop(context); _pickImage(); }),
                _buildAttachmentButton(icon: Icons.camera_alt, label: 'Camera', color: const Color(0xFF06B6D4), onTap: () { Navigator.pop(context); _takePhoto(); }),
                _buildAttachmentButton(icon: Icons.videocam, label: 'Video', color: Colors.purple, onTap: () { Navigator.pop(context); _pickVideoFromGallery(); }),
                _buildAttachmentButton(icon: Icons.videocam_off, label: 'Record', color: Colors.pink, onTap: () { Navigator.pop(context); _recordVideo(); }),
                _buildAttachmentButton(icon: Icons.insert_drive_file, label: 'Document', color: Colors.blue, onTap: () { Navigator.pop(context); _pickFile(); }),
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
