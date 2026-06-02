import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'chat/chat_list_screen.dart';
import 'status/status_screen.dart';
import 'calls/calls_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _currentIndex = _tabController.index);
    });

    // Load chats on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).loadChats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('TARRIFIC CHAT'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/global_search'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.pushNamed(context, '/settings');
                  break;
                case 'profile':
                  Navigator.pushNamed(context, '/profile');
                  break;
                case 'saved':
                  Navigator.pushNamed(context, '/saved_messages');
                  break;
                case 'invite':
                  Navigator.pushNamed(context, '/invite_friends');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'saved',
                child: Row(
                  children: [
                    Icon(Icons.bookmark),
                    SizedBox(width: 8),
                    Text('Saved Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.person_add),
                    SizedBox(width: 8),
                    Text('Invite Friends'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'CHATS'),
            Tab(text: 'STATUS'),
            Tab(text: 'CALLS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ChatListScreen(),
          StatusScreen(),
          CallsScreen(),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    switch (_currentIndex) {
      case 0: // Chats
        return FloatingActionButton(
          onPressed: () => _showNewChatOptions(context),
          child: const Icon(Icons.chat),
        );
      case 1: // Status
        return FloatingActionButton(
          onPressed: () => Navigator.pushNamed(context, '/create_status'),
          child: const Icon(Icons.camera_alt),
        );
      case 2: // Calls
        return FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add_call),
        );
      default:
        return null;
    }
  }

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('New Group'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_group');
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('New Channel'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create_group');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('New Contact'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/contacts');
              },
            ),
          ],
        ),
      ),
    );
  }
}
