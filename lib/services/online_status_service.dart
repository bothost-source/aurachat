import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStatusService {
  static final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Timer? _heartbeatTimer;

  /// Get current user ID (Firebase OR mock)
  static Future<String?> _getUserId() async {
    final firebaseUser = _auth.currentUser?.uid;
    if (firebaseUser != null) return firebaseUser;

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mock_user_id');
  }

  /// Call when user logs in or app comes to foreground
  static Future<void> setOnline() async {
    final userId = await _getUserId();
    if (userId == null) return;

    try {
      // Set online now
      await _firestore.collection('users').doc(userId).set({
        'is_online': true,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Start heartbeat — update last_seen every 30 seconds
      _startHeartbeat(userId);
    } catch (e) {
      print('setOnline error: $e');
    }
  }

  /// Start heartbeat timer to keep last_seen fresh
  static void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await _firestore.collection('users').doc(userId).update({
          'last_seen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('heartbeat error: $e');
      }
    });
  }

  /// Call when user logs out or app goes to background
  static Future<void> setOffline() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

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

  /// Check if a user is online (last_seen within 2 minutes)
  static bool isUserOnline(Timestamp? lastSeen) {
    if (lastSeen == null) return false;
    final now = DateTime.now();
    final diff = now.difference(lastSeen.toDate());
    return diff.inMinutes < 2;
  }
}
