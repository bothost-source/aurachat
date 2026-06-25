import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineStatusService {
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Call when user logs in or app comes to foreground
  static Future<void> setOnline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('setOnline error: $e');
    }
  }

  /// Call when user logs out or app goes to background
  static Future<void> setOffline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('setOffline error: $e');
    }
  }
}
