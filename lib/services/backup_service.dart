import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BackupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _backendUrl = 'https://aurachat-backend-5utu.onrender.com';

  /// Backup user's chats and messages to their email
  /// This exports chat metadata and message text only (not media files)
  static Future<bool> backupToEmail(String userId, String email) async {
    try {
      // 1. Get all chats where user is a participant
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      final List<Map<String, dynamic>> backupData = [];

      for (final chatDoc in chatsSnapshot.docs) {
        final chatData = chatDoc.data();
        final chatId = chatDoc.id;

        // Get messages for this chat (text only, no media URLs)
        final messagesSnapshot = await _firestore
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('created_at')
            .get();

        final messages = messagesSnapshot.docs.map((msg) {
          final msgData = msg.data();
          return {
            'id': msg.id,
            'type': msgData['type'] ?? 'text',
            'content': msgData['content'] ?? '',
            'sender_id': msgData['sender_id'],
            'created_at': msgData['created_at']?.toDate()?.toIso8601String(),
            'is_edited': msgData['is_edited'] ?? false,
            // NOTE: We do NOT include media_url - media stays in Cloudinary
            // User will re-upload when restoring if needed
          };
        }).toList();

        backupData.add({
          'chat_id': chatId,
          'chat_name': chatData['name'] ?? 'Unknown',
          'chat_type': chatData['type'] ?? 'direct',
          'participants': chatData['participants'] ?? [],
          'created_at': chatData['created_at']?.toDate()?.toIso8601String(),
          'messages': messages,
        });
      }

      // 2. Send to backend for email delivery
      final response = await http.post(
        Uri.parse('$_backendUrl/api/backup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'email': email,
          'backup_data': backupData,
          'backup_date': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        // 3. Store backup metadata in Firestore
        await _firestore.collection('backups').doc(userId).set({
          'last_backup': FieldValue.serverTimestamp(),
          'email': email,
          'chat_count': backupData.length,
          'message_count': backupData.fold(0, (sum, chat) => sum + (chat['messages'] as List).length),
        }, SetOptions(merge: true));

        return true;
      }
      return false;
    } catch (e) {
      print('Backup error: $e');
      return false;
    }
  }

  /// Retrieve backup data from email (user forwards the backup email to restore)
  /// This creates new chats with the backed-up messages
  static Future<bool> restoreFromBackup(String userId, Map<String, dynamic> backupData) async {
    try {
      final chats = backupData['chats'] as List<dynamic>? ?? [];

      for (final chat in chats) {
        final chatId = chat['chat_id'] as String;
        final messages = chat['messages'] as List<dynamic>? ?? [];

        // Check if chat already exists
        final existingChat = await _firestore.collection('chats').doc(chatId).get();

        if (!existingChat.exists) {
          // Recreate chat
          await _firestore.collection('chats').doc(chatId).set({
            'name': chat['chat_name'] ?? 'Restored Chat',
            'type': chat['chat_type'] ?? 'direct',
            'participants': chat['participants'] ?? [userId],
            'created_at': FieldValue.serverTimestamp(),
            'is_restored': true,
            'restored_at': FieldValue.serverTimestamp(),
          });
        }

        // Restore messages (text only)
        for (final msg in messages) {
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .add({
            'type': msg['type'] ?? 'text',
            'content': msg['content'] ?? '',
            'sender_id': msg['sender_id'] ?? userId,
            'created_at': msg['created_at'] != null 
                ? Timestamp.fromDate(DateTime.parse(msg['created_at']))
                : FieldValue.serverTimestamp(),
            'is_restored': true,
            'original_id': msg['id'],
            // No media_url - user must re-upload media
          });
        }
      }

      // Update restore metadata
      await _firestore.collection('backups').doc(userId).update({
        'last_restore': FieldValue.serverTimestamp(),
        'restored_chat_count': chats.length,
      });

      return true;
    } catch (e) {
      print('Restore error: $e');
      return false;
    }
  }

  /// Get last backup info
  static Future<Map<String, dynamic>?> getLastBackupInfo(String userId) async {
    try {
      final doc = await _firestore.collection('backups').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      return null;
    }
  }
}
