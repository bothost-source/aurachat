import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../themes/app_theme.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'chat_list/chats_list_screen.dart';
import 'status/status_screen.dart';
import 'calls/calls_screen.dart';
import 'settings/settings_screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;

  final List<Widget> _screens = [
    const ChatsListScreen(),
    const StatusScreen(),
    const CallsScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = ['Chats', 'Status', 'Calls', 'Settings'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final totalUnread = chatProvider.totalUnread;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          border: Border(top: BorderSide(color: AppTheme.divider)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppTheme.primaryGreen,
            unselectedItemColor: AppTheme.textTertiary,
            selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            items: [
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.chat_bubble_outline, 0, badge: totalUnread > 0 ? totalUnread.toString() : null),
                activeIcon: _buildNavIcon(Icons.chat_bubble, 0, isActive: true, badge: totalUnread > 0 ? totalUnread.toString() : null),
                label: 'Chats',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.auto_awesome_mosaic_outlined, 1),
                activeIcon: _buildNavIcon(Icons.auto_awesome_mosaic, 1, isActive: true),
                label: 'Status',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.call_outlined, 2),
                activeIcon: _buildNavIcon(Icons.call, 2, isActive: true),
                label: 'Calls',
              ),
              BottomNavigationBarItem(
                icon: _buildNavIcon(Icons.settings_outlined, 3),
                activeIcon: _buildNavIcon(Icons.settings, 3, isActive: true),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {bool isActive = false, String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24),
        if (badge != null)
          Positioned(
            top: -6,
            right: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentPink,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.bgSecondary, width: 1.5),
              ),
              child: Text(
                badge,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
