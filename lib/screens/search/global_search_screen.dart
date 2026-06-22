import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;

      final response = await supabase
          .from('users')
          .select('id, username, display_name, avatar_url, bio, phone, created_at')
          .ilike('username', '%${query.trim()}%')
          .limit(20);

      final filtered = List<Map<String, dynamic>>.from(response)
          .where((u) => u['id'] != currentUserId)
          .toList();

      setState(() {
        _users = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id;

      if (currentUserId == null) {
        throw Exception('Not authenticated');
      }

      final targetUserId = user['id'] as String;

      // Check if a direct chat already exists
      final existingChats = await supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', currentUserId);

      final currentUserChatIds = List<Map<String, dynamic>>.from(existingChats)
          .map((c) => c['chat_id'] as String)
          .toList();

      if (currentUserChatIds.isNotEmpty) {
        final mutualChat = await supabase
            .from('chat_participants')
            .select('chat_id, chats!inner(type)')
            .eq('user_id', targetUserId)
            .inFilter('chat_id', currentUserChatIds)
            .eq('chats.type', 'direct')
            .maybeSingle();

        if (mutualChat != null) {
          if (mounted) {
            Navigator.pushNamed(
              context,
              '/chat',
              arguments: {
                'chatId': mutualChat['chat_id'],
                'chatName': user['username'] ?? 'Chat',
                'chatAvatar': user['avatar_url'],
                'isGroup': false,
              },
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Create new direct chat
      final chatId = DateTime.now().millisecondsSinceEpoch.toString();

      await supabase.from('chats').insert({
        'id': chatId,
        'name': null,
        'type': 'direct',
        'created_by': currentUserId,
        'created_at': DateTime.now().toIso8601String(),
      });

      await supabase.from('chat_participants').insert([
        {
          'chat_id': chatId,
          'user_id': currentUserId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
        {
          'chat_id': chatId,
          'user_id': targetUserId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
      ]);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatId': chatId,
            'chatName': user['username'] ?? 'Chat',
            'chatAvatar': user['avatar_url'],
            'isGroup': false,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _viewPublicProfile(Map<String, dynamic> user) {
    Navigator.pushNamed(
      context,
      '/public_profile',
      arguments: {
        'userId': user['id'],
        'username': user['username'],
        'avatarUrl': user['avatar_url'],
        'bio': user['bio'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by username...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _searchUsers(value);
              }
            });
          },
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _users = [];
                  _error = null;
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _searchUsers(_searchController.text),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for users by username',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? 'Unknown';
    final displayName = user['display_name'] as String? ?? username;
    final avatarUrl = user['avatar_url'] as String?;
    final bio = user['bio'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@$username',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
              ),
            ),
            if (bio != null && bio.isNotEmpty)
              Text(
                bio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => _viewPublicProfile(user),
              tooltip: 'View Profile',
            ),
            IconButton(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () => _startChat(user),
              tooltip: 'Start Chat',
            ),
          ],
        ),
      ),
    );
  }
}
