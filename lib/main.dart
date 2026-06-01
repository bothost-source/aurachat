import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'themes/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/theme_provider.dart';
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
import 'screens/profile/public_profile_screen.dart';
import 'screens/moderation/report_screen.dart';
import 'screens/moderation/appeal_screen.dart';
import 'screens/ai/ai_studio_screen.dart';
import 'screens/channel/channel_screen.dart';
import 'screens/calls/calls_screen.dart';
import 'screens/search/global_search_screen.dart';
import 'screens/contacts/contacts_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/notifications_settings_screen.dart';
import 'screens/settings/data_storage_screen.dart';
import 'screens/settings/account_settings_screen.dart';
import 'screens/settings/bot_settings_screen.dart';
import 'screens/invite/invite_friends_screen.dart';
import 'screens/saved/saved_messages_screen.dart';
import 'screens/archive/archived_chats_screen.dart';
import 'services/notification_service.dart';
import 'services/connectivity.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_chat_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services with error handling
  ConnectivityService().initialize();
  await NotificationService.init();
  
  try {
    FirebaseChatService().initialize();
    await Firebase.initializeApp();    
  } catch (e) {
    print('Firebase init error: $e');
    // Continue without Firebase - app will still open
  }
  
  SystemChrome.setPreferredOrientations([
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

class TarrificChatApp extends StatelessWidget {
  const TarrificChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => BotProvider()),
        ChangeNotifierProvider(create: (_) => ModerationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'TARRIFIC CHAT',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            initialRoute: '/',
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
              '/public_profile': (contxt) => const PublicProfileScreen(),
              '/report': (context) => const ReportScreen(),
              '/appeal': (context) => const AppealScreen(),
              '/ai_studio': (context) => AIStudioScreen(),
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
