import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

import 'themes/app_theme.dart';
import 'providers/auth_provider.dart' show AuraAuthProvider;
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/bot_provider.dart';
import 'providers/moderation_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding/terms_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/setup_profile_screen.dart';
import 'screens/main_app_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/bot/bot_store_screen.dart';
import 'screens/bot/bot_creator_screen.dart';
import 'screens/settings/privacy_settings_screen.dart';
import 'screens/settings/security_screen.dart';
import 'screens/settings/blocked_users_screen.dart';
import 'screens/settings/appearance_screen.dart';
import 'screens/settings/language_screen.dart';
import 'screens/settings/notifications_settings_screen.dart';
import 'screens/settings/data_storage_screen.dart';
import 'screens/settings/account_settings_screen.dart';
import 'screens/settings/bot_settings_screen.dart';
import 'screens/settings/restore_chats_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/status/status_screen.dart';
import 'screens/status/create_status_screen.dart';
import 'screens/moderation/report_screen.dart';
import 'screens/moderation/appeal_screen.dart';
import 'screens/moderation/ban_guard.dart';
import 'screens/ai/ai_chatbot_screen.dart';
import 'screens/ai/ai_studio_screen.dart';
import 'screens/channel/channel_screen.dart';
import 'screens/channel/create_channel_screen.dart';
import 'screens/calls/call_screen.dart';
import 'screens/calls/incoming_call_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/invite/invite_friends_screen.dart';
import 'screens/saved/saved_messages_screen.dart';
import 'screens/archive/archived_chats_screen.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/call_notification_service.dart';
import 'services/connectivity.dart';
import 'services/online_status_service.dart';
import 'services/call_service.dart';
import 'services/call_signaling_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/email_verification_screen.dart';

// Global navigator key for navigation from background/notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');

  final data = message.data;
  final type = data['type'] as String?;

  if (type == 'call') {
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

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  String? startupError;
  String? startupStack;

  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await NotificationService.init();
    await NotificationService.requestPermission();

    await CallNotificationService().initialize();

    final pushService = PushNotificationService();
    await pushService.initialize();

    ConnectivityService().initialize();
    CallService.initialize('8a2cea909f994b0d9e61146e99710277');

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runApp(const AuraChatApp());
    return;

  } catch (e, stack) {
    startupError = e.toString();
    startupStack = stack.toString();
  }

  runApp(ErrorApp(error: startupError ?? 'Unknown error', stack: startupStack));
}

class ErrorApp extends StatelessWidget {
  final String error;
  final String? stack;

