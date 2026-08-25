import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import '../../services/cloudinary_service.dart';

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
        'view_count': 0,
        'likes': [],
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
        'view_count': 0,
        'likes': [],
      });
      return true;
    } catch (e) {
      print('Create media status error: $e');
      return false;
    }
  }

  // Get statuses from saved contacts + user's own status
  static Future<List<Map<String, dynamic>>> getContactStatuses(String userId) async {
    try {
      final contactsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .get();

      final contactIds = contactsSnapshot.docs.map((d) => d.id).toList();
      final allUserIds = [...contactIds, userId];

      if (allUserIds.isEmpty) return [];

      final statuses = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = 0; i < allUserIds.length; i += 10) {
        final batch = allUserIds.sublist(
          i,
          i + 10 > allUserIds.length ? allUserIds.length : i + 10,
        );

        final snapshot = await _firestore
            .collection('statuses')
            .where('user_id', whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
          
          if (expiresAt == null || expiresAt.isBefore(now)) continue;

          final statusUserId = data['user_id'] as String;
          final userDoc = await _firestore.collection('users').doc(statusUserId).get();
          final userData = userDoc.data();

          final viewsSnapshot = await _firestore
              .collection('statuses')
              .doc(doc.id)
              .collection('views')
              .get();

          statuses.add({
            'id': doc.id,
            ...data,
            'view_count': viewsSnapshot.docs.length,
            'likes': data['likes'] ?? [],
            'is_mine': statusUserId == userId,
            'users': {
              'username': userData?['username'] ?? 'Unknown',
              'avatar_url': userData?['avatar_url'],
            },
          });
        }
      }

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
      final viewRef = _firestore
          .collection('statuses')
          .doc(statusId)
          .collection('views')
          .doc(userId);

      final doc = await viewRef.get();
      if (!doc.exists) {
        await viewRef.set({
          'viewed_at': Timestamp.now(),
        });
        
        await _firestore.collection('statuses').doc(statusId).update({
          'view_count': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Mark as viewed error: $e');
    }
  }

  // Toggle like on a status
  static Future<void> toggleLike(String statusId, String userId) async {
    try {
      final docRef = _firestore.collection('statuses').doc(statusId);
      final doc = await docRef.get();
      
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final likes = List<String>.from(data['likes'] ?? []);
      
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      
      await docRef.update({'likes': likes});
    } catch (e) {
      print('Toggle like error: $e');
    }
  }

  // Get views list with user details
  static Future<List<Map<String, dynamic>>> getViews(String statusId) async {
    try {
      final viewsSnapshot = await _firestore
          .collection('statuses')
          .doc(statusId)
          .collection('views')
          .orderBy('viewed_at', descending: true)
          .get();

      final views = <Map<String, dynamic>>[];
      
      for (final viewDoc in viewsSnapshot.docs) {
        final userId = viewDoc.id;
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        views.add({
          'user_id': userId,
          'username': userData?['username'] ?? 'Unknown',
          'avatar_url': userData?['avatar_url'],
          'viewed_at': viewDoc.data()['viewed_at'],
        });
      }
      
      return views;
    } catch (e) {
      print('Get views error: $e');
      return [];
    }
  }

  // Reply to a status
  static Future<bool> replyToStatus(String statusId, String userId, String text) async {
    try {
      final statusDoc = await _firestore.collection('statuses').doc(statusId).get();
      if (!statusDoc.exists) return false;
      
      final statusData = statusDoc.data()!;
      final recipientId = statusData['user_id'] as String;
      
      await _firestore.collection('messages').add({
        'sender_id': userId,
        'recipient_id': recipientId,
        'text': text,
        'status_reply_to': statusId,
        'created_at': Timestamp.now(),
        'read': false,
      });
      
      return true;
    } catch (e) {
      print('Reply to status error: $e');
      return false;
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

  // Get active statuses (not expired)
  static Future<List<Map<String, dynamic>>> getActiveStatuses() async {
    try {
      final now = Timestamp.now();
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
        
        final viewsSnapshot = await _firestore
            .collection('statuses')
            .doc(doc.id)
            .collection('views')
            .get();

        statuses.add({
          'id': doc.id,
          ...data,
          'view_count': viewsSnapshot.docs.length,
          'likes': data['likes'] ?? [],
          'users': {
            'username': userData?['username'],
            'avatar_url': userData?['avatar_url'],
          },
        });
      }

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

  // Get my statuses
  static Future<List<Map<String, dynamic>>> getMyStatuses(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('statuses')
          .where('user_id', isEqualTo: userId)
          .get();

      final now = DateTime.now();
      final statuses = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expires_at'] as Timestamp?)?.toDate();
        if (expiresAt == null || expiresAt.isBefore(now)) continue;

        final viewsSnapshot = await _firestore
            .collection('statuses')
            .doc(doc.id)
            .collection('views')
            .get();

        statuses.add({
          'id': doc.id,
          ...data,
          'view_count': viewsSnapshot.docs.length,
          'likes': data['likes'] ?? [],
        });
      }

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

  // ═══════════════════════════════════════════════════════════════════════════
  // FIXED: Delete expired statuses + delete media from Cloudinary
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> deleteExpiredStatuses() async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('statuses')
          .where('expires_at', isLessThan: now)
          .get();

      int deletedCount = 0;
      int cloudinaryDeleted = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Delete from Cloudinary
        final publicId = data['cloudinary_public_id'] as String?;
        final mediaUrl = data['media_url'] as String?;
        
        bool cloudinarySuccess = false;
        
        if (publicId != null && publicId.isNotEmpty) {
          cloudinarySuccess = await CloudinaryService.deleteByPublicId(publicId);
        } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
          cloudinarySuccess = await CloudinaryService.deleteFile(mediaUrl);
        }
        
        if (cloudinarySuccess) {
          cloudinaryDeleted++;
        }

        // Delete the Firestore document
        await doc.reference.delete();
        deletedCount++;
      }
      
      print('Deleted $deletedCount expired statuses');
      print('Deleted $cloudinaryDeleted media files from Cloudinary');
    } catch (e) {
      print('Delete expired error: $e');
    }
  }
}
