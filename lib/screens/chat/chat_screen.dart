import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../providers/chat_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/ai_moderation_service.dart';
import '../../utils/verified_badge.dart';
import '../groups/group_info_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_emoji_picker.dart';


class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;
  final String? chatAvatar;
  final bool isGroup;
  final bool isChannel;

  const ChatScreen({
    super.key,
    this.chatId,
    this.chatName,
    this.chatAvatar,
    this.isGroup = false,
    this.isChannel = false,
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
  bool _isChannel = false;
  String? _creatorEmail; 
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
  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _pendingUserFetches = {};
  final ValueNotifier<bool> _hasText = ValueNotifier(false);

  // NEW: self-destruct timer (available in both direct and group chats,
  // matching the website's chat.html and group_chat.html)
  int _selfDestructSeconds = 0;

  // NEW: slow mode (group only, matches group_chat.html)
  int _slowModeSeconds = 0;
  DateTime? _lastSentAt;

  // NEW: group member tracking for mentions (group only)
  List<String> _groupMemberIds = [];
  String? _mentionQuery;
  List<String> _mentionMatches = [];
  bool _showMentionPicker = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAudioPlayer();
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final newValue = _messageController.text.trim().isNotEmpty;
    if (_hasText.value != newValue) {
      _hasText.value = newValue;
    }
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
      _isChannel = args['isChannel'] as bool? ?? false;
    }

    if (_chatId != null && _messages.isEmpty && _isLoading) {
      _loadMessages();
      _subscribeToMessages();
      _loadChatInfo();
      _subscribeToChatInfo();
      _loadPinnedMessages();
      if (!_isGroup) {
        _initDirectChatFeatures();
      }
      _setOnlineStatus();
    }
  }

  /// FIX: _checkBlockStatus() is async and sets _otherUserId only after its
  /// Firestore reads complete. It was previously called without awaiting,
  /// so _subscribeToOtherUserStatus() and _subscribeToTyping() ran immediately
  /// afterward with _otherUserId still null, causing them to silently return
  /// early (see their `if (_otherUserId == null) return;` guards). That meant
  /// the online-status listener never actually attached, so _otherUserStatus
  /// stayed null and the UI always fell back to showing "Online".
  /// Awaiting _checkBlockStatus() first ensures _otherUserId is set before the
  /// dependent subscriptions are started.
  Future<void> _initDirectChatFeatures() async {
    await _checkBlockStatus();
    _subscribeToBlockStatus();
    _subscribeToOtherUserStatus();
    _subscribeToTyping();
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
    _messageController.removeListener(_onTextChanged);
    _hasText.dispose();
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
    _liveLocationTimer?.cancel();
    _liveLocationEndTimer?.cancel();
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
            _creatorEmail = data['created_by_email'] as String?; 
            _chatSettings = data['settings'] as Map<String, dynamic>?;
            _myRole = (data['participants_data']?[userId]?['role'] ?? 'member') as String;

            final isAdmin = _myRole == 'owner' || _myRole == 'admin';
            _canSend = !(_chatSettings?['chat_disabled'] == true && !isAdmin);
            _canSendFiles = !(_chatSettings?['file_sharing_disabled'] == true && !isAdmin);
            _isAnnouncementsOnly = _chatSettings?['announcements_only'] == true && !isAdmin;

            // NEW: self-destruct timer (both direct & group) and slow mode
            // (group only) — read straight off the chat document, matching
            // the fields the website writes (self_destruct_seconds,
            // slow_mode_seconds).
            _selfDestructSeconds = (data['self_destruct_seconds'] ?? 0) as int;
            _slowModeSeconds = _isGroup ? ((data['slow_mode_seconds'] ?? 0) as int) : 0;

            // NEW: group member ids, needed for @mention autocomplete.
            if (_isGroup) {
              _groupMemberIds = List<String>.from(data['participants'] ?? []);
            }
          });

          // NEW: pre-fetch user data for all group members so mention
          // suggestions have names/avatars ready immediately.
          if (_isGroup && _groupMemberIds.isNotEmpty) {
            for (final uid in _groupMemberIds) {
              if (!_userCache.containsKey(uid)) {
                final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                if (userDoc.exists) {
                  final u = userDoc.data()!;
                  _userCache[uid] = {
                    'username': u['username'] ?? u['display_name'] ?? 'Unknown',
                    'avatar_url': u['avatar_url'],
                    'bio': u['bio'],
                    'email': u['email'],
                    'is_verified': u['is_verified'] == true,
                  };
                }
              }
            }
          }
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

          // NEW: keep self-destruct/slow mode in sync live (e.g. an admin
          // changes slow mode while you're already in the chat).
          _selfDestructSeconds = (data['self_destruct_seconds'] ?? 0) as int;
          _slowModeSeconds = _isGroup ? ((data['slow_mode_seconds'] ?? 0) as int) : 0;
          if (_isGroup) {
            _groupMemberIds = List<String>.from(data['participants'] ?? []);
          }
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
      // FIX: removed .where('deleted_for_everyone', isEqualTo: false) from the
      // query. Combining a .where() (equality) on one field with .orderBy() on
      // a DIFFERENT field (created_at) requires a Firestore composite index. If
      // that index was never created in the Firebase console, this exact query
      // fails silently (only a debugPrint, nothing shown to the user), leaving
      // the message list permanently empty — matching "old messages don't show,
      // as if I never sent anything". Filtering deleted_for_everyone client-side
      // instead avoids the composite-index dependency entirely, using the same
      // pattern already used below for the per-user 'deleted_for' array check.
      final snapshot = await firestore
          .collection('chats')
          .doc(_chatId!)
          .collection('messages')
          .orderBy('created_at', descending: false)
          .get();

      final Set<String> userIds = {};
      final List<Map<String, dynamic>> loadedMessages = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['deleted_for_everyone'] == true) continue;
        // NEW: skip messages past their self-destruct expiry (mirrors the
        // website's identical check in loadMessages/renderMessages).
        final destructSecs = data['self_destruct_seconds'] as int?;
        if (destructSecs != null && destructSecs > 0 && data['created_at'] != null) {
          final createdAt = (data['created_at'] as Timestamp).toDate();
          if (DateTime.now().difference(createdAt).inSeconds > destructSecs) continue;
        }
        final senderId = data['sender_id'] as String?;
        if (senderId != null) userIds.add(senderId);
        loadedMessages.add({
          'id': doc.id,
          ...data,
          'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
        });
      }

      // Batch fetch all users at once
      final missingUserIds = userIds.where((id) => !_userCache.containsKey(id) && !_pendingUserFetches.contains(id)).toSet();
      
      if (missingUserIds.isNotEmpty) {
        _pendingUserFetches.addAll(missingUserIds);
        
        final userDocs = await Future.wait(
          missingUserIds.map((id) => firestore.collection('users').doc(id).get()),
        );
        
        _pendingUserFetches.removeAll(missingUserIds);
        for (final userDoc in userDocs) {
          if (userDoc.exists) {
            final u = userDoc.data()!;
            _userCache[userDoc.id] = {
              'username': u['username'] ?? u['display_name'] ?? 'Unknown',
              'avatar_url': u['avatar_url'],
              'bio': u['bio'],
              'email': u['email'], 
              'is_verified': u['is_verified'] == true,
            };
          }
        }
      }

      for (final msg in loadedMessages) {
        final sid = msg['sender_id'] as String?;
        if (sid != null && _userCache.containsKey(sid)) {
          msg['users'] = _userCache[sid];
        } else {
          msg['users'] = {
            'username': 'Unknown',
            'avatar_url': null,
            'bio': null,
            'email': null, 
            'is_verified': false,
          };
        }
      }

      setState(() {
        _messages = loadedMessages;
        _isLoading = false;
      });
      _scrollToBottom(force: true);
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _isLoading = false);
    }
  }
 
    void _subscribeToMessages() {
    if (_chatId == null) return;

    final firestore = FirebaseFirestore.instance;
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;

    // FIX: same as _loadMessages() above — removed the
    // .where('deleted_for_everyone', isEqualTo: false) clause since combining
    // it with .orderBy('created_at') on a different field requires a Firestore
    // composite index that may not exist, silently failing the whole
    // subscription. deleted_for_everyone is now filtered client-side below,
    // right alongside the existing per-user 'deleted_for' check.
    _messageSubscription = firestore
        .collection('chats')
        .doc(_chatId!)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted) return;

          final Set<String> allSenderIds = {};
          final List<Map<String, dynamic>> allMessages = [];

          // First pass: collect all sender IDs and build message list
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final messageId = doc.id;
            final senderId = data['sender_id'] as String?;

            if (data['deleted_for_everyone'] == true) continue;

            // NEW: same self-destruct expiry skip as _loadMessages() above.
            final destructSecs = data['self_destruct_seconds'] as int?;
            if (destructSecs != null && destructSecs > 0 && data['created_at'] != null) {
              final createdAt = (data['created_at'] as Timestamp).toDate();
              if (DateTime.now().difference(createdAt).inSeconds > destructSecs) continue;
            }

            final deletedFor = List<String>.from(data['deleted_for'] ?? []);
            if (deletedFor.contains(currentUserId)) continue;

            if (senderId != null) {
              allSenderIds.add(senderId);
            }

            allMessages.add({
              'id': messageId,
              ...data,
              'created_at': data['created_at']?.toDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
            });
          }

          // Fetch ALL missing users at once (not just from changes)
          final missingUserIds = allSenderIds
              .where((id) => !_userCache.containsKey(id) && !_pendingUserFetches.contains(id))
              .toSet();
          
          if (missingUserIds.isNotEmpty) {
            _pendingUserFetches.addAll(missingUserIds);
            
            final userDocs = await Future.wait(
              missingUserIds.map((id) => firestore.collection('users').doc(id).get()),
            );
            
            _pendingUserFetches.removeAll(missingUserIds);
            
            for (final userDoc in userDocs) {
              if (userDoc.exists) {
                final u = userDoc.data()!;
                _userCache[userDoc.id] = {
                  'username': u['username'] ?? u['display_name'] ?? 'Unknown',
                  'avatar_url': u['avatar_url'],
                  'bio': u['bio'],
                  'email': u['email'], 
                  'is_verified': u['is_verified'] == true,
                };
              }
            }
          }

          // Second pass: apply user data to ALL messages
          for (final msg in allMessages) {
            final sid = msg['sender_id'] as String?;
            if (sid != null && _userCache.containsKey(sid)) {
              msg['users'] = _userCache[sid];
            } else {
              msg['users'] = {
                'username': 'Unknown',
                'avatar_url': null,
                'bio': null,
                'email': null, 
                'is_verified': false,
              };
            }
          }

          setState(() {
            _messages = allMessages;
            _isLoading = false;
          });
          _scrollToBottom(force: _messages.length <= 20);
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

    // FIX: previously this checked `_scrollController.hasClients` immediately
    // and returned early if false — but on the very first load, setState()
    // finishes before the ListView has actually attached to the controller,
    // so hasClients was false and the function bailed out before ever
    // scheduling the delayed jumpTo. That meant the initial auto-scroll to
    // the newest message silently never happened, leaving the chat open on
    // the oldest messages until the user scrolled down manually.
    // Wrapping the whole check in addPostFrameCallback guarantees it only
    // runs after the current frame (including the ListView) has been built,
    // so hasClients is reliably true by the time we check it.
    void _scrollToBottom({bool force = false}) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        if (force || (maxScroll - currentScroll) < 300) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }

  List<TextSpan> _parseTextWithLinks(String text, bool isMe) {
  final urlRegex = RegExp(r'https?://[^\s]+');
  final matches = urlRegex.allMatches(text);
  
  if (matches.isEmpty) {
    return [TextSpan(text: text, style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9)))];
  }

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final match in matches) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(
        text: text.substring(lastEnd, match.start),
        style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9)),
      ));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: TextStyle(
        color: isMe ? Colors.white.withOpacity(0.85) : const Color(0xFF8B5CF6),
        decoration: TextDecoration.underline,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _openLink(match.group(0)!),
    ));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastEnd),
      style: TextStyle(color: isMe ? Colors.white : Colors.white.withOpacity(0.9)),
    ));
  }

  return spans;
}

