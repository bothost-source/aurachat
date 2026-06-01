import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import 'connectivity.dart';

// ============================================================================
// FIREBASE CHAT SERVICE — Real-time messaging backend
// ============================================================================
class FirebaseChatService {
  static final FirebaseChatService _instance = FirebaseChatService._internal();
  factory FirebaseChatService() => _instance;
  FirebaseChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream subscriptions for cleanup
  final Map<String, StreamSubscription> _chatSubscriptions = {};
  final Map<String, StreamSubscription> _messageSubscriptions = {};
  final Map<String, StreamSubscription> _typingSubscriptions = {};

  // Local queue for offline messages
  final List<QueuedMessage> _offlineQueue = [];
  Timer? _syncTimer;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  bool get _isAuthenticated => currentUserId != null;

  // Initialize service
  void initialize() {
    // Start sync timer for offline queue
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => _processOfflineQueue());

    // Listen for connectivity changes to sync when back online
    ConnectivityService().stateStream.listen((state) {
      if (state == NetworkState.online) {
        _processOfflineQueue();
      }
    });
  }

  // ==========================================================================
  // CHAT MANAGEMENT
  // ==========================================================================

  // Create or get existing 1-on-1 chat
  Future<String> createDirectChat(String otherUserId) async {
    if (!_isAuthenticated) throw Exception('Not authenticated');

    final userId = currentUserId;
    final chatId = _getDirectChatId(currentUserId!, otherUserId!);

    final chatRef = _firestore.collection('chats').doc(chatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      // Create new chat
      await chatRef.set({
        'id': chatId,
        'type': 'private',
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'unreadCount': {currentUserId: 0, otherUserId: 0},
      });
    }

    return chatId;
  }

  // Create group chat
  Future<String> createGroupChat({
    required String name,
    String? description,
    required List<String> memberIds,
    bool isPublic = true,
  }) async {
    if (!_isAuthenticated) throw Exception('Not authenticated');

    final userId = currentUserId;
    final allMembers = [currentUserId, ...memberIds.where((id) => id != currentUserId)];

    final chatRef = _firestore.collection('chats').doc();

    await chatRef.set({
      'id': chatRef.id,
      'type': 'group',
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'creatorId': currentUserId,
      'admins': [currentUserId],
      'members': allMembers.map((id) => {
        'userId': id,
        'role': id == currentUserId ? 'admin' : 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      }).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'unreadCount': {for (var id in allMembers) id: 0},
    });

    return chatRef.id;
  }

  // Create channel
  Future<String> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    if (!_isAuthenticated) throw Exception('Not authenticated');

    final userId = currentUserId;
    final chatRef = _firestore.collection('chats').doc();

    await chatRef.set({
      'id': chatRef.id,
      'type': 'channel',
      'name': name,
      'description': description,
      'isPublic': isPublic,
      'creatorId': currentUserId,
      'admins': [currentUserId],
      'subscribers': [currentUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'subscriberCount': 1,
    });

    return chatRef.id;
  }

  // Get user's chats stream
  Stream<List<ChatModel>> getUserChats() {
    if (!_isAuthenticated) return Stream.value([]);

    final userId = currentUserId!;

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _chatFromFirestore(doc)).toList());
  }

  // Get group chats stream
  Stream<List<ChatModel>> getUserGroups() {
    if (!_isAuthenticated) return Stream.value([]);

    final userId = currentUserId;

    return _firestore
        .collection('chats')
        .where('members', arrayContains: currentUserId)
        .where('type', isEqualTo: 'group')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _chatFromFirestore(doc)).toList());
  }

  // Subscribe to chat updates
  void subscribeToChat(String chatId, Function(ChatModel) onUpdate) {
    _chatSubscriptions[chatId]?.cancel();

    _chatSubscriptions[chatId] = _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        onUpdate(_chatFromFirestore(doc));
      }
    });
  }

  // ==========================================================================
  // MESSAGING
  // ==========================================================================

  // Send message (with offline support)
  Future<void> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? replyToMessageId,
    String? forwardFromChatId,
    String? forwardFromMessageId,
  }) async {
    if (!_isAuthenticated) throw Exception('Not authenticated');

    final userId = currentUserId!;
    final messageId = '${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';

    final message = MessageModel(
      id: messageId,
      chatId: chatId,
      senderId: currentUserId ?? '',
      senderName: _auth.currentUser?.displayName ?? 'You',
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      replyToMessageId: replyToMessageId,
      forwardFromChatId: forwardFromChatId,
      forwardFromMessageId: forwardFromMessageId,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      readBy: [],
      deliveredTo: [],
    );

    // Check connectivity
    if (ConnectivityService().currentState != NetworkState.online) {
      // Queue for later
      _offlineQueue.add(QueuedMessage(
        message: message,
        chatId: chatId,
      ));

      // Save to local storage
      await _saveOfflineQueue();

      // Return immediately — will sync when online
      return;
    }

    await _sendToFirebase(message, chatId);
  }

  // Actually send to Firebase
  Future<void> _sendToFirebase(MessageModel message, String chatId) async {
    try {
      final userId = currentUserId;

      // Add message to Firestore
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(message.id)
          .set({
        'id': message.id,
        'chatId': chatId,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'type': message.type.name,
        'content': message.content,
        'mediaUrl': message.mediaUrl,
        'replyToMessageId': message.replyToMessageId,
        'forwardFromChatId': message.forwardFromChatId,
        'forwardFromMessageId': message.forwardFromMessageId,
        'status': 'sent',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [currentUserId], // Sender has "read" it
        'deliveredTo': [],
        'contentFlag': 'none',
        'isDeleted': false,
      });

      // Update chat last message
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': {
          'content': message.content,
          'senderId': message.senderId,
          'type': message.type.name,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Increment unread count for other participants
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final data = chatDoc.data();
      if (data != null) {
        final participants = List<String>.from(data['participants'] ?? []);
        final unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});

        for (final participantId in participants) {
          if (participantId != currentUserId) {
            unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
          }
        }

        await _firestore.collection('chats').doc(chatId).update({
          'unreadCount': unreadCount,
        });
      }
    } catch (e) {
      // If failed, queue for retry
      _offlineQueue.add(QueuedMessage(message: message, chatId: chatId));
      await _saveOfflineQueue();
      rethrow;
    }
  }

  // Process offline queue
  Future<void> _processOfflineQueue() async {
    if (_offlineQueue.isEmpty) return;
    if (ConnectivityService().currentState != NetworkState.online) return;

    final queue = List<QueuedMessage>.from(_offlineQueue);
    _offlineQueue.clear();

    for (final queued in queue) {
      try {
        await _sendToFirebase(queued.message, queued.chatId);
      } catch (e) {
        // Put back in queue if still failing
        _offlineQueue.add(queued);
      }
    }

    await _saveOfflineQueue();
  }

  // Save offline queue to SharedPreferences
  Future<void> _saveOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = _offlineQueue.map((q) => jsonEncode({
      'message': q.message.toJson(),
      'chatId': q.chatId,
    })).toList();
    await prefs.setStringList('offline_message_queue', queueJson);
  }

  // Load offline queue from SharedPreferences
  Future<void> loadOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getStringList('offline_message_queue') ?? [];

    _offlineQueue.clear();
    for (final item in queueJson) {
      try {
        final data = jsonDecode(item);
        // Parse message from JSON
        _offlineQueue.add(QueuedMessage(
          message: _messageFromJson(data['message']),
          chatId: data['chatId'],
        ));
      } catch (_) {
        // Skip invalid entries
      }
    }
  }

  // ==========================================================================
  // REAL-TIME MESSAGE STREAMS
  // ==========================================================================

  // Get messages stream for a chat
  Stream<List<MessageModel>> getMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => _messageFromFirestore(doc)).toList());
  }

  // Subscribe to messages
  void subscribeToMessages(String chatId, Function(List<MessageModel>) onMessages) {
    _messageSubscriptions[chatId]?.cancel();

    _messageSubscriptions[chatId] = getMessages(chatId).listen(onMessages);
  }

  // Mark messages as read
  Future<void> markAsRead(String chatId) async {
    if (!_isAuthenticated) return;

    final userId = currentUserId;

    // Get unread messages
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('readBy', arrayContains: currentUserId)
        .get();

    final batch = _firestore.batch();

    for (final doc in messages.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(currentUserId)) {
        readBy: [if (currentUserId != null) currentUserId],
        batch.update(doc.reference, {'readBy': readBy});
      }
    }

    await batch.commit();

    // Reset unread count for this user
    await _firestore.collection('chats').doc(chatId).update({
      'unreadCount.$currentUserId': 0,
    });
  }

  // Mark message as delivered
  Future<void> markAsDelivered(String chatId, String messageId) async {
    if (!_isAuthenticated) return;

    final userId = currentUserId;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deliveredTo': FieldValue.arrayUnion([currentUserId]),
    });
  }

  // ==========================================================================
  // TYPING INDICATORS
  // ==========================================================================

  // Set typing status
  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    if (!_isAuthenticated) return;

    final userId = currentUserId;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .doc(currentUserId)
        .set({
      'isTyping': isTyping,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Subscribe to typing indicators
  Stream<List<String>> getTypingUsers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .where('isTyping', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // ==========================================================================
  // SEARCH USERS
  // ==========================================================================

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  void unsubscribeFromChat(String chatId) {
    _chatSubscriptions[chatId]?.cancel();
    _chatSubscriptions.remove(chatId);

    _messageSubscriptions[chatId]?.cancel();
    _messageSubscriptions.remove(chatId);

    _typingSubscriptions[chatId]?.cancel();
    _typingSubscriptions.remove(chatId);
  }

  void dispose() {
    _syncTimer?.cancel();
    for (final sub in _chatSubscriptions.values) sub.cancel();
    for (final sub in _messageSubscriptions.values) sub.cancel();
    for (final sub in _typingSubscriptions.values) sub.cancel();
    _chatSubscriptions.clear();
    _messageSubscriptions.clear();
    _typingSubscriptions.clear();
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _getDirectChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return 'direct_${sorted[0]}_${sorted[1]}';
  }

  ChatModel _chatFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] as String?;

    return ChatModel(
      id: doc.id,
      name: data['name'] ?? data['displayName'] ?? 'Unknown',
      avatarUrl: data['avatarUrl'],
      participants: (data['participants'] as List<dynamic>?)
          ?.map((p) => UserModel(
            id: p is String ? p : p['userId'] ?? '',
            username: p is Map ? p['username'] ?? '' : '',
            displayName: p is Map ? p['displayName'] ?? '' : '',
            phoneNumber: '',
            createdAt: DateTime.now(),
          ))
          .toList() ?? [],
      type: type == 'group' ? ChatType.group : type == 'channel' ? ChatType.channel : ChatType.private,
      isPublic: data['isPublic'] ?? true,
      description: data['description'],
      creatorId: data['creatorId'],
      adminIds: (data['admins'] as List<dynamic>?)?.cast<String>() ?? [],
      members: (data['members'] as List<dynamic>?)
          ?.map((m) => GroupMember(
            id: m['userId'] ?? '',
            name: m['name'] ?? '',
            role: _parseRole(m['role']),
            joinedAt: (m['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ))
          .toList() ?? [],
      subscribers: (data['subscribers'] as List<dynamic>?)
          ?.map((s) => GroupMember(
            id: s['userId'] ?? '',
            name: s['name'] ?? '',
            role: _parseRole(s['role']),
            joinedAt: (s['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ))
          .toList() ?? [],
      memberCount: data['memberCount'] ?? (data['members'] as List?)?.length ?? 0,
      subscriberCount: data['subscriberCount'] ?? (data['subscribers'] as List?)?.length ?? 0,
      onlineCount: data['onlineCount'] ?? 0,
      unreadCount: data['unreadCount'] != null
          ? (data['unreadCount'] as Map<String, dynamic>)[currentUserId ?? ''] ?? 0
          : 0,
      isPinned: false,
      isMuted: false,
      isArchived: false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] != null
          ? MessageModel(
              id: 'last',
              chatId: doc.id,
              senderId: data['lastMessage']['senderId'] ?? '',
              content: data['lastMessage']['content'] ?? '',
              type: _parseMessageType(data['lastMessage']['type']),
              createdAt: (data['lastMessage']['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              status: MessageStatus.sent,
            )
          : null,
    );
  }

  MessageModel _messageFromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'],
      type: _parseMessageType(data['type']),
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'],
      replyToMessageId: data['replyToMessageId'],
      forwardFromChatId: data['forwardFromChatId'],
      forwardFromMessageId: data['forwardFromMessageId'],
      status: _parseMessageStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: (data['readBy'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveredTo: (data['deliveredTo'] as List<dynamic>?)?.cast<String>() ?? [],
      contentFlag: _parseContentFlag(data['contentFlag']),
      isDeleted: data['isDeleted'] ?? false,
      isRestricted: data['isRestricted'] ?? false,
      restrictionNote: data['restrictionNote'],
    );
  }

  MessageModel _messageFromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      chatId: json['chatId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'],
      type: _parseMessageType(json['type']),
      content: json['content'] ?? '',
      mediaUrl: json['mediaUrl'],
      status: _parseMessageStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      readBy: (json['readBy'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveredTo: (json['deliveredTo'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'voice': return MessageType.voice;
      case 'document': return MessageType.document;
      case 'location': return MessageType.location;
      case 'contact': return MessageType.contact;
      case 'sticker': return MessageType.sticker;
      case 'poll': return MessageType.poll;
      case 'forwarded': return MessageType.forwarded;
      case 'reply': return MessageType.reply;
      case 'botCommand': return MessageType.botCommand;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  MessageStatus _parseMessageStatus(String? status) {
    switch (status) {
      case 'sending': return MessageStatus.sending;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  ContentFlag _parseContentFlag(String? flag) {
    switch (flag) {
      case 'spam': return ContentFlag.spam;
      case 'illegal': return ContentFlag.illegal;
      case 'harassment': return ContentFlag.harassment;
      case 'violence': return ContentFlag.violence;
      case 'explicit': return ContentFlag.explicit;
      case 'misinformation': return ContentFlag.misinformation;
      case 'copyright': return ContentFlag.copyright;
      default: return ContentFlag.none;
    }
  }

  MemberRole _parseRole(String? role) {
    switch (role) {
      case 'admin': return MemberRole.admin;
      case 'moderator': return MemberRole.moderator;
      default: return MemberRole.member;
    }
  }
}

// ============================================================================
// QUEUED MESSAGE — For offline queue
// ============================================================================
class QueuedMessage {
  final MessageModel message;
  final String chatId;

  QueuedMessage({required this.message, required this.chatId});
}
