import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ChatProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _contacts = [];
  List<String> _blockedUsers = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _chatsSubscription;
  String? _currentUserId;

  List<Map<String, dynamic>> get chats => _chats;
  List<Map<String, dynamic>> get contacts => _contacts;
  List<String> get blockedUsers => _blockedUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChatProvider() {
    _init();
  }

  Future<void> _init() async {
    _currentUserId = _auth.currentUser?.uid;
    if (_currentUserId != null) {
      await _loadBlockedUsers();
      await loadChats();
      _subscribeToChats();
    }
  }

  Future<void> setMockUser(String mockUserId) async {
    _currentUserId = mockUserId;
    await _loadBlockedUsers();
    await loadChats();
    _subscribeToChats();
    notifyListeners();
  }

  String? get currentUserId => _currentUserId;

  Future<void> _loadBlockedUsers() async {
    try {
      final doc = await _firestore.collection('users').doc(_currentUserId).get();
      if (doc.exists) {
        final data = doc.data()!;
        _blockedUsers = List<String>.from(data['blocked_users'] ?? []);
      }
    } catch (e) {
      debugPrint('Load blocked users error: $e');
    }
  }

  bool isBlocked(String userId) => _blockedUsers.contains(userId);

  Future<void> blockUser(String userId) async {
    if (_currentUserId == null) return;
    try {
      await _firestore.collection('users').doc(_currentUserId).set({
        'blocked_users': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
      _blockedUsers.add(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to block user: $e';
      notifyListeners();
    }
  }

  Future<void> unblockUser(String userId) async {
    if (_currentUserId == null) return;
    try {
      await _firestore.collection('users').doc(_currentUserId).set({
        'blocked_users': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));
      _blockedUsers.remove(userId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to unblock user: $e';
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOAD ALL CHATS: private + groups + channels (all from 'chats' collection)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> loadChats() async {
    _setLoading(true);
    _error = null;

    try {
      final userId = _currentUserId;
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
        final chatType = chat['type'] as String? ?? 'direct';

        // Skip blocked DMs
        if (chatType == 'direct') {
          final participants = List<String>.from(chat['participants'] ?? []);
          final otherUserId = participants.firstWhere(
            (id) => id != userId,
            orElse: () => '',
          );
          if (otherUserId.isNotEmpty && _blockedUsers.contains(otherUserId)) {
            continue;
          }
        }

        // Skip archived
        final participantsData = chat['participants_data'] as Map<String, dynamic>? ?? {};
        final myData = participantsData[userId] as Map<String, dynamic>? ?? {};
        if (myData['is_archived'] == true) continue;

        // Get unread count
        final unreadCount = await _getUnreadCount(chatId, userId);

        // Get member count
        int participantsCount = 0;
        if (chatType == 'group' || chatType == 'channel') {
          participantsCount = (chat['participants'] as List<dynamic>?)?.length ?? 0;
        }

        // Get role
        final role = myData['role'] ?? 'member';

        formattedChats.add({
          ...chat,
          'id': chatId,
          'role': role,
          'unread_count': unreadCount,
          'participants_count': participantsCount,
        });
      }

      _chats = formattedChats;
      _setLoading(false);
    } catch (e) {
      _error = 'Failed to load chats: $e';
      debugPrint('loadChats error: $e');
      _setLoading(false);
    }
  }

  Future<int> _getUnreadCount(String chatId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('is_read', isEqualTo: false)
          .where('sender_id', isNotEqualTo: userId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  void _subscribeToChats() {
    final userId = _currentUserId;
    if (userId == null) return;

    _chatsSubscription?.cancel();
    _chatsSubscription = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((_) => loadChats());
  }

  Future<void> loadContacts() async {
    _setLoading(true);

    try {
      final userId = _currentUserId;
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
      final userId = _currentUserId;
      if (userId == null) return null;

      if (_blockedUsers.contains(otherUserId)) {
        _error = 'You have blocked this user';
        notifyListeners();
        return null;
      }

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
      final userId = _currentUserId;
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
      final userId = _currentUserId;
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
      final userId = _currentUserId;
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
      final userId = _currentUserId;
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

  Future<void> leaveChat(String chatId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final isOwner = chatData['created_by'] == userId;

      if (isOwner) {
        _error = 'Owner cannot leave. Transfer ownership or delete the group.';
        notifyListeners();
        return;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'participants_data.$userId': FieldValue.delete(),
        'member_count': FieldValue.increment(-1),
      });

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'type': 'system',
        'content': 'A member left',
        'created_at': FieldValue.serverTimestamp(),
      });

      await loadChats();
    } catch (e) {
      _error = 'Failed to leave chat: $e';
      notifyListeners();
    }
  }

  Future<void> kickMember(String chatId, String memberId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final myRole = (chatData['participants_data']?[userId]?['role'] ?? 'member') as String;

      if (myRole != 'owner' && myRole != 'admin') {
        _error = 'Only owners and admins can kick members';
        notifyListeners();
        return;
      }

      final memberRole = (chatData['participants_data']?[memberId]?['role'] ?? 'member') as String;
      if (memberRole == 'owner') {
        _error = 'Cannot kick the owner';
        notifyListeners();
        return;
      }
      if (myRole == 'admin' && memberRole == 'admin') {
        _error = 'Admins cannot kick other admins';
        notifyListeners();
        return;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayRemove([memberId]),
        'participants_data.$memberId': FieldValue.delete(),
        'member_count': FieldValue.increment(-1),
      });

      final userDoc = await _firestore.collection('users').doc(memberId).get();
      final userName = userDoc.data()?['username'] ?? 'A member';
      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'type': 'system',
        'content': '$userName was removed',
        'created_at': FieldValue.serverTimestamp(),
      });

      await loadChats();
    } catch (e) {
      _error = 'Failed to kick member: $e';
      notifyListeners();
    }
  }

  Future<void> banMember(String chatId, String memberId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final myRole = (chatData['participants_data']?[userId]?['role'] ?? 'member') as String;

      if (myRole != 'owner' && myRole != 'admin') {
        _error = 'Only owners and admins can ban members';
        notifyListeners();
        return;
      }

      final memberRole = (chatData['participants_data']?[memberId]?['role'] ?? 'member') as String;
      if (memberRole == 'owner') {
        _error = 'Cannot ban the owner';
        notifyListeners();
        return;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'participants': FieldValue.arrayRemove([memberId]),
        'participants_data.$memberId': FieldValue.delete(),
        'banned_users': FieldValue.arrayUnion([memberId]),
        'member_count': FieldValue.increment(-1),
      });

      final userDoc = await _firestore.collection('users').doc(memberId).get();
      final userName = userDoc.data()?['username'] ?? 'A member';
      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'type': 'system',
        'content': '$userName was banned',
        'created_at': FieldValue.serverTimestamp(),
      });

      await loadChats();
    } catch (e) {
      _error = 'Failed to ban member: $e';
      notifyListeners();
    }
  }

  Future<void> promoteToAdmin(String chatId, String memberId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final myRole = (chatData['participants_data']?[userId]?['role'] ?? 'member') as String;

      if (myRole != 'owner') {
        _error = 'Only the owner can promote members';
        notifyListeners();
        return;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'participants_data.$memberId.role': 'admin',
      });

      final userDoc = await _firestore.collection('users').doc(memberId).get();
      final userName = userDoc.data()?['username'] ?? 'A member';
      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'type': 'system',
        'content': '$userName was promoted to admin',
        'created_at': FieldValue.serverTimestamp(),
      });

      await loadChats();
    } catch (e) {
      _error = 'Failed to promote member: $e';
      notifyListeners();
    }
  }

  Future<void> toggleSetting(String chatId, String settingKey, bool value) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final myRole = (chatData['participants_data']?[userId]?['role'] ?? 'member') as String;

      if (myRole != 'owner' && myRole != 'admin') {
        _error = 'Only owners and admins can change settings';
        notifyListeners();
        return;
      }

      await _firestore.collection('chats').doc(chatId).update({
        'settings.$settingKey': value,
      });

      await loadChats();
    } catch (e) {
      _error = 'Failed to update setting: $e';
      notifyListeners();
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
