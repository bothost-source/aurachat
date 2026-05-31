import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// PUSH NOTIFICATION SERVICE — Firebase Cloud Messaging
// ============================================================================
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

  // Callbacks for navigation
  Function(String chatId)? onChatOpen;
  Function()? onNotificationTap;

  // Initialize everything
  Future<void> initialize({
    Function(String chatId)? onChatOpenCallback,
    Function()? onNotificationTapCallback,
  }) async {
    onChatOpen = onChatOpenCallback;
    onNotificationTap = onNotificationTapCallback;

    // Request permission
    await _requestPermission();

    // Setup local notifications
    await _setupLocalNotifications();

    // Get FCM token
    await _getAndSaveToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // Handle foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps (app was in background)
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  // ==========================================================================
  // PERMISSIONS
  // ==========================================================================

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('Push notification permission: ${settings.authorizationStatus}');
  }

  // ==========================================================================
  // LOCAL NOTIFICATIONS (Foreground)
  // ==========================================================================

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
        final payload = response.payload;
        if (payload != null) {
          _handlePayload(payload);
        }
      },
    );
  }

  // ==========================================================================
  // FCM TOKEN
  // ==========================================================================

  Future<void> _getAndSaveToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'fcmToken': token,
      'platform': 'android', // or detect platform
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================================
  // MESSAGE HANDLERS
  // ==========================================================================

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    // Show local notification
    _showLocalNotification(
      title: notification?.title ?? 'New Message',
      body: notification?.body ?? '',
      payload: jsonEncode(data),
    );

    // Update unread count in local storage
    _incrementUnreadCount(data['chatId'] ?? '');
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
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

  // ==========================================================================
  // LOCAL NOTIFICATION DISPLAY
  // ==========================================================================

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'tarrific_chat_channel',
      'TARRIFIC CHAT',
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
      android: androidDetails,
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

  // ==========================================================================
  // UNREAD COUNT
  // ==========================================================================

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

  // ==========================================================================
  // NOTIFICATION SETTINGS
  // ==========================================================================

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  Future<void> setMuteChat(String chatId, bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mute_$chatId', muted);
  }

  Future<bool> isChatMuted(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mute_$chatId') ?? false;
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  void dispose() {
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
  }
}

// ============================================================================
// BACKGROUND MESSAGE HANDLER (Must be top-level function)
// ============================================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This runs when app is terminated/backgrounded
  // Keep it light — just show notification
  print('Background message: ${message.messageId}');
}
