import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;

class StatusService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Upload image/video status
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
      });
      return true;
    } catch (e) {
      print('Create media status error: $e');
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
          .orderBy('expires_at', descending: true)
          .get();

      final statuses = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['user_id'] as String;
        
        // Get user info
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

      return statuses;
    } catch (e) {
      print('Get statuses error: $e');
      return [];
    }
  }

  // Get my statuses
  static Future<List<Map<String, dynamic>>> getMyStatuses(String userId) async {
    try {
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('statuses')
          .where('user_id', isEqualTo: userId)
          .where('expires_at', isGreaterThan: now)
          .orderBy('expires_at', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
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
        // Delete associated media if exists
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
