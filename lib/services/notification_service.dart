import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(initSettings);

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'otp_channel',
      'OTP Notifications',
      description: 'One-time password notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  static Future<void> requestPermission() async {
    final status = await permission_handler.Permission.notification.request();
    debugPrint('Notification permission: $status');
    
    if (status.isPermanentlyDenied) {
      await permission_handler.openAppSettings();
    }
  }

  static Future<bool> checkPermission() async {
    final status = await permission_handler.Permission.notification.status;
    return status.isGranted;
  }

  static Future<void> showOTP(String otp, String phoneNumber) async {
    // Check/request permission first
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      await requestPermission();
    }

    const androidDetails = AndroidNotificationDetails(
      'otp_channel',
      'OTP Notifications',
      channelDescription: 'One-time password notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      color: Color(0xFF8B5CF6),
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

    await _notifications.show(
      DateTime.now().millisecond,
      'AURA Verification Code',
      'Your OTP for $phoneNumber is: $otp',
      details,
    );

    debugPrint('OTP notification sent: $otp');
  }
}
