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

  bool _showEmojiPicker = false;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;
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
    _messageSubscription?.cancel();
    _blockSubscription?.cancel();
    _otherUserSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _statusTimer?.cancel();
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

  /// Add/remove reaction
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

  /// Show reaction picker
  void _showReactionPicker(String messageId) {
    final reactions = ['❤️', '👍', '👎', '😂', '😮', '😢', '🎉', '🔥'];

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
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: reactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleReaction(messageId, emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Forward message
  void _forwardMessage(Map<String, dynamic> message) {
    Navigator.pushNamed(context, '/forward_message', arguments: {
      'message': message,
      'fromChatId': _chatId,
    });
  }

  /// Copy message text
  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  /// Pin message
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

  /// Unpin message
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

  /// Search messages
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
            // Quick reactions row
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
                        padding: const EdgeInsets.all(8),
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
                  final senderId = message['sender_id'] as String?;
                  final user = message['users'];
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

  Future<void> _pickImage() async {
    if (!_canSendFiles) {
      _showPermissionDenied();
      return;
    }
    if (!_isGroup && _isBlocked) {
      _showBlockedWarning();
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
    if (!_isGroup && _isBlocked) {
      _showBlockedWarning();
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
    if (!_isGroup && _isBlocked) {
      _showBlockedWarning();
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

  /// Check if date separator should show
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
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Colors.red.withOpacity(0.8),
                                ),
                              )
                            else if (_otherUserTyping)
                              const Text(
                                'typing...',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: Color(0xFF06B6D4),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else if (_otherUserStatus != null)
                              Text(
                                _otherUserStatus!,
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: const Color(0xFF06B6D4).withOpacity(0.8),
                                ),
                              )
                            else
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 12, 
                                  color: const Color(0xFF06B6D4).withOpacity(0.8),
                                ),
                              ),
                          ] else ...[
                            Text(
                              '$_myRole \u2022 Tap for info',
                              style: TextStyle(
                                fontSize: 12, 
                                color: const Color(0xFF06B6D4).withOpacity(0.8),
                              ),
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
                  onPressed: (_isBlocked && !_isGroup) 
                    ? _showBlockedWarning 
                    : () {}
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.white70), 
                  onPressed: (_isBlocked && !_isGroup) 
                    ? _showBlockedWarning 
                    : () {}
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (_isBlocked && !_isGroup) || !_canSend || _isAnnouncementsOnly
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
                        // Reply preview
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
                                  left: BorderSide(
                                    color: const Color(0xFF8B5CF6),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['reply_to_sender'] ?? 'Unknown',
                                    style: const TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    message['reply_to_content'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMe ? Colors.white70 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_isGroup && !isMe && showAvatar)
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
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF8B5CF6).withOpacity(0.9)),
                                badgeSize: 12, spacing: 4,
                              ),
                            ),
                          ),

                        if (isDeleted)
                          Text(
                            'This message was deleted',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else if (type == 'text')
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
                            Text(
                              DateFormat('HH:mm').format(createdAt), 
                              style: TextStyle(
                                fontSize: 10, 
                                color: isMe ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4),
                              ),
                            ),
                            if (isEdited && !isDeleted) ...[
                              const SizedBox(width: 4),
                              Text('edited', style: TextStyle(fontSize: 10, color: isMe ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3), fontStyle: FontStyle.italic)),
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

                  // Reactions row
                  if (reactions.isNotEmpty)
                    Positioned(
                      bottom: -10,
                      right: isMe ? null : 0,
                      left: isMe ? 0 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1a103c),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: reactions.entries.map((entry) {
                            final emoji = entry.key;
                            final count = (entry.value as List).length;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                '$emoji${count > 1 ? count : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
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