  const ErrorApp({super.key, required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 24),
                const Text('AURA Chat Error',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'The app failed to start. Please screenshot this and send it to support email for help.',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 32),
                const Text('ERROR:',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontFamily: 'monospace')),
                ),
                if (stack != null) ...[
                  const SizedBox(height: 24),
                  const Text('STACK TRACE:',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(stack!,
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthRouter extends StatefulWidget {
  const AuthRouter({super.key});

  @override
  State<AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<AuthRouter> {
  Widget? _targetScreen;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final prefs = await SharedPreferences.getInstance();

    final pendingOtpPhone = prefs.getString('pending_otp_phone');
    final pendingOtpExpected = prefs.getString('pending_otp_expected');
    final pendingOtpTimestamp = prefs.getInt('pending_otp_timestamp');

    if (pendingOtpPhone != null && pendingOtpExpected != null && pendingOtpTimestamp != null) {
      final otpAge = DateTime.now().millisecondsSinceEpoch - pendingOtpTimestamp;
      if (otpAge < 10 * 60 * 1000) {
        setState(() {
          _targetScreen = OtpScreen(
            phoneNumber: pendingOtpPhone,
            expectedOtp: pendingOtpExpected,
            cleanPhoneNumber: pendingOtpPhone,
          );
          _isChecking = false;
        });
        return;
      } else {
        await prefs.remove('pending_otp_phone');
        await prefs.remove('pending_otp_expected');
        await prefs.remove('pending_otp_timestamp');
      }
    }

    final pendingEmailUserId = prefs.getString('pending_mock_user_id');
    final pendingEmail = prefs.getString('pending_mock_email');

    // FIX: Check for pending email verification for BOTH new and existing users
    if (pendingEmailUserId != null && pendingEmail != null) {
      final pendingEmailTimestamp = prefs.getInt('pending_email_timestamp');
      final emailAge = pendingEmailTimestamp != null
          ? DateTime.now().millisecondsSinceEpoch - pendingEmailTimestamp
          : 0;

      // Allow up to 30 minutes for email verification
      if (pendingEmailTimestamp == null || emailAge < 30 * 60 * 1000) {
        setState(() {
          _targetScreen = EmailVerificationScreen(
            userId: pendingEmailUserId,
            backendUrl: 'https://aurachat-backend-5utu.onrender.com',
            isLoginFlow: true,
          );
          _isChecking = false;
        });
        return;
      } else {
        // Expired — clear pending state
        await prefs.remove('pending_mock_user_id');
        await prefs.remove('pending_mock_email');
        await prefs.remove('pending_email_timestamp');
      }
    }

    // FIX: Also check for old-style pending email verification
    final oldPendingEmailUserId = prefs.getString('pending_email_user_id');
    final oldPendingEmailVerification = prefs.getBool('pending_email_verification') ?? false;
    final oldPendingEmailTimestamp = prefs.getInt('pending_email_timestamp');

    if (oldPendingEmailUserId != null && oldPendingEmailVerification && oldPendingEmailTimestamp != null) {
      final emailAge = DateTime.now().millisecondsSinceEpoch - oldPendingEmailTimestamp;
      if (emailAge < 30 * 60 * 1000) {
        setState(() {
          _targetScreen = EmailVerificationScreen(
            userId: oldPendingEmailUserId,
            backendUrl: 'https://aurachat-backend-5utu.onrender.com',
            isLoginFlow: true,
          );
          _isChecking = false;
        });
        return;
      } else {
        await prefs.remove('pending_email_user_id');
        await prefs.remove('pending_email_verification');
        await prefs.remove('pending_email_timestamp');
      }
    }

    // MOCK USER SUPPORT PRESERVED
    final currentUser = FirebaseAuth.instance.currentUser;
    final mockUserId = prefs.getString('mock_user_id');

    if (currentUser != null || mockUserId != null) {
      setState(() {
        _targetScreen = const MainAppScreen();
        _isChecking = false;
      });
      return;
    }

    setState(() {
      _targetScreen = const SplashScreen();
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
      );
    }
    return _targetScreen!;
  }
}

class CallListener extends StatefulWidget {
  final Widget child;
  const CallListener({super.key, required this.child});

  @override
  State<CallListener> createState() => _CallListenerState();
}

class _CallListenerState extends State<CallListener> {
  StreamSubscription<CallSignal>? _callSub;

  @override
  void initState() {
    super.initState();
    _setupCallListening();
  }

  void _setupCallListening() {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.currentUserId;

    if (userId != null) {
      CallSignalingService.startListening(userId);

      _callSub = CallSignalingService.onCallSignal.listen((signal) {
        if (signal.type == CallSignalType.incoming && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => IncomingCallScreen(signal: signal),
            ),
          );
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuraAuthProvider>(context);
    final userId = authProvider.currentUserId;
    if (userId != null) {
      CallSignalingService.startListening(userId);
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AuraChatApp extends StatefulWidget {
  const AuraChatApp({super.key});

  @override
  State<AuraChatApp> createState() => _AuraChatAppState();
}

class _AuraChatAppState extends State<AuraChatApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      authProvider.listenToAuthChanges();

      PushNotificationService().onChatOpen = (chatId) {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushNamed('/chat', arguments: {'chatId': chatId});
        }
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CallSignalingService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // FIX: Don't use Provider.of with listen: false here — use a local ref
    // to avoid triggering rebuilds that cause AuthRouter to re-check
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _handleBackground();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  void _handleBackground() async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.onAppBackground();
    } catch (e) {
      debugPrint('Background handler error: $e');
    }
  }

  void _handleResume() async {
    try {
      OnlineStatusService.setOnline();
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      authProvider.refreshSession();

      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      settingsProvider.shouldShowLockScreen();
    } catch (e) {
      debugPrint('Resume handler error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuraAuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BotProvider()),
        ChangeNotifierProvider(create: (_) => ModerationProvider()),
      ],
      child: Consumer2<ThemeProvider, AuraAuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'AURA',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            builder: (context, child) {
              // FIX: Use a separate widget that listens to SettingsProvider
              // so MaterialApp itself doesn't rebuild on every settings change
              return _AppLockWrapper(child: child!);
            },
            routes: {
              '/': (context) => const AuthRouter(),
              '/terms': (context) => const TermsScreen(),
              '/login': (context) => const LoginScreen(),
              '/setup_profile': (context) => const SetupProfileScreen(),
              '/main': (context) => const MainAppScreen(),
              '/chat': (context) => const ChatScreen(),
              '/bot_store': (context) => const BotStoreScreen(),
              '/bot_creator': (context) => const BotCreatorScreen(),
              '/privacy_settings': (context) => const PrivacySettingsScreen(),
              '/security': (context) => const SecurityScreen(),
              '/blocked_users': (context) => const BlockedUsersScreen(),
              '/appearance': (context) => const AppearanceScreen(),
              '/language': (context) => const LanguageScreen(),
              '/public_profile': (context) => const PublicProfileScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/create_group': (context) => const CreateGroupScreen(),
              '/create_channel': (context) => const CreateChannelScreen(),
              '/status': (context) => const StatusScreen(),
              '/create_status': (context) => const CreateStatusScreen(),
              '/report': (context) => const ReportScreen(),
              '/appeal': (context) => const AppealScreen(),
              '/ai_chatbot': (context) => const AIChatbotScreen(),
              '/ai_studio': (context) => const AIStudioScreen(),
              '/channel': (context) {
                final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                return ChannelChatScreen(
                  channelId: args?['channelId'] as String? ?? '',
                  channelName: args?['channelName'] as String? ?? 'Channel',
                );
              },
              '/calls': (context) => const CallScreen.pick(),
              '/global_search': (context) => const GlobalSearchScreen(),
              '/contacts': (context) => const ContactsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/notifications_settings': (context) => const NotificationsSettingsScreen(),
              '/data_storage': (context) => const DataStorageScreen(),
              '/account_settings': (context) => const AccountSettingsScreen(),
              '/bot_settings': (context) => const BotSettingsScreen(),
              '/invite_friends': (context) => const InviteFriendsScreen(),
              '/saved_messages': (context) => const SavedMessagesScreen(),
              '/archived_chats': (context) => const ArchivedChatsScreen(),
              '/restore_chats': (context) => const RestoreChatsScreen(),
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// APP LOCK WRAPPER — separated so MaterialApp doesn't rebuild on settings changes
// ============================================================================
class _AppLockWrapper extends StatefulWidget {
  final Widget child;
  const _AppLockWrapper({required this.child});

  @override
  State<_AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<_AppLockWrapper> {
  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isLocked = settingsProvider.isLocked;

    final app = CallListener(child: widget.child);

    // If locked, show lock screen OVER everything
    if (isLocked) {
      return _buildLockScreen(settingsProvider);
    }

    // Check ban status for authenticated users
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? authProvider.currentUserId;

    if (userId != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF0A0A0F),
              body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final isBanned = userData?['is_banned'] == true;
          final bannedUntil = userData?['banned_until'] as Timestamp?;

          if (isBanned && bannedUntil != null) {
            final banExpiry = bannedUntil.toDate();
            if (DateTime.now().isAfter(banExpiry)) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .update({
                'is_banned': false,
                'banned_until': null,
                'ban_reason': null,
                'ban_report_id': null,
                'ban_level': null,
              });
              return app;
            }
          }

          if (isBanned) {
            final banStatus = {
              'is_banned': true,
              'banned_until': bannedUntil?.toDate(),
              'ban_reason': userData?['ban_reason'],
              'ban_level': userData?['ban_level'],
              'ban_report_id': userData?['ban_report_id'],
            };
            return BannedScreen(banStatus: banStatus);
          }

          return app;
        },
      );
    }

    return app;
  }

  Widget _buildLockScreen(SettingsProvider settingsProvider) {
    return LockScreen(
      onUnlocked: () {
        settingsProvider.unlock();
      },
    );
  }
}

// ============================================================================
// LOCK SCREEN WIDGET — themed with purple gradient + glassmorphism passcode
// ============================================================================
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isAuthenticating = false;
  bool _showPasscode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptAutoAuth();
    });
  }

  Future<void> _attemptAutoAuth() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    if (settingsProvider.biometricLock) {
      final localAuth = LocalAuthentication();
      try {
        final didAuth = await localAuth.authenticate(
          localizedReason: 'Unlock AURA Chat',
          authMessages: const [
            AndroidAuthMessages(
              signInTitle: 'Biometric Authentication',
              cancelButton: 'Cancel',
              biometricHint: 'Verify your identity',
              biometricNotRecognized: 'Not recognized, try again',
              biometricRequiredTitle: 'Biometric authentication required',
              biometricSuccess: 'Authentication successful',
              deviceCredentialsRequiredTitle: 'Device credentials required',
              deviceCredentialsSetupDescription: 'Please set up device credentials',
              goToSettingsButton: 'Go to Settings',
              goToSettingsDescription: 'Please set up biometric authentication in your device settings',
            ),
            IOSAuthMessages(
              cancelButton: 'Cancel',
              goToSettingsButton: 'Go to Settings',
              goToSettingsDescription: 'Please set up biometric authentication in your device settings',
              lockOut: 'Please re-enable biometric authentication',
            ),
          ],
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            sensitiveTransaction: true,
            useErrorDialogs: true,
          ),
        );

        if (didAuth && mounted) {
          widget.onUnlocked();
          return;
        }
      } catch (e) {
        debugPrint('Biometric auth failed: $e');
      }
    }

    if (settingsProvider.appPasscode && mounted) {
      setState(() => _showPasscode = true);
    }

    _isAuthenticating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF1a103c),
              Color(0xFF0d1b2a),
              Color(0xFF0A0A0F),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: _showPasscode
                ? _PasscodeEntry(
                    correctPasscode: Provider.of<SettingsProvider>(context, listen: false).passcode,
                    onUnlocked: widget.onUnlocked,
                    onCancel: () => setState(() => _showPasscode = false),
                  )
                : _buildLockPrompt(),
          ),
        ),
      ),
    );
  }

  Widget _buildLockPrompt() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Glowing lock icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 48,
            color: Color(0xFF8B5CF6),
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'AURA is Locked',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Authentication required to continue',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 48),
        // Unlock button with glassmorphism
        GestureDetector(
          onTap: () {
            final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
            if (settingsProvider.appPasscode) {
              setState(() => _showPasscode = true);
            } else {
              _attemptAutoAuth();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Text(
              'Enter Passcode',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INLINE PASSCODE ENTRY — glassmorphism themed, no dialog
// ============================================================================
class _PasscodeEntry extends StatefulWidget {
  final String correctPasscode;
  final VoidCallback onUnlocked;
  final VoidCallback onCancel;

  const _PasscodeEntry({
    required this.correctPasscode,
    required this.onUnlocked,
    required this.onCancel,
  });

  @override
  State<_PasscodeEntry> createState() => _PasscodeEntryState();
}

class _PasscodeEntryState extends State<_PasscodeEntry> {
  String _enteredPasscode = '';
  String _errorMessage = '';
  bool _isShaking = false;

  void _onDigitPressed(String digit) {
    if (_enteredPasscode.length < 6) {
      setState(() {
        _enteredPasscode += digit;
        _errorMessage = '';
      });
      if (_enteredPasscode.length == 6) _verifyPasscode();
    }
  }

  void _onBackspace() {
    if (_enteredPasscode.isNotEmpty) {
      setState(() {
        _enteredPasscode = _enteredPasscode.substring(0, _enteredPasscode.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _verifyPasscode() {
    if (_enteredPasscode == widget.correctPasscode) {
      widget.onUnlocked();
    } else {
      setState(() {
        _errorMessage = 'Incorrect passcode';
        _enteredPasscode = '';
        _isShaking = true;
      });
      // Reset shake after animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isShaking = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.pin_outlined,
              size: 32,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter Passcode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your 6-digit PIN to unlock',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 32),

          // Dots with shake animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: _isShaking
                ? (Matrix4.identity()..translate(_shakeOffset()))
                : Matrix4.identity(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _enteredPasscode.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? const Color(0xFF8B5CF6)
                        : Colors.white.withOpacity(0.15),
                    boxShadow: isFilled
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 40),

          // Number pad with glassmorphism tiles
          SizedBox(
            width: 300,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                for (var i = 1; i <= 9; i++) _buildDigitButton(i.toString()),
                _buildActionButton(
                  icon: Icons.fingerprint,
                  onTap: () {
                    // Try biometric again
                    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
                    if (settingsProvider.biometricLock) {
                      _tryBiometric();
                    }
                  },
                ),
                _buildDigitButton('0'),
                _buildActionButton(
                  icon: Icons.backspace_outlined,
                  onTap: _onBackspace,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Cancel button
          TextButton(
            onPressed: widget.onCancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _shakeOffset() {
    // Simple shake effect
    final shakeCount = DateTime.now().millisecond % 4;
    return shakeCount == 0 ? -8 : shakeCount == 1 ? 8 : shakeCount == 2 ? -4 : 4;
  }

  Future<void> _tryBiometric() async {
    final localAuth = LocalAuthentication();
    try {
      final didAuth = await localAuth.authenticate(
        localizedReason: 'Unlock AURA Chat',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (didAuth && mounted) {
        widget.onUnlocked();
      }
    } catch (e) {
      debugPrint('Biometric retry failed: $e');
    }
  }

  Widget _buildDigitButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.6),
            size: 24,
          ),
        ),
      ),
    );
  }
}
