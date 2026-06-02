import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/supabase_chat_service.dart';
import '../../services/connectivity.dart';
import '../../models/chat_model.dart' show ChatModel;
import '../../models/message_model.dart';
import '../../models/user_model.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingUsers = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRealChats();
  }

  Future<void> _loadRealChats() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSetup = prefs.getBool('profile_setup_complete') ?? false;
    if (!hasSetup) {
      context.read<ChatProvider>().clearAllChats();
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchingUsers = false;
      });
      return;
    }
    setState(() => _isSearchingUsers = true);

    try {
      final results = await context.read<ChatProvider>().searchUsers(query);
      setState(() {
        _searchResults = results;
        _isSearchingUsers = false;
      });
    } catch (e) {
      setState(() => _isSearchingUsers = false);
    }
  }

  void _startRealChat(Map<String, dynamic> user) async {
    final chatProvider = context.read<ChatProvider>();

    setState(() => _isLoading = true);

    try {
      // Create or get direct chat via Firebase
      await chatProvider.createDirectChat(user['id'] ?? '');

      // Navigate to chat
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: {
          'chatId': chatProvider.selectedChat?.id,
          'otherUserId': user['id'],
          'otherUserName': user['displayName'] ?? user['username'],
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Create Group with Firebase
  void _showCreateGroup() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPublic = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('New Group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 16),

              // Group Photo
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.group, color: Colors.white, size: 36),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.bgModal, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Group Name',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.group, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.description, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 16),

              // Group Type Toggle
              Text('Group Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => isPublic = true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPublic ? AppTheme.primaryGreen.withOpacity(0.2) : AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPublic ? AppTheme.primaryGreen : AppTheme.divider,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.public, color: isPublic ? AppTheme.primaryGreen : AppTheme.textTertiary),
                            const SizedBox(height: 4),
                            Text('Public', style: TextStyle(
                              color: isPublic ? AppTheme.primaryGreen : AppTheme.textSecondary,
                              fontWeight: isPublic ? FontWeight.w600 : FontWeight.normal,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => isPublic = false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isPublic ? AppTheme.primaryGreen.withOpacity(0.2) : AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isPublic ? AppTheme.primaryGreen : AppTheme.divider,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock, color: !isPublic ? AppTheme.primaryGreen : AppTheme.textTertiary),
                            const SizedBox(height: 4),
                            Text('Private', style: TextStyle(
                              color: !isPublic ? AppTheme.primaryGreen : AppTheme.textSecondary,
                              fontWeight: !isPublic ? FontWeight.w600 : FontWeight.normal,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;

                    Navigator.pop(context);

                    try {
                      await context.read<ChatProvider>().createGroupChat(
                        name: nameController.text,
                        description: descController.text.isNotEmpty ? descController.text : null,
                        memberIds: [], // TODO: Add member selection
                        isPublic: isPublic,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group created successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Create Channel with Firebase
  void _showCreateChannel() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    bool isPublic = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('New Channel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 16),

              // Channel Photo
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.campaign, color: Colors.white, size: 36),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.bgModal, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Channel Name',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.campaign, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.description, color: AppTheme.textTertiary),
                ),
              ),
              const SizedBox(height: 16),

              // Channel Type Toggle
              Text('Channel Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => isPublic = true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPublic ? AppTheme.primaryGreen.withOpacity(0.2) : AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPublic ? AppTheme.primaryGreen : AppTheme.divider,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.public, color: isPublic ? AppTheme.primaryGreen : AppTheme.textTertiary),
                            const SizedBox(height: 4),
                            Text('Public', style: TextStyle(
                              color: isPublic ? AppTheme.primaryGreen : AppTheme.textSecondary,
                              fontWeight: isPublic ? FontWeight.w600 : FontWeight.normal,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => isPublic = false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isPublic ? AppTheme.primaryGreen.withOpacity(0.2) : AppTheme.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isPublic ? AppTheme.primaryGreen : AppTheme.divider,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock, color: !isPublic ? AppTheme.primaryGreen : AppTheme.textTertiary),
                            const SizedBox(height: 4),
                            Text('Private', style: TextStyle(
                              color: !isPublic ? AppTheme.primaryGreen : AppTheme.textSecondary,
                              fontWeight: !isPublic ? FontWeight.w600 : FontWeight.normal,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;

                    Navigator.pop(context);

                    try {
                      await context.read<ChatProvider>().createChannel(
                        name: nameController.text,
                        description: descController.text.isNotEmpty ? descController.text : null,
                        isPublic: isPublic,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Channel created successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Channel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Find People', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by username, name, or phone...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                if (value.length >= 2) _searchUsers(value);
                else setState(() => _searchResults = []);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearchingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: AppTheme.textTertiary.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty ? 'Type to search users' : 'No users found',
                                style: TextStyle(color: AppTheme.textTertiary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.bgElevated,
                                backgroundImage: user['photoUrl'] != null ? NetworkImage(user['photoUrl']) : null,
                                child: user['photoUrl'] == null
                                    ? Text((user['displayName'] ?? user['username'] ?? '?')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(user['displayName'] ?? user['username'] ?? 'Unknown',
                                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                              subtitle: Text('@${user['username'] ?? ''}', style: TextStyle(color: AppTheme.textSecondary)),
                              trailing: user['isVerified'] == true
                                  ? const Icon(Icons.verified, color: AppTheme.verifiedBlue, size: 20)
                                  : null,
                              onTap: () {
                                Navigator.pop(context);
                                _startRealChat(user);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final allChats = chatProvider.chats;
    final pinnedChats = chatProvider.pinnedChats;
    final unpinnedChats = chatProvider.unpinnedChats;
    final isLoading = chatProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _isSearching ? _buildSearchAppBar() : _buildMainAppBar(themeProvider),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              onRefresh: () async => await chatProvider.refreshChats(),
              color: AppTheme.primaryGreen,
              backgroundColor: AppTheme.bgSecondary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (pinnedChats.isNotEmpty) ...[
                    _buildSectionHeader('PINNED'),
                    ...pinnedChats.map((chat) => _buildChatTile(chat)),
                    Divider(color: AppTheme.divider, indent: 80),
                  ],
                  if (unpinnedChats.isNotEmpty) ...[
                    if (pinnedChats.isNotEmpty) _buildSectionHeader('ALL CHATS'),
                    ...unpinnedChats.map((chat) => _buildChatTile(chat)),
                  ],
                  if (allChats.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(color: AppTheme.bgElevated, shape: BoxShape.circle),
                              child: Icon(Icons.chat_bubble_outline, size: 60, color: AppTheme.textTertiary.withOpacity(0.5)),
                            ),
                            const SizedBox(height: 24),
                            const Text('No chats yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 8),
                            Text('Find people and start chatting!', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showUserSearch,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Find People'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUserSearch,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  AppBar _buildMainAppBar(ThemeProvider themeProvider) {
    return AppBar(
      backgroundColor: AppTheme.bgSecondary,
      elevation: 0,
      title: const Text('TARRIFIC CHAT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      actions: [
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: AppTheme.textPrimary,
          ),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.textPrimary),
          onPressed: () => setState(() => _isSearching = true),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          color: AppTheme.bgModal,
          onSelected: (value) {
            switch (value) {
              case 'new_group':
                _showCreateGroup();
                break;
              case 'new_channel':
                _showCreateChannel();
                break;
              case 'saved':
                Navigator.pushNamed(context, '/saved_messages');
                break;
              case 'archived':
                Navigator.pushNamed(context, '/archived_chats');
                break;
              case 'settings':
                Navigator.pushNamed(context, '/settings');
                break;
            }
          },
          itemBuilder: (context) => [
            _buildMenuItem('new_group', 'New Group', Icons.group),
            _buildMenuItem('new_channel', 'New Channel', Icons.campaign),
            _buildMenuItem('saved', 'Saved Messages', Icons.bookmark),
            _buildMenuItem('archived', 'Archived Chats', Icons.archive),
            _buildMenuItem('settings', 'Settings', Icons.settings),
          ],
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgSecondary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          context.read<ChatProvider>().setSearchQuery(null);
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search chats, messages...',
          hintStyle: TextStyle(color: AppTheme.textTertiary),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textTertiary, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<ChatProvider>().setSearchQuery(null);
                  },
                )
              : null,
        ),
        onChanged: (value) => context.read<ChatProvider>().setSearchQuery(value.isEmpty ? null : value),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String text, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1)),
    );
  }

  Widget _buildChatTile(ChatModel chat) {
    final isSelf = chat.isSelfChat;
    final hasUnread = chat.unreadCount > 0;
    final isMuted = chat.isMuted;

    return Slidable(
      key: ValueKey(chat.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          CustomSlidableAction(
            onPressed: (_) => context.read<ChatProvider>().pinChat(chat.id),
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.push_pin, size: 20),
              SizedBox(height: 4),
              Text('Pin', style: TextStyle(fontSize: 12)),
            ]),
          ),
          CustomSlidableAction(
            onPressed: (_) => context.read<ChatProvider>().muteChat(chat.id, ChatMuteDuration.eightHours),
            backgroundColor: AppTheme.warning,
            foregroundColor: Colors.white,
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_off, size: 20),
              SizedBox(height: 4),
              Text('Mute', style: TextStyle(fontSize: 12)),
            ]),
          ),
          CustomSlidableAction(
            onPressed: (_) => context.read<ChatProvider>().archiveChat(chat.id),
            backgroundColor: AppTheme.textMuted,
            foregroundColor: Colors.white,
            child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.archive, size: 20),
              SizedBox(height: 4),
              Text('Archive', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          context.read<ChatProvider>().selectChat(chat);
          context.read<ChatProvider>().markAsRead(chat.id);
          Navigator.pushNamed(context, '/chat');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(chat),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  chat.displayName,
                                  style: TextStyle(fontSize: 15, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500, color: AppTheme.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (chat.participants.isNotEmpty && chat.participants.first.isVerified) ...[
                                const SizedBox(width: 4),
                                _buildVerifiedBadge(chat.participants.first.verificationLevel),
                              ],
                              if (isMuted) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.notifications_off, size: 14, color: AppTheme.textTertiary),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          chat.timeString,
                          style: TextStyle(fontSize: 12, color: hasUnread ? AppTheme.primaryGreen : AppTheme.textTertiary, fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (chat.lastMessage?.senderId == 'me') ...[
                          Icon(
                            chat.lastMessage?.status == MessageStatus.read ? Icons.done_all : Icons.done,
                            size: 14,
                            color: chat.lastMessage?.status == MessageStatus.read ? AppTheme.accentCyan : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            chat.subtitle,
                            style: TextStyle(fontSize: 14, color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)),
                            child: Text(chat.unreadCount.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatModel chat) {
    if (chat.isSelfChat) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(gradient: AppGradients.primary, shape: BoxShape.circle),
        child: const Icon(Icons.bookmark, color: Colors.white, size: 24),
      );
    }
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: AppTheme.bgElevated, shape: BoxShape.circle, border: Border.all(color: AppTheme.divider, width: 1)),
          child: chat.avatarUrl != null
              ? ClipOval(child: Image.network(chat.avatarUrl!, fit: BoxFit.cover))
              : Center(
                  child: Text(
                    chat.displayName.isNotEmpty ? chat.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ),
        ),
        if (chat.participants.isNotEmpty && chat.participants.first.status == UserStatus.online)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: AppTheme.online, shape: BoxShape.circle, border: Border.all(color: AppTheme.bgPrimary, width: 2)),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifiedBadge(VerificationLevel level) {
    final isOfficial = level == VerificationLevel.official;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: isOfficial ? AppTheme.verifiedGold : AppTheme.verifiedBlue, shape: BoxShape.circle),
      child: const Icon(Icons.check, size: 10, color: Colors.white),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
