import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _chatsSubscription;

  List<Map<String, dynamic>> get chats => _chats;
  List<Map<String, dynamic>> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChatProvider() {
    loadChats();
    _subscribeToChats();
  }

  Future<void> loadChats() async {
    _setLoading(true);
    _error = null;

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _setLoading(false);
        return;
      }

      final snapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('last_message_at', descending: true)
          .get();

      final List<Map<String, dynamic>> formattedChats = [];

      for (final doc in snapshot.docs) {
        final chat = doc.data();
        final chatId = doc.id;

        final unreadSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('is_read', isEqualTo: false)
            .where('sender_id', isNotEqualTo: userId)
            .get();

        final unreadCount = unreadSnapshot.docs.length;

        int participantsCount = 0;
        if (chat['type'] == 'group' || chat['type'] == 'channel') {
          participantsCount = (chat['participants'] as List<dynamic>?)?.length ?? 0;
        }

        formattedChats.add({
          ...chat,
          'id': chatId,
          'role': (chat['participants_data'] as Map<String, dynamic>?)?[userId]?['role'] ?? 'member',
          'unread_count': unreadCount,
          'participants_count': participantsCount,
        });
      }

      _chats = formattedChats;
      _setLoading(false);
    } catch (e) {
      _error = 'Failed to load chats: $e';
      _setLoading(false);
    }
  }

  void _subscribeToChats() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snapshot) {
          loadChats();
        });
  }

  Future<void> loadContacts() async {
    _setLoading(true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _setLoading(false);
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .where('id', isNotEqualTo: userId)
          .orderBy('id')
          .orderBy('username')
          .get();

      _contacts = snapshot.docs.map((doc) => doc.data()).toList();
      _setLoading(false);
    } catch (e) {
      _error = 'Failed to load contacts: $e';
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> startDirectChat(String otherUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final chatId = const Uuid().v4();

      await _firestore.collection('chats').doc(chatId).set({
        'id': chatId,
        'type': 'direct',
        'participants': [userId, otherUserId],
        'participants_data': {
          userId: {'role': 'member', 'joined_at': FieldValue.serverTimestamp()},
          otherUserId: {'role': 'member', 'joined_at': FieldValue.serverTimestamp()},
        },
        'created_at': FieldValue.serverTimestamp(),
        'last_message_at': FieldValue.serverTimestamp(),
      });

      await loadChats();

      return _chats.firstWhere(
        (chat) => chat['id'] == chatId,
        orElse: () => {'id': chatId},
      );
    } catch (e) {
      _error = 'Failed to start chat: $e';
      return null;
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final unreadSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('is_read', isEqualTo: false)
          .where('sender_id', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadSnapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();

      final index = _chats.indexWhere((chat) => chat['id'] == chatId);
      if (index >= 0) {
        _chats[index]['unread_count'] = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
            'participants': FieldValue.arrayRemove([userId]),
            'participants_data.$userId': FieldValue.delete(),
          });

      await loadChats();
    } catch (e) {
      _error = 'Failed to delete chat: $e';
    }
  }

  Future<void> archiveChat(String chatId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
            'participants_data.$userId.is_archived': true,
          });

      await loadChats();
    } catch (e) {
      _error = 'Failed to archive chat: $e';
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({
            'participants_data.$userId.is_archived': false,
          });

      await loadChats();
    } catch (e) {
      _error = 'Failed to unarchive chat: $e';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }
}
