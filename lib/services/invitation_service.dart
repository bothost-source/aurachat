import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for generating and managing invitation links
class InvitationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  static final Random _random = Random();

  // FIXED: Use Firebase Hosting URL instead of deprecated Dynamic Links
  static const String _baseUrl = 'https://aurachat-85f54.web.app';

  /// Generate a custom invitation link for a group or channel
  static Future<Map<String, dynamic>> createInvitation({
    required String chatId,
    required String chatName,
    required String chatType, // 'group' or 'channel'
    required String createdBy,
    String? customName, // User-defined name for the link
  }) async {
    // Sanitize custom name or generate random
    String code;
    if (customName != null && customName.trim().isNotEmpty) {
      code = customName.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    } else {
      code = _generateRandomCode(8);
    }

    // Check if code already exists
    final existing = await _firestore
        .collection('invitations')
        .where('code', isEqualTo: code)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('This invitation name is already taken. Please choose another.');
    }

    final invitationId = _firestore.collection('invitations').doc().id;
    // FIXED: Use Firebase Hosting URL with /join path
    final link = '$_baseUrl/join/$code';

    await _firestore.collection('invitations').doc(invitationId).set({
      'id': invitationId,
      'chat_id': chatId,
      'chat_name': chatName,
      'chat_type': chatType,
      'code': code,
      'link': link,
      'created_by': createdBy,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': null, // No expiry by default
      'max_uses': null, // Unlimited by default
      'used_count': 0,
      'is_active': true,
    });

    // Also store in chat document for easy access
    await _firestore.collection('chats').doc(chatId).update({
      'invitation': {
        'code': code,
        'link': link,
        'enabled': true,
      },
    });

    return {
      'invitation_id': invitationId,
      'code': code,
      'link': link,
    };
  }

  /// Generate random code
  static String _generateRandomCode(int length) {
    return List.generate(length, (_) => _chars[_random.nextInt(_chars.length)]).join();
  }

  /// Validate and process an invitation
  static Future<Map<String, dynamic>> processInvitation({
    required String code,
    required String userId,
    required String userName,
  }) async {
    final invitationQuery = await _firestore
        .collection('invitations')
        .where('code', isEqualTo: code)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (invitationQuery.docs.isEmpty) {
      return {'success': false, 'message': 'Invalid or expired invitation link.'};
    }

    final invitation = invitationQuery.docs.first;
    final data = invitation.data();

    // Check if already a member
    final chatDoc = await _firestore.collection('chats').doc(data['chat_id']).get();
    if (!chatDoc.exists) {
      return {'success': false, 'message': 'This group or channel no longer exists.'};
    }

    final chatData = chatDoc.data()!;
    final participants = List<String>.from(chatData['participants'] ?? []);

    if (participants.contains(userId)) {
      return {
        'success': true,
        'already_member': true,
        'chat_id': data['chat_id'],
        'chat_name': data['chat_name'],
        'chat_type': data['chat_type'],
      };
    }

    // Check max uses
    final maxUses = data['max_uses'] as int?;
    final usedCount = data['used_count'] as int? ?? 0;
    if (maxUses != null && usedCount >= maxUses) {
      return {'success': false, 'message': 'This invitation has reached its maximum uses.'};
    }

    // Check expiry
    final expiresAt = data['expires_at'] as Timestamp?;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
      return {'success': false, 'message': 'This invitation has expired.'};
    }

    // Check banned users
    final bannedUsers = List<String>.from(chatData['banned_users'] ?? []);
    if (bannedUsers.contains(userId)) {
      return {'success': false, 'message': 'You have been banned from this group or channel.'};
    }

    // Return preview info for confirmation dialog
    return {
      'success': true,
      'already_member': false,
      'chat_id': data['chat_id'],
      'chat_name': data['chat_name'],
      'chat_type': data['chat_type'],
      'invitation_id': invitation.id,
      'requires_confirmation': true,
    };
  }

  /// Join user to group/channel after confirmation
  static Future<Map<String, dynamic>> joinWithInvitation({
    required String invitationId,
    required String userId,
    required String userName,
  }) async {
    final invitation = await _firestore.collection('invitations').doc(invitationId).get();
    if (!invitation.exists) {
      return {'success': false, 'message': 'Invitation not found.'};
    }

    final data = invitation.data()!;
    final chatId = data['chat_id'] as String;

    // Fetch chat data for welcome message
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    final chatData = chatDoc.data() ?? {};

    // Add user to chat
    await _firestore.collection('chats').doc(chatId).update({
      'participants': FieldValue.arrayUnion([userId]),
      'participants_data.$userId': {
        'role': 'member',
        'joined_at': FieldValue.serverTimestamp(),
        'joined_via': 'invitation',
        'invitation_id': invitationId,
      },
      'member_count': FieldValue.increment(1),
    });

    // Update invitation usage
    await _firestore.collection('invitations').doc(invitationId).update({
      'used_count': FieldValue.increment(1),
      'used_by': FieldValue.arrayUnion([{
        'user_id': userId,
        'user_name': userName,
        'joined_at': FieldValue.serverTimestamp(),
      }]),
    });

    // Send welcome message
    final welcomeMessage = chatData['settings']?['welcome_message'] ?? 'Welcome to the group!';
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'type': 'system',
      'content': '$userName joined via invitation link',
      'created_at': FieldValue.serverTimestamp(),
      'is_read': false,
    });

    return {
      'success': true,
      'chat_id': chatId,
      'chat_name': data['chat_name'],
      'chat_type': data['chat_type'],
    };
  }

  /// Revoke an invitation
  static Future<void> revokeInvitation(String invitationId) async {
    final doc = await _firestore.collection('invitations').doc(invitationId).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final chatId = data['chat_id'] as String;

    await _firestore.collection('invitations').doc(invitationId).update({
      'is_active': false,
      'revoked_at': FieldValue.serverTimestamp(),
    });

    // Update chat
    await _firestore.collection('chats').doc(chatId).update({
      'invitation.enabled': false,
    });
  }

  /// Get invitation preview (for share sheet)
  static Future<Map<String, dynamic>?> getInvitationPreview(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return null;

    final data = chatDoc.data()!;
    final invitation = data['invitation'] as Map<String, dynamic>?;
    if (invitation == null || invitation['enabled'] != true) return null;

    return {
      'chat_name': data['name'],
      'chat_type': data['type'],
      'member_count': data['member_count'] ?? 0,
      'code': invitation['code'],
      'link': invitation['link'],
    };
  }

  /// Get rich preview data for a chat (NEW - for Telegram-style link preview)
  static Future<Map<String, dynamic>> getChatPreviewData(String chatId) async {
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return {};

    final data = chatDoc.data()!;
    final participants = List<String>.from(data['participants'] ?? []);

    return {
      'name': data['name'] ?? 'Unknown',
      'description': data['description'] ?? '',
      'avatar_url': data['avatar_url'],
      'member_count': participants.length,
      'type': data['type'] ?? 'group',
    };
  }

  /// Regenerate an invitation link (invalidates old, creates new)
  static Future<String?> regenerateLink(String chatId, String createdBy) async {
    // Get current chat data
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return null;

    final chatData = chatDoc.data()!;
    final oldInvitation = chatData['invitation'] as Map<String, dynamic>?;
    final chatName = chatData['name'] ?? 'Unknown';
    final chatType = chatData['type'] ?? 'channel';

    // Revoke old invitation if exists
    if (oldInvitation != null) {
      final oldCode = oldInvitation['code'] as String?;
      if (oldCode != null) {
        final oldQuery = await _firestore
            .collection('invitations')
            .where('code', isEqualTo: oldCode)
            .limit(1)
            .get();
        if (oldQuery.docs.isNotEmpty) {
          await _firestore.collection('invitations').doc(oldQuery.docs.first.id).update({
            'is_active': false,
            'revoked_at': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    // Create new invitation
    final newCode = _generateRandomCode(8);
    // FIXED: Use Firebase Hosting URL
    final newLink = '$_baseUrl/join/$newCode';
    final invitationId = _firestore.collection('invitations').doc().id;

    await _firestore.collection('invitations').doc(invitationId).set({
      'id': invitationId,
      'chat_id': chatId,
      'chat_name': chatName,
      'chat_type': chatType,
      'code': newCode,
      'link': newLink,
      'created_by': createdBy,
      'created_at': FieldValue.serverTimestamp(),
      'expires_at': null,
      'max_uses': null,
      'used_count': 0,
      'is_active': true,
    });

    await _firestore.collection('chats').doc(chatId).update({
      'invitation': {
        'code': newCode,
        'link': newLink,
        'enabled': true,
      },
    });

    return newLink;
  }
}