Future<void> _openLink(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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

      // NEW: slow mode (group only) — placed here in the shared _sendMessage
      // function so it covers text AND media/voice/etc sends, not just typed
      // text messages.
      if (_isGroup && _slowModeSeconds > 0 && _lastSentAt != null) {
        final elapsed = DateTime.now().difference(_lastSentAt!).inSeconds;
        if (elapsed < _slowModeSeconds) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Slow mode: wait ${_slowModeSeconds - elapsed}s before sending again')),
            );
          }
          return;
        }
      }

      final messageId = const Uuid().v4();

      // Optimistic UI - shows immediately
      final optimisticMessage = {
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
        'created_at': DateTime.now().toIso8601String(),
        'self_destruct_seconds': _selfDestructSeconds > 0 ? _selfDestructSeconds : null,
        'is_read': false,
        'is_edited': false,
        'deleted_for_everyone': false,
        'deleted_for': [],
        'reactions': {},
        'sent_to_fcm': false,
        'users': {
          'username': authProvider.displayName ?? authProvider.userName ?? 'You',
          'avatar_url': authProvider.userPhotoUrl,
          'bio': authProvider.userBio,
          'email': authProvider.email, 
          'is_verified': false,
        },
      };

      setState(() {
        _messages.add(optimisticMessage);
        _replyingTo = null;
        _replyingToContent = null;
        _replyingToSender = null;
      });
      _scrollToBottom(force: true);

      final serverMessage = {
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
        'self_destruct_seconds': _selfDestructSeconds > 0 ? _selfDestructSeconds : null,
        'is_read': false,
        'is_edited': false,
        'deleted_for_everyone': false,
        'deleted_for': [],
        'reactions': {},
        'sent_to_fcm': false,
      };

      try {
        await Future.wait([
          firestore.collection('chats').doc(_chatId!).collection('messages').doc(messageId).set(serverMessage),
          firestore.collection('chats').doc(_chatId!).update({
            'last_message': content,
            'last_message_at': FieldValue.serverTimestamp(),
          }),
        ]);
        // NEW: track last send time for slow mode, and schedule
        // auto-delete if a self-destruct timer is set (mirrors the
        // website's setTimeout-based approach).
        _lastSentAt = DateTime.now();
        if (_selfDestructSeconds > 0) {
          Timer(Duration(seconds: _selfDestructSeconds), () {
            firestore.collection('chats').doc(_chatId!).collection('messages').doc(messageId).update({
              'deleted_for_everyone': true,
              'content': 'This message was deleted',
              'media_url': null,
            }).catchError((_) {});
          });
        }
      } catch (e) {
        debugPrint('Firestore write error: $e');
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
        }
        return;
      }

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
  
    Future<void> _unblockUser() async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (currentUserId == null || _otherUserId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'blocked_users': FieldValue.arrayRemove([_otherUserId]),
      });

      setState(() {
        _iBlockedThem = false;
        _isBlocked = _theyBlockedMe;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked')),
        );
      }
    } catch (e) {
      debugPrint('Unblock error: $e');
    }
  }

  Future<void> _deleteChat() async {
    try {
      if (_chatId == null) return;
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (currentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .update({
        'deleted_for': FieldValue.arrayUnion([currentUserId]),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Delete chat error: $e');
    }
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

  // ==================== MENTIONS (group only) ====================

  void _checkForMention(String value) {
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) { setState(() => _showMentionPicker = false); return; }
    final before = value.substring(0, cursor);
    final match = RegExp(r'(^|\s)@([a-zA-Z0-9_]*)$').firstMatch(before);
    if (match == null) {
      setState(() => _showMentionPicker = false);
      return;
    }
    final query = (match.group(2) ?? '').toLowerCase();
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final myId = authProvider.user?.uid ?? authProvider.mockUserId;
    final matches = _groupMemberIds.where((uid) {
      if (uid == myId) return false;
      final u = _userCache[uid];
      if (u == null) return false;
      final name = ((u['username'] ?? u['display_name'] ?? '') as String).toLowerCase();
      if (query.isEmpty) return true;
      return name.contains(query);
    }).take(20).toList();
    setState(() {
      _mentionQuery = query;
      _mentionMatches = matches;
      _showMentionPicker = true;
    });
  }

  void _insertMention(String uid) {
    final u = _userCache[uid];
    final username = (u?['username'] ?? 'user') as String;
    final value = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    final safeCursor = cursor >= 0 ? cursor : value.length;
    final before = value.substring(0, safeCursor);
    final after = value.substring(safeCursor);
    final newBefore = before.replaceFirstMapped(RegExp(r'(^|\s)@([a-zA-Z0-9_]*)$'), (m) => '${m.group(1)}@$username ');
    _messageController.text = newBefore + after;
    _messageController.selection = TextSelection.collapsed(offset: newBefore.length);
    setState(() => _showMentionPicker = false);
  }

  // ==================== ADMIN LOG (group only) ====================

  Future<void> _logAdminAction(String action, String details) async {
    if (!_isGroup || _chatId == null) return;
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      final myName = authProvider.displayName ?? authProvider.userName ?? 'Someone';
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('adminLog').add({
        'action': action,
        'details': details,
        'actor_id': userId,
        'actor_name': myName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Admin log error: $e');
    }
  }

  void _openAdminLog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Admin Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(_chatId)
                    .collection('adminLog')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('No admin actions yet', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final ts = d['timestamp'] as Timestamp?;
                      final timeStr = ts != null ? DateFormat('MMM d, HH:mm').format(ts.toDate()) : '';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.info_outline, color: Color(0xFF8B5CF6), size: 20),
                        title: Text('${d['actor_name'] ?? 'Someone'} ${d['details'] ?? d['action'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SLOW MODE (group only) ====================

  void _openSlowModeDialog() {
    int selected = _slowModeSeconds;
    const options = [0, 10, 30, 60, 300, 900];
    const labels = ['Off', '10 sec', '30 sec', '1 min', '5 min', '15 min'];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a103c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Slow Mode', style: TextStyle(color: Colors.white)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(options.length, (i) {
              final isSelected = selected == options[i];
              return ChoiceChip(
                label: Text(labels[i]),
                selected: isSelected,
                selectedColor: const Color(0xFF8B5CF6),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                onSelected: (_) => setDialogState(() => selected = options[i]),
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({'slow_mode_seconds': selected});
                  setState(() => _slowModeSeconds = selected);
                  _logAdminAction('slow_mode', selected > 0 ? 'enabled slow mode (${selected}s)' : 'disabled slow mode');
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update slow mode')));
                }
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SELF-DESTRUCT TIMER (direct & group) ====================

  void _openSelfDestructDialog() {
    int selected = _selfDestructSeconds;
    const options = [0, 30, 60, 300, 3600, 86400];
    const labels = ['Off', '30 sec', '1 min', '5 min', '1 hour', '24 hours'];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a103c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Self-Destruct Timer', style: TextStyle(color: Colors.white)),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(options.length, (i) {
              final isSelected = selected == options[i];
              return ChoiceChip(
                label: Text(labels[i]),
                selected: isSelected,
                selectedColor: const Color(0xFF8B5CF6),
                backgroundColor: Colors.white.withOpacity(0.05),
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                onSelected: (_) => setDialogState(() => selected = options[i]),
              );
            }),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({'self_destruct_seconds': selected});
                  setState(() => _selfDestructSeconds = selected);
                  if (_isGroup) _logAdminAction('self_destruct', selected > 0 ? 'set self-destruct to ${selected}s' : 'disabled self-destruct');
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update self-destruct')));
                }
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF8B5CF6))),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MORE OPTIONS MENU ====================

  void _showMoreOptionsMenu() {
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
            ListTile(
              leading: const Icon(Icons.whatshot, color: Colors.red),
              title: const Text('Self-Destruct Timer', style: TextStyle(color: Colors.white)),
              subtitle: Text(_selfDestructSeconds > 0 ? 'On — ${_selfDestructSeconds}s' : 'Off', style: TextStyle(color: Colors.white.withOpacity(0.4))),
              onTap: () { Navigator.pop(context); _openSelfDestructDialog(); },
            ),
            if (_isGroup) ...[
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.orange),
                title: const Text('Slow Mode', style: TextStyle(color: Colors.white)),
                subtitle: Text(_slowModeSeconds > 0 ? '${_slowModeSeconds}s between messages' : 'Off', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                onTap: () { Navigator.pop(context); _openSlowModeDialog(); },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Color(0xFF06B6D4)),
                title: const Text('Admin Log', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _openAdminLog(); },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== POLLS (group only) ====================

  void _openPollDialog() {
    final questionController = TextEditingController();
    final optionControllers = <TextEditingController>[TextEditingController(), TextEditingController()];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a103c),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Poll', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: 'Ask a question...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                ...optionControllers.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: entry.value,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(hintText: 'Option ${entry.key + 1}', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
                    ),
                  );
                }),
                if (optionControllers.length < 10)
                  TextButton(
                    onPressed: () => setDialogState(() => optionControllers.add(TextEditingController())),
                    child: const Text('+ Add option', style: TextStyle(color: Color(0xFF8B5CF6))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
            TextButton(
              onPressed: () async {
                final question = questionController.text.trim();
                final options = optionControllers.map((c) => c.text.trim()).where((v) => v.isNotEmpty).toList();
                if (question.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a question and at least 2 options')));
                  return;
                }
                Navigator.pop(context);
                await _sendPoll(question, options);
              },
              child: const Text('Create', style: TextStyle(color: Color(0xFF8B5CF6))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPoll(String question, List<String> options) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;
      final msgRef = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc();
      await msgRef.set({
        'id': msgRef.id,
        'sender_id': userId,
        'type': 'poll',
        'media_type': 'poll',
        'poll': {'question': question, 'options': options, 'votes': {}},
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 'is_edited': false, 'deleted_for_everyone': false, 'deleted_for': [], 'reactions': {},
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'last_message': '📊 Poll', 'last_message_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create poll: $e')));
    }
  }

  Future<void> _votePoll(String msgId, int optionIndex) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;
      final msgRef = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgId);
      final doc = await msgRef.get();
      if (!doc.exists) return;
      final poll = Map<String, dynamic>.from(doc.data()?['poll'] ?? {});
      final votes = Map<String, dynamic>.from(poll['votes'] ?? {});
      if (votes[userId] == optionIndex) {
        votes.remove(userId);
      } else {
        votes[userId] = optionIndex;
      }
      poll['votes'] = votes;
      await msgRef.update({'poll': poll});
    } catch (e) {
      debugPrint('Vote poll error: $e');
    }
  }

  // ==================== LOCATION SHARING (group only) ====================

  Future<void> _shareLocation() async {
    Navigator.pop(context); // close attachment sheet
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable location services')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission permanently denied')));
        return;
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Getting location...')));
      final pos = await Geolocator.getCurrentPosition();
      String label = 'Shared location';
      try {
        final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=14'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['display_name'] != null) {
            label = (data['display_name'] as String).split(',').take(3).join(', ');
          }
        }
      } catch (_) {}

      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;
      final msgRef = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc();
      await msgRef.set({
        'id': msgRef.id,
        'sender_id': userId,
        'type': 'location',
        'media_type': 'location',
        'location_lat': pos.latitude,
        'location_lng': pos.longitude,
        'location_label': label,
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 'is_edited': false, 'deleted_for_everyone': false, 'deleted_for': [], 'reactions': {},
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'last_message': '📍 Location', 'last_message_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share location: $e')));
    }
  }

  // NEW: live location — periodically updates the same message doc with a
  // fresh position for 15 minutes, then marks it ended. Uses a repeating
  // Timer + getCurrentPosition rather than a raw position stream, to keep
  // resource cleanup simple and predictable.
  Timer? _liveLocationTimer;
  Timer? _liveLocationEndTimer;

  Future<void> _startLiveLocation() async {
    Navigator.pop(context);
    if (_liveLocationTimer != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Already sharing live location')));
      return;
    }
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;

      final pos = await Geolocator.getCurrentPosition();
      final msgRef = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc();
      await msgRef.set({
        'id': msgRef.id,
        'sender_id': userId,
        'type': 'location',
        'media_type': 'location',
        'location_live': true,
        'location_lat': pos.latitude,
        'location_lng': pos.longitude,
        'location_label': 'Live location',
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 'is_edited': false, 'deleted_for_everyone': false, 'deleted_for': [], 'reactions': {},
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'last_message': '📍 Live location', 'last_message_at': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live location started (15 min)')));

      _liveLocationTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
        try {
          final p = await Geolocator.getCurrentPosition();
          await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgRef.id).update({
            'location_lat': p.latitude,
            'location_lng': p.longitude,
          });
        } catch (_) {}
      });
      _liveLocationEndTimer = Timer(const Duration(minutes: 15), () => _stopLiveLocation(msgRef.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start live location: $e')));
    }
  }

  Future<void> _stopLiveLocation(String msgId) async {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    _liveLocationEndTimer?.cancel();
    _liveLocationEndTimer = null;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc(msgId).update({
        'location_live': false,
        'location_label': 'Live location ended',
      });
    } catch (_) {}
  }

  void _openLocationMap(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ==================== CONTACT SHARING (group only) ====================

  Future<void> _openShareContactSheet() async {
    Navigator.pop(context); // close attachment sheet
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final myId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (myId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: myId).get(),
        builder: (context, snapshot) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Share a Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                Flexible(
                  child: !snapshot.hasData
                    ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: _collectDirectContacts(snapshot.data!.docs, myId),
                        builder: (context, contactSnap) {
                          if (!contactSnap.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
                          final contacts = contactSnap.data!;
                          if (contacts.isEmpty) return Padding(padding: const EdgeInsets.all(20), child: Text('No contacts found', style: TextStyle(color: Colors.white.withOpacity(0.3))));
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: contacts.length,
                            itemBuilder: (context, i) {
                              final c = contacts[i];
                              final name = (c['display_name'] ?? c['username'] ?? 'User') as String;
                              final avatarUrl = c['avatar_url'] as String?;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                  child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white)),
                                onTap: () { Navigator.pop(context); _shareContact(c); },
                              );
                            },
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _collectDirectContacts(List<QueryDocumentSnapshot> chatDocs, String myId) async {
    final contacts = <Map<String, dynamic>>[];
    for (final doc in chatDocs) {
      final c = doc.data() as Map<String, dynamic>;
      if ((c['type'] ?? 'direct') != 'direct') continue;
      final participants = List<String>.from(c['participants'] ?? []);
      final otherId = participants.firstWhere((id) => id != myId, orElse: () => '');
      if (otherId.isEmpty) continue;
      if (_userCache.containsKey(otherId)) {
        contacts.add({'uid': otherId, ..._userCache[otherId]!});
        continue;
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherId).get();
      if (userDoc.exists) {
        final u = userDoc.data()!;
        final entry = {
          'uid': otherId,
          'username': u['username'] ?? 'Unknown',
          'display_name': u['display_name'] ?? u['username'] ?? 'Unknown',
          'avatar_url': u['avatar_url'],
        };
        _userCache[otherId] = entry;
        contacts.add(entry);
      }
    }
    return contacts;
  }

  Future<void> _shareContact(Map<String, dynamic> contact) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? authProvider.mockUserId;
      if (userId == null || _chatId == null) return;
      final msgRef = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').doc();
      await msgRef.set({
        'id': msgRef.id,
        'sender_id': userId,
        'type': 'contact',
        'media_type': 'contact',
        'contact': {
          'uid': contact['uid'],
          'username': contact['username'],
          'display_name': contact['display_name'] ?? contact['username'],
          'avatar_url': contact['avatar_url'],
        },
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false, 'is_edited': false, 'deleted_for_everyone': false, 'deleted_for': [], 'reactions': {},
      });
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({
        'last_message': '👤 Contact', 'last_message_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share contact: $e')));
    }
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
                onTap: _chatId != null && (_isGroup || _isChannel)
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupInfoScreen(
                          chatId: _chatId!,
                          chatName: _chatName ?? (_isChannel ? 'Channel' : 'Group'),
                          chatAvatar: _chatAvatar,
                          isChannel: _isChannel,
                        ),
                      ),
                    )
                  : !_isGroup && !_isChannel && _otherUserId != null && !_isBlocked
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
                            email: _isGroup ? _creatorEmail : null, 
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
                if ((_isGroup || _isChannel) && _chatId != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white70),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupInfoScreen(
                          chatId: _chatId!,
                          chatName: _chatName ?? (_isChannel ? 'Channel' : 'Group'),
                          chatAvatar: _chatAvatar,
                          isChannel: _isChannel,
                        ),
                      ),
                    ),
                  ),
                // NEW: self-destruct timer (both) / slow mode + admin log
                // (group only) live here, kept as an additive icon so
                // nothing already in the AppBar is disturbed.
                if (_chatId != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onPressed: _showMoreOptionsMenu,
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
            GestureDetector(
              onTap: () {
                if (_iBlockedThem) {
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
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Icon(Icons.block, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'You blocked this contact',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You will no longer receive messages or calls from this person.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _unblockUser();
                                  },
                                  icon: const Icon(Icons.block_flipped, color: Colors.white),
                                  label: const Text('Unblock'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteChat();
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                                  label: const Text('Delete Chat'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: Colors.red.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 16, color: Colors.red.withOpacity(0.8)),
                    const SizedBox(width: 8),
                    Text(
                      _iBlockedThem
                        ? 'You blocked this person. Tap to unblock.'
                        : 'This user blocked you. You cannot send messages.',
                      style: TextStyle(color: Colors.red.withOpacity(0.9), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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

          // NEW: slow mode banner (group only), matching the website's
          // .slow-mode-banner.
          if (_isGroup && _slowModeSeconds > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: const Color(0xFFFBBF24).withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 8),
                  Text(
                    'Slow mode — wait ${_slowModeSeconds}s between messages',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
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

          // FIX: typing indicator moved here, below the message list and
          // above the reply bar/input — it was previously placed ABOVE the
          // Expanded(ListView) block, which put it at the top of the screen
          // instead of near the newest message like WhatsApp/Telegram show
          // it. Moving the same widget after the list (not duplicating it)
          // fixes the position without changing its look.
          if (!_isGroup && !_isBlocked && _otherUserTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
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
  CustomEmojiPicker(
    onEmojiSelected: (emoji) {
      setState(() => _messageController.text += emoji);
    },
    onClose: () => setState(() => _showEmojiPicker = false),
  ),

          // NEW: @mention picker (group only) — shows above the input when
          // the user types "@" followed by letters, matching the website's
          // mention-picker behavior in group_chat.html.
          if (_isGroup && _showMentionPicker)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFF1a103c),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: _mentionMatches.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No members found', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mentionMatches.length,
                    itemBuilder: (context, i) {
                      final uid = _mentionMatches[i];
                      final u = _userCache[uid];
                      final name = (u?['username'] ?? u?['display_name'] ?? 'User') as String;
                      final avatarUrl = u?['avatar_url'] as String?;
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)) : null,
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        onTap: () => _insertMention(uid),
                      );
                    },
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
                        onChanged: (val) {
                          _startTyping();
                          if (_isGroup) _checkForMention(val);
                        },
                        onSubmitted: (_) => _sendTextMessage(),
                        onTap: () { if (_showEmojiPicker) setState(() => _showEmojiPicker = false); },
                        enabled: _canSend && !_isAnnouncementsOnly && !(_isBlocked && !_isGroup),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic or Send button — PERFECT FIX: ValueListenableBuilder for instant toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: _hasText,
                    builder: (context, hasText, child) {
                      final isDisabled = (_isBlocked && !_isGroup) || !_canSend || _isAnnouncementsOnly;
                      
                      if (!hasText && !_isRecording) {
                        // MIC BUTTON
                        return GestureDetector(
                          onLongPressStart: isDisabled ? null : (_) => _startRecording(),
                          onLongPressEnd: isDisabled ? null : (_) => _stopRecordingAndSend(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDisabled
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
                        );
                      } else if (!_isRecording) {
                        // SEND BUTTON
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDisabled || !hasText
                                ? [Colors.grey, Colors.grey]
                                : [const Color(0xFF8B5CF6), const Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20),
                            onPressed: (_canSend && !_isAnnouncementsOnly && hasText && !(_isBlocked && !_isGroup))
                              ? _sendTextMessage
                              : null,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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
    final rawUser = message['users'];
    final Map<String, dynamic>? user = rawUser is Map<String, dynamic> ? rawUser : null;
    final isEdited = message['is_edited'] == true;
    final senderId = message['sender_id'] as String?;
    final senderEmail = user?['email'] as String?; 
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
                                  username: user?['username'] ?? (senderId != null ? 'Loading...' : 'Unknown'),
                                  email: senderEmail, 
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
                            RichText(text: TextSpan(children: _parseTextWithLinks(content, isMe)))
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
                          // NEW: location, contact, and poll bubbles (group
                          // only in practice since only the group attachment
                          // sheet can create them, but rendered generically
                          // here in case a message is forwarded into a
                          // direct chat).
                          else if (type == 'location')
                            _buildLocationBubble(message: message, isMe: isMe)
                          else if (type == 'contact')
                            _buildContactBubble(message: message, isMe: isMe)
                          else if (type == 'poll')
                            _buildPollBubble(message: message)
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
                                // FIX: added blue (#06B6D4) color for the read
                                // state, matching the website's exact CSS
                                // (.tick.read { color: #06B6D4; }). Previously
                                // both states used shades of white/grey only,
                                // so there was no clear visual distinction
                                // between "delivered" and "read".
                                Icon(
                                  message['is_read'] == true ? Icons.done_all : Icons.done, 
                                  size: 14, 
                                  color: message['is_read'] == true
                                      ? const Color(0xFF06B6D4)
                                      : Colors.white.withOpacity(0.6),
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
      onTap: isInitialized ? () => _openFullScreenVideo(videoUrl) : null,
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
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
                    ),
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
  
    void _openFullScreenVideo(String videoUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: _FullScreenVideoPlayer(videoUrl: videoUrl),
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

  // NEW: location bubble — tap to open in Google Maps.
  Widget _buildLocationBubble({required Map<String, dynamic> message, required bool isMe}) {
    final lat = (message['location_lat'] ?? 0).toDouble();
    final lng = (message['location_lng'] ?? 0).toDouble();
    final label = message['location_label'] ?? 'Shared location';
    final isLive = message['location_live'] == true;
    return GestureDetector(
      onTap: () => _openLocationMap(lat, lng),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: isLive ? Colors.red.withOpacity(0.08) : const Color(0xFF8B5CF6).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isLive ? Colors.red.withOpacity(0.3) : const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLive
                          ? [Colors.red.withOpacity(0.25), Colors.orange.withOpacity(0.15)]
                          : [const Color(0xFF06B6D4).withOpacity(0.25), const Color(0xFF8B5CF6).withOpacity(0.25)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Icon(Icons.location_on, color: isLive ? Colors.red : const Color(0xFF8B5CF6), size: 36),
                  alignment: Alignment.center,
                ),
                if (isLive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                      child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(Icons.place, size: 14, color: isLive ? Colors.red : const Color(0xFF8B5CF6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: shared-contact bubble — tap to view their public profile.
  Widget _buildContactBubble({required Map<String, dynamic> message, required bool isMe}) {
    final contact = Map<String, dynamic>.from(message['contact'] ?? {});
    final name = (contact['display_name'] ?? contact['username'] ?? 'Contact') as String;
    final username = (contact['username'] ?? 'user') as String;
    final avatarUrl = contact['avatar_url'] as String?;
    final uid = contact['uid'] as String?;
    return GestureDetector(
      onTap: uid != null
          ? () => Navigator.pushNamed(context, '/public_profile', arguments: {'userId': uid, 'username': username, 'avatar_url': avatarUrl})
          : null,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)])),
              child: avatarUrl != null
                  ? ClipOval(child: CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover))
                  : Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('@$username', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
          ],
        ),
      ),
    );
  }

  // NEW: poll bubble — tap an option to vote/change vote.
  Widget _buildPollBubble({required Map<String, dynamic> message}) {
    final poll = Map<String, dynamic>.from(message['poll'] ?? {});
    final question = (poll['question'] ?? 'Poll') as String;
    final options = List<String>.from(poll['options'] ?? []);
    final votes = Map<String, dynamic>.from(poll['votes'] ?? {});
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final myId = authProvider.user?.uid ?? authProvider.mockUserId;
    final totalVotes = votes.length;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(question, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final optText = entry.value;
            final count = votes.values.where((v) => v == i).length;
            final myVote = votes[myId] == i;
            final pct = totalVotes > 0 ? count / totalVotes : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => _votePoll(message['id'], i),
                child: Stack(
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.25), borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 16, height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: myVote ? const Color(0xFF8B5CF6) : Colors.transparent,
                                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.6), width: 2),
                              ),
                              child: myVote ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(optText, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            if (count > 0) Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
          Text('$totalVotes vote${totalVotes != 1 ? 's' : ''}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10), textAlign: TextAlign.right),
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
                // NEW: group-only extras, matching the website's
                // group_chat.html attachment sheet (the direct-chat sheet on
                // the website has none of these, so they're kept out of
                // direct chats here too for parity).
                if (_isGroup) ...[
                  _buildAttachmentButton(icon: Icons.poll, label: 'Poll', color: const Color(0xFF06B6D4), onTap: () { Navigator.pop(context); _openPollDialog(); }),
                  _buildAttachmentButton(icon: Icons.location_on, label: 'Location', color: const Color(0xFF10B981), onTap: _shareLocation),
                  _buildAttachmentButton(icon: Icons.satellite_alt, label: 'Live Loc', color: Colors.red, onTap: _startLiveLocation),
                  _buildAttachmentButton(icon: Icons.contact_page, label: 'Contact', color: Colors.amber, onTap: _openShareContactSheet),
                ],
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

class _FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPlayer({required this.videoUrl});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
    _hideControlsAfterDelay();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _hideControlsAfterDelay() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
        if (_showControls) _hideControlsAfterDelay();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          ),
          if (_showControls && _controller.value.isInitialized) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF8B5CF6),
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            });
                            _hideControlsAfterDelay();
                          },
                        ),
                        Text(
                          '${_fmt(_controller.value.position)} / ${_fmt(_controller.value.duration)}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );    
  }
}    
