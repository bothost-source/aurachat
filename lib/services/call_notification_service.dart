import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_signaling_service.dart';

/// ============================================================================
/// CALL NOTIFICATION SERVICE — Handles incoming call FCM + full-screen UI
/// ============================================================================
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _initialized = false;
  Function(CallSignal)? onIncomingCall;

  Future<void> initialize({
    Function(CallSignal)? onIncomingCallCallback,
  }) async {
    if (_initialized) return;
    onIncomingCall = onIncomingCallCallback;

    // Create high-priority call notification channel
    const androidChannel = AndroidNotificationChannel(
      'aura_call_channel',
      'AURA Calls',
      description: 'Incoming voice and video calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('ringtone'), // Add ringtone.mp3 to android/app/src/main/res/raw/
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    debugPrint('CallNotificationService initialized');
  }

  /// Send FCM call notification to target user
  static Future<bool> sendCallFCM({
    required String targetUserId,
    required String callId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String channelName,
    required bool isVideoCall,
  }) async {
    try {
      // Get target user's FCM token
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetUserId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('No FCM token for user $targetUserId');
        return false;
      }

      // We need to send FCM via HTTP v1 API or Cloud Function
      // For now, we'll also write to Realtime DB as fallback
      // The Cloud Function should trigger on DB write and send FCM
      // OR we can send directly if we have server key (not recommended for client)
      
      // Write call signal to Realtime DB (existing behavior)
      await CallSignalingService.sendCallInvitation(
        targetUserId: targetUserId,
        callId: callId,
        callerId: callerId,
        callerName: callerName,
        callerAvatar: callerAvatar,
        channelName: channelName,
        isVideoCall: isVideoCall,
      );

      debugPrint('Call invitation sent to $targetUserId');
      return true;
    } catch (e) {
      debugPrint('Error sending call FCM: $e');
      return false;
    }
  }

  /// Show local incoming call notification (for foreground/background)
  Future<void> showIncomingCallNotification(CallSignal signal) async {
    final androidDetails = AndroidNotificationDetails(
      'aura_call_channel',
      'AURA Calls',
      channelDescription: 'Incoming voice and video calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      actions: [
        const AndroidNotificationAction(
          'decline_call',
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
        const AndroidNotificationAction(
          'accept_call',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.wav',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'incoming_call',
      'call_id': signal.callId,
      'caller_id': signal.callerId,
      'caller_name': signal.callerName,
      'caller_avatar': signal.callerAvatar,
      'channel_name': signal.channelName,
      'is_video_call': signal.isVideoCall,
    });

    await _notifications.show(
      9999, // Fixed ID for call notification
      signal.isVideoCall == true ? 'Incoming Video Call' : 'Incoming Voice Call',
      signal.callerName ?? 'Unknown',
      details,
      payload: payload,
    );
  }

  /// Cancel incoming call notification
  Future<void> cancelCallNotification() async {
    await _notifications.cancel(9999);
  }

  /// Handle notification action (accept/decline)
  Future<void> handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      final actionId = response.actionId;

      if (actionId == 'accept_call') {
        onIncomingCall?.call(CallSignal(
          type: CallSignalType.incoming,
          callId: data['call_id'],
          callerId: data['caller_id'],
          callerName: data['caller_name'],
          callerAvatar: data['caller_avatar'],
          channelName: data['channel_name'],
          isVideoCall: data['is_video_call'],
        ));
      } else if (actionId == 'decline_call') {
        // Send decline signal
        await CallSignalingService.answerCall(
          callerId: data['caller_id'],
          callId: data['call_id'],
          accepted: false,
          channelName: data['channel_name'],
        );
      }
    } catch (e) {
      debugPrint('Error handling call notification response: $e');
    }
  }
}
