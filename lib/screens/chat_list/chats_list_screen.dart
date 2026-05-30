import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_model.dart';
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

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final pinnedChats = chatProvider.pinnedChats;
    final unpinnedChats = chatProvider.unpinnedChats;

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _isSearching ? _buildSearchAppBar() : _buildMainAppBar(),
      body: RefreshIndicator(
        onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
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
            if (pinnedChats.isEmpty && unpinnedChats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('No chats yet', style: TextStyle(color: AppTheme.textTertiary)),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/contacts'),
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  AppBar _buildMainAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgSecondary,
      elevation: 0,
      title: const Text('TARRIFIC CHAT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      actions: [
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
                break;
              case 'new_channel':
                break;
              case 'saved':
                Navigator.pushNamed(context, '/saved_messages');
                break;
              case 'archived':
                Navigator.pushNamed(context, '/archived_chats');
                break;
              case 'settings':
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
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary, letterSpacing: 1),
      ),
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
              // Avatar
              _buildAvatar(chat),
              const SizedBox(width: 14),
              // Content
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
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread ? AppTheme.primaryGreen : AppTheme.textTertiary,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
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
                            style: TextStyle(
                              fontSize: 14,
                              color: hasUnread ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              chat.unreadCount.toString(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
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
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.bookmark, color: Colors.white, size: 24),
      );
    }

    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.bgElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.divider, width: 1),
          ),
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
              decoration: BoxDecoration(
                color: AppTheme.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.bgPrimary, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerifiedBadge(VerificationLevel level) {
    final isOfficial = level == VerificationLevel.official;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: isOfficial ? AppTheme.verifiedGold : AppTheme.verifiedBlue,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 10, color: Colors.white),
    );
  }
}
