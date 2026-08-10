import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStatusService {
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user ID (Firebase OR mock)
  static Future<String?> _getUserId() async {
    final firebaseUser = _auth.currentUser?.uid;
    if (firebaseUser != null) return firebaseUser;

    // Check for mock user
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mock_user_id');
  }

  /// Call when user logs in or app comes to foreground
  static Future<void> setOnline() async {
    final userId = await _getUserId();
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('setOnline error: $e');
    }
  }

  /// Call when user logs out or app goes to background
  static Future<void> setOffline() async {
    final userId = await _getUserId();
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('setOffline error: $e');
    }
  }
}
