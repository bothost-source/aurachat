import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class FirebaseChatService {
  static final FirebaseChatService _instance = FirebaseChatService._internal();
  factory FirebaseChatService() => _instance;
  FirebaseChatService._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;

  void initialize() {
    _currentUserId = _auth.currentUser?.uid;
  }

  String? get currentUserId => _currentUserId;

  // ==========================================================================
  // STREAMS (Real-time)
  // ==========================================================================

  Stream<List<ChatModel>> getUserChats() {
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('last_message_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromJson(doc.data()))
            .toList());
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromJson(doc.data()))
            .toList());
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('typing')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data()['user_id'] as String)
            .toList());
  }

  // ==========================================================================
  // MESSAGES
  // ==========================================================================

  Future<void> sendMessage({
    required String chatId,
    required String content,
    required MessageType type,
  }) async {
    if (_currentUserId == null) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'chat_id': chatId,
      'sender_id': _currentUserId,
      'content': content,
      'type': type.name,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Update chat last message
    await _firestore.collection('chats').doc(chatId).update({
      'last_message': content,
      'last_message_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String chatId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'unread_count': 0,
    });
  }

  // ==========================================================================
  // TYPING STATUS
  // ==========================================================================

  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    final userId = _currentUserId;
    if (userId == null) return;

    if (isTyping) {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(userId)
          .set({
        'chat_id': chatId,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('typing')
          .doc(userId)
          .delete();
    }
  }

  // ==========================================================================
  // CHAT CREATION
  // ==========================================================================

  Future<String> createDirectChat(String otherUserId) async {
    final currentUser = _currentUserId;
    if (currentUser == null) throw Exception('User not authenticated');

    final chatRef = _firestore.collection('chats').doc();
    final chatId = chatRef.id;

    await chatRef.set({
      'id': chatId,
      'name': 'Chat',
      'type': 'private',
      'participants': [currentUser, otherUserId],
      'participants_data': {
        currentUser: {'role': 'member', 'joined_at': FieldValue.serverTimestamp()},
        otherUserId: {'role': 'member', 'joined_at': FieldValue.serverTimestamp()},
      },
      'created_at': FieldValue.serverTimestamp(),
      'last_message_at': FieldValue.serverTimestamp(),
    });

    return chatId;
  }

  Future<void> createGroupChat({
    required String name,
    String? description,
    required List<String> memberIds,
    bool isPublic = true,
  }) async {
    final currentUser = _currentUserId;
    if (currentUser == null) return;

    final participants = [currentUser, ...memberIds];
    final participantsData = <String, dynamic>{};

    for (final id in participants) {
      participantsData[id] = {
        'role': id == currentUser ? 'admin' : 'member',
        'joined_at': FieldValue.serverTimestamp(),
      };
    }

    await _firestore.collection('chats').add({
      'name': name,
      'type': 'group',
      'description': description,
      'participants': participants,
      'participants_data': participantsData,
      'is_public': isPublic,
      'created_at': FieldValue.serverTimestamp(),
      'last_message_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    final currentUser = _currentUserId;
    if (currentUser == null) return;

    await _firestore.collection('chats').add({
      'name': name,
      'type': 'channel',
      'description': description,
      'participants': [currentUser],
      'participants_data': {
        currentUser: {'role': 'admin', 'joined_at': FieldValue.serverTimestamp()},
      },
      'is_public': isPublic,
      'created_at': FieldValue.serverTimestamp(),
      'last_message_at': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final snapshot = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  void dispose() {}
}
