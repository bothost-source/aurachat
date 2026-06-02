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
import 'screens/calls/calls_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/invite/invite_friends_screen.dart';
import 'screens/saved/saved_messages_screen.dart';
import 'screens/archive/archived_chats_screen.dart';
import 'services/notification_service.dart';
import 'services/connectivity.dart';

/// Use environment variables or secure config for production
/// NEVER commit real credentials to git
const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL', 
    defaultValue: 'https://eocvhkbjjqeinycdgshj.supabase.co');
const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvY3Zoa2JqanFlaW55Y2Rnc2hqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzNDMxODEsImV4cCI6MjA5NTkxOTE4MX0.Eqd4jqB7BpROM7LyXX4GoW0UBWkltKXuf1XrT0CwQQQ');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.init();
  ConnectivityService().initialize();

  // Initialize Supabase with error handling
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: false,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Lock orientation
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

  runApp(const TarrificChatApp());
}

class TarrificChatApp extends StatefulWidget {
  const TarrificChatApp({super.key});

  @override
  State<TarrificChatApp> createState() => _TarrificChatAppState();
}

class _TarrificChatAppState extends State<TarrificChatApp> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh auth session when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshSession();
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
            title: 'TARRIFIC CHAT',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/terms': (context) => const TermsScreen(),
              '/login': (context) => const LoginScreen(),
              '/otp': (context) => const OTPScreen(),
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
              '/calls': (context) => const CallsScreen(),
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
}
