import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class StatusService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload image/video status media
  static Future<String?> uploadStatusMedia(File file, String userId, String type) async {
    try {
      final ext = path.extension(file.path);
      final fileName = 'statuses/$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
      
      final ref = _storage.ref().child(fileName);
      final metadata = SettableMetadata(
        contentType: type == 'video' ? 'video/mp4' : 'image/jpeg',
      );
      
      await ref.putFile(file, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Create text status
  static Future<bool> createTextStatus(String userId, String caption) async {
    try {
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      
      await _firestore.collection('statuses').add({
        'user_id': userId,
        'caption': caption,
        'type': 'text',
        'created_at': Timestamp.now(),
        'expires_at': Timestamp.fromDate(expiresAt),
        'viewed_by': [],
      });
      return true;
    } catch (e) {
      print('Create text status error: $e');
      return false;
    }
  }

  // Create media status
  static Future<bool> createMediaStatus(String userId, String mediaUrl, String type, {String caption = ''}) async {
    try {
      final expiresAt = DateTime.now().add(const Duration(hours: 24));
      
      await _firestore.collection('statuses').add({
        'user_id': userId,
        'media_url': mediaUrl,
        'caption': caption,
        'type': type,
        'created_at': Timestamp.now(),
        'expires_at': Timestamp.fromDate(expiresAt),
        'viewed_by': [],
      });
      return true;
    } catch (e) {
      print('Create media status error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED: Get statuses from saved contacts + user's own status
  // Uses simple query + client-side filtering to avoid composite index issues
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getContactStatuses(String userId) async {
    try {
      // Get saved contacts for this user
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      final contactIds = contactsSnapshot.docs.map((d) => d.id).toList();
      // Always include userId so YOUR status shows even with no contacts
      final allUserIds = [...contactIds, userId];

      if (allUserIds.isEmpty) return [];

      final statuses = <Map<String, dynamic>>[];
      final now = DateTime.now();

      // Fetch in batches of 10 (Firestore whereIn limit)
      for (int i = 0; i < allUserIds.length; i += 10) {
        final batch = allUserIds.sublist(
          i,
          i + 10 > allUserIds.length ? allUserIds.length : i + 10,
        );

        // FIXED: Simple query without orderBy to avoid composite index requirement
        // We sort client-side instead
        final snapshot = await _firestore
            .collection('statuses')
            .where('user_id', whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
          
          // Client-side expiry check
          if (expiresAt == null || expiresAt.isBefore(now)) continue;

          final statusUserId = data['user_id'] as String;

          // Get user info
          final userDoc = await _firestore.collection('users').doc(statusUserId).get();
          final userData = userDoc.data();

          statuses.add({
            'id': doc.id,
            ...data,
            'is_mine': statusUserId == userId,
            'users': {
              'username': userData?['username'] ?? 'Unknown',
              'avatar_url': userData?['avatar_url'],
            },
          });
        }
      }

      // Sort by created_at descending so newest appears first
      statuses.sort((a, b) {
        final aTime = (a['created_at'] as Timestamp).toDate();
        final bTime = (b['created_at'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      return statuses;
    } catch (e) {
      print('Get contact statuses error: $e');
      return [];
    }
  }

  // Mark a status as viewed by current user
  static Future<void> markAsViewed(String statusId, String userId) async {
    try {
      await _firestore
          .collection('statuses')
          .doc(statusId)
          .collection('views')
          .doc(userId)
          .set({
        'viewed_at': Timestamp.now(),
      });
    } catch (e) {
      print('Mark as viewed error: $e');
    }
  }

  // Check if a user is in current user's contacts
  static Future<bool> isContact(String currentUserId, String contactUserId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('contacts')
          .doc(contactUserId)
          .get();
      return doc.exists;
    } catch (e) {
      print('Is contact error: $e');
      return false;
    }
  }

  // Save a contact to current user's contacts list
  static Future<bool> saveContact(String currentUserId, String contactUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('contacts')
          .doc(contactUserId)
          .set({
        'saved_at': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Save contact error: $e');
      return false;
    }
  }

  // Get active statuses (not expired) — all users
  static Future<List<Map<String, dynamic>>> getActiveStatuses() async {
    try {
      final now = Timestamp.now();
      // FIXED: Simple query, client-side filter for user data
      final snapshot = await _firestore
          .collection('statuses')
          .where('expires_at', isGreaterThan: now)
          .get();

      final statuses = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String;
        
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        statuses.add({
          'id': doc.id,
          ...data,
          'users': {
            'username': userData?['username'],
            'avatar_url': userData?['avatar_url'],
          },
        });
      }

      // Sort client-side
      statuses.sort((a, b) {
        final aTime = (a['created_at'] as Timestamp).toDate();
        final bTime = (b['created_at'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      return statuses;
    } catch (e) {
      print('Get statuses error: $e');
      return [];
    }
  }

  // Get my statuses — works for both Firebase and mock users
  // FIXED: Simple query without composite index
  static Future<List<Map<String, dynamic>>> getMyStatuses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('statuses')
          .where('user_id', isEqualTo: userId)
          .get();

      final now = DateTime.now();
      final statuses = snapshot.docs
          .map((doc) => {
            'id': doc.id,
            ...doc.data(),
          })
          .where((s) {
            final expiresAt = (s['expires_at'] as Timestamp?)?.toDate();
            return expiresAt != null && expiresAt.isAfter(now);
          })
          .toList();

      // Sort client-side
      statuses.sort((a, b) {
        final aTime = (a['created_at'] as Timestamp).toDate();
        final bTime = (b['created_at'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      return statuses;
    } catch (e) {
      print('Get my statuses error: $e');
      return [];
    }
  }

  // Delete expired statuses (call periodically)
  static Future<void> deleteExpiredStatuses() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('statuses')
          .where('expires_at', isLessThan: now)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['media_url'] != null) {
          try {
            final mediaUrl = data['media_url'] as String;
            final ref = _storage.refFromURL(mediaUrl);
            await ref.delete();
          } catch (e) {
            print('Delete media error: $e');
          }
        }
        await doc.reference.delete();
      }
    } catch (e) {
      print('Delete expired error: $e');
    }
  }
}
