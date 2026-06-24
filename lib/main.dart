import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'themes/app_theme.dart';
import 'providers/auth_provider.dart';
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
import 'screens/profile/profile_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'screens/groups/create_group_screen.dart';
import 'screens/status/status_screen.dart';
import 'screens/status/create_status_screen.dart';
import 'screens/moderation/report_screen.dart';
import 'screens/moderation/appeal_screen.dart';
import 'screens/ai/ai_chatbot_screen.dart';
import 'screens/ai/ai_studio_screen.dart';
import 'screens/channel/channel_screen.dart';
import 'screens/calls/call_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/invite/invite_friends_screen.dart';
import 'screens/saved/saved_messages_screen.dart';
import 'screens/archive/archived_chats_screen.dart';
import 'services/notification_service.dart';
import 'services/connectivity.dart';
import 'services/online_status_service.dart';
import 'services/call_service.dart';
import 'services/call_signaling_service.dart';

const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL', 
    defaultValue: 'https://ziesdpcajbzsffemgfiw.supabase.co');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZXNkcGNhamJ6c2ZmZW1nZml3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIxNjExNzAsImV4cCI6MjA5NzczNzE3MH0.TYexcUcB5N7z5tmSton2Hzdr0nuv8Nxc3Jf_O7akDd4');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.init();
  await NotificationService.requestPermission();
  ConnectivityService().initialize();
  CallService.initialize('8a2cea909f994b0d9e61146e99710277');
    
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: false,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

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
}

class AuraChatApp extends StatefulWidget {
  const AuraChatApp({super.key});

  @override
  State<AuraChatApp> createState() => _AuraChatAppState();
}

class _AuraChatAppState extends State<AuraChatApp> 
    with WidgetsBindingObserver {

  DateTime? _backgroundTime;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.listenToAuthChanges();
      
      // Start listening for incoming calls
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        CallSignalingService.startListening(currentUser.id);
        
        CallSignalingService.onCallSignal.listen((signal) {
          if (signal.type == CallSignalType.incoming && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => CallScreen.incoming(callSignal: signal),
              ),
            );
          }
        });
      }
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
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _backgroundTime = DateTime.now();
      
      if (settingsProvider.biometricLock || settingsProvider.appPasscode) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      OnlineStatusService.setOnline();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshSession();
      
      if (_isLocked && _backgroundTime != null) {
        final elapsed = DateTime.now().difference(_backgroundTime!);
        final timeoutMinutes = settingsProvider.autoLockTimeout;
        
        if (elapsed.inMinutes >= timeoutMinutes) {
          _showLockScreen();
        } else {
          setState(() => _isLocked = false);
        }
      }
    }
  }

  Future<void> _showLockScreen() async {
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
        
        if (didAuth) {
          setState(() => _isLocked = false);
          return;
        }
      } catch (e) {
        debugPrint('Biometric auth failed: $e');
      }
    }
    
    if (settingsProvider.appPasscode && mounted) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PasscodeDialog(
          correctPasscode: settingsProvider.passcode,
        ),
      );
      
      if (result == true) {
        setState(() => _isLocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => BotProvider()),
        ChangeNotifierProvider(create: (_) => ModerationProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return MaterialApp(
            title: 'AURA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            builder: (context, child) {
              if (_isLocked) {
                return _buildLockScreen();
              }
              return child!;
            },
            routes: {
              '/': (context) => const SplashScreen(),
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
              '/status': (context) => const StatusScreen(),
              '/create_status': (context) => const CreateStatusScreen(),
              '/report': (context) => const ReportScreen(),
              '/appeal': (context) => const AppealScreen(),
              '/ai_chatbot': (context) => const AIChatbotScreen(),
              '/ai_studio': (context) => const AIStudioScreen(),
              '/channel': (context) => const ChannelScreen(),
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
            },
          );
        },
      ),
    );
  }

  Widget _buildLockScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 24),
            const Text(
              'AURA is Locked',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Authentication required to continue',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _showLockScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Unlock',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasscodeDialog extends StatefulWidget {
  final String? correctPasscode;

  const _PasscodeDialog({required this.correctPasscode});

  @override
  State<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends State<_PasscodeDialog> {
  String _enteredPasscode = '';
  String _errorMessage = '';

  void _onDigitPressed(String digit) {
    if (_enteredPasscode.length < 6) {
      setState(() {
        _enteredPasscode += digit;
        _errorMessage = '';
      });

      if (_enteredPasscode.length == 6) {
        _verifyPasscode();
      }
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
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Incorrect passcode. Try again.';
        _enteredPasscode = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Passcode',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _enteredPasscode.length
                        ? Colors.white
                        : Colors.white24,
                  ),
                );
              }),
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 1; i <= 9; i++)
                  _buildDigitButton(i.toString()),
                const SizedBox.shrink(),
                _buildDigitButton('0'),
                IconButton(
                  onPressed: _onBackspace,
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
