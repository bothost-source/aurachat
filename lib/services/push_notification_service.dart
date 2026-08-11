import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_notification_service.dart';
import 'call_signaling_service.dart';

// ============================================================================
// BACKGROUND MESSAGE HANDLER (Must be top-level function)
// ============================================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
  
  final data = message.data;
  final type = data['type'] as String?;

  if (type == 'call') {
    // Initialize call notification service in background
    final callService = CallNotificationService();
    await callService.initialize();
    
    final signal = CallSignal(
      type: CallSignalType.incoming,
      callId: data['call_id'],
      callerId: data['caller_id'],
      callerName: data['caller_name'],
      callerAvatar: data['caller_avatar'],
      channelName: data['channel_name'],
      isVideoCall: data['is_video_call'] == 'true',
    );
    
    await callService.showIncomingCallNotification(signal);
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  Function(String chatId)? onChatOpen;
  Function()? onNotificationTap;

  Future<void> initialize({
    Function(String chatId)? onChatOpenCallback,
    Function()? onNotificationTapCallback,
  }) async {
    onChatOpen = onChatOpenCallback;
    onNotificationTap = onNotificationTapCallback;

    await _requestPermission();
    await _setupLocalNotifications();
    await _getAndSaveToken();
    await CallNotificationService().initialize();

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // Handle foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check initial message
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // Enable for call notifications
      announcement: false,
      carPlay: false,
    );
    print('Push notification permission: ${settings.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle call notification actions
        if (response.notificationResponseType == NotificationResponseType.selectedNotificationAction) {
          CallNotificationService().handleNotificationResponse(response);
          return;
        }
        
        final payload = response.payload;
        if (payload != null) {
          _handlePayload(payload);
        }
      },
    );
  }

  Future<void> _getAndSaveToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('mock_user_id');
    }

    if (userId == null) {
      print('No user ID available - cannot save FCM token');
      return;
    }

    await _firestore.collection('users').doc(userId).set({
      'fcmToken': token,
      'platform': 'android',
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('FCM token saved for user: $userId');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;
    final type = data['type'] as String?;

    // Handle call notifications differently
    if (type == 'call') {
      final signal = CallSignal(
        type: CallSignalType.incoming,
        callId: data['call_id'],
        callerId: data['caller_id'],
        callerName: data['caller_name'],
        callerAvatar: data['caller_avatar'],
        channelName: data['channel_name'],
        isVideoCall: data['is_video_call'] == 'true',
      );
      CallNotificationService().showIncomingCallNotification(signal);
      return;
    }

    // Regular message notification
    _showLocalNotification(
      title: notification?.title ?? 'New Message',
      body: notification?.body ?? '',
      payload: jsonEncode(data),
    );

    _incrementUnreadCount(data['chatId'] ?? '');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'call') {
      // Call tap handled by CallNotificationService
      return;
    }

    final chatId = data['chatId'];
    if (chatId != null && onChatOpen != null) {
      onChatOpen!(chatId);
    }
    onNotificationTap?.call();
  }

  void _handlePayload(String payload) {
    try {
      final data = jsonDecode(payload);
      final chatId = data['chatId'];

      if (chatId != null && onChatOpen != null) {
        onChatOpen!(chatId);
      }
    } catch (e) {
      print('Error handling notification payload: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'aura_chat_channel',
      'AURA Chat Messages',
      channelDescription: 'Chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: iosDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _incrementUnreadCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'unread_$chatId';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
  }

  Future<int> getUnreadCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('unread_$chatId') ?? 0;
  }

  Future<void> clearUnreadCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unread_$chatId');
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
  }
}
