import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String? _error;
  List<String> _recentSearches = [];
  final String _recentSearchesKey = 'global_search_recent';
  RealtimeChannel? _presenceChannel;
  Map<String, bool> _onlineStatus = {};

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _subscribeToPresence();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  // ─── Recent Searches ───

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final trimmed = query.trim();
    setState(() {
      _recentSearches.remove(trimmed);
      _recentSearches.insert(0, trimmed);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.sublist(0, 10);
      }
    });
    await _saveRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    setState(() => _recentSearches.clear());
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }

  Future<void> _removeRecentSearch(String query) async {
    setState(() => _recentSearches.remove(query));
    await _saveRecentSearches();
  }

  // ─── Real-time Online Status ───

  void _subscribeToPresence() {
    final supabase = Supabase.instance.client;
    _presenceChannel = supabase.channel('online_users');

    _presenceChannel!
        .onPresenceSync((payload) {
          final presenceState = _presenceChannel!.presenceState();
          final onlineIds = <String>{};
          for (final presence in presenceState) {
            for (final user in presence.presences) {
              final userId = user.payload['user_id'] as String?;
              if (userId != null) onlineIds.add(userId);
            }
          }
          if (mounted) {
            setState(() {
              for (final id in onlineIds) {
                _onlineStatus[id] = true;
              }
              // Mark others as offline if not in presence state
              for (final user in _users) {
                final uid = user['id'] as String?;
                if (uid != null && !onlineIds.contains(uid)) {
                  _onlineStatus[uid] = false;
                }
              }
            });
          }
        })
        .subscribe((status, error) {
          if (status == 'SUBSCRIBED') {
            _trackPresence();
          }
        });
  }

  void _trackPresence() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // FIXED: Use mockUserId as fallback
    final currentUserId = authProvider.user?.id ?? authProvider.mockUserId;
    if (currentUserId == null) return;

    _presenceChannel?.track({'user_id': currentUserId});
  }

  // ─── Search ───

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _users = [];
        _error = null;
      });
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // FIXED: Use mockUserId as fallback
      final currentUserId = authProvider.user?.id ?? authProvider.mockUserId;

      final searchTerm = '%${query.trim()}%';
      debugPrint('Searching for: $searchTerm');

      final response = await supabase
          .from('users')
          .select('id, username, display_name, avatar_url, bio, phone, created_at')
          .ilike('username', searchTerm)
          .limit(20);

      debugPrint('Search response: $response');

      final filtered = List<Map<String, dynamic>>.from(response)
          .where((u) => u['id'] != currentUserId)
          .toList();

      // Fetch online status for these users
      await _fetchOnlineStatus(filtered);

      setState(() {
        _users = filtered;
        _isLoading = false;
      });

      await _addRecentSearch(query);
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _error = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchOnlineStatus(List<Map<String, dynamic>> users) async {
    final supabase = Supabase.instance.client;
    final userIds = users.map((u) => u['id'] as String).toList();

    if (userIds.isEmpty) return;

    try {
      // Query presence table or use a custom online_status table
      final response = await supabase
          .from('online_status')
          .select('user_id, is_online')
          .inFilter('user_id', userIds);

      final onlineData = List<Map<String, dynamic>>.from(response);
      final statusMap = <String, bool>{};
      for (final row in onlineData) {
        statusMap[row['user_id'] as String] = row['is_online'] as bool;
      }

      if (mounted) {
        setState(() {
          for (final user in users) {
            final uid = user['id'] as String;
            _onlineStatus[uid] = statusMap[uid] ?? false;
          }
        });
      }
    } catch (e) {
      // Fallback: assume all offline if table doesn't exist
      debugPrint('Online status fetch error: $e');
    }
  }

  // ─── Chat ───

  Future<void> _startChat(Map<String, dynamic> user) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // FIXED: Use mockUserId as fallback
      final currentUserId = authProvider.user?.id ?? authProvider.mockUserId;

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

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _users = [];
      _error = null;
    });
  }

  bool _isUserOnline(String userId) {
    return _onlineStatus[userId] ?? false;
  }

  // ─── Build ───

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Discover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Glassmorphism Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            blurRadius: 20,
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: Colors.white.withOpacity(0.4),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              autofocus: true,
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                              cursorColor: const Color(0xFF8B5CF6),
                              decoration: InputDecoration(
                                hintText: 'Search by username...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onChanged: (value) {
                                setState(() {});
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (_searchController.text == value) {
                                    _searchUsers(value);
                                  }
                                });
                              },
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Body Content
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Loading state (initial)
    if (_isLoading && _users.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF8B5CF6).withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Error state
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 32,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _buildGlassButton(
                onPressed: () => _searchUsers(_searchController.text),
                label: 'Retry',
                icon: Icons.refresh_rounded,
              ),
            ],
          ),
        ),
      );
    }

    // Empty search state (no query yet)
    if (_searchController.text.isEmpty) {
      return _buildEmptyState();
    }

    // No results found
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Icon(
                Icons.person_search_outlined,
                size: 40,
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No users found',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Results list
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _users.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              '${_users.length} result${_users.length != 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
        return _buildGlowingUserCard(_users[index - 1]);
      },
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                child: Text(
                  'Clear all',
                  style: TextStyle(
                    color: const Color(0xFF8B5CF6).withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = search;
                  _searchUsers(search);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 14,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(search),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
        ],

        // Hint
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 40,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Search for users by username',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlowingUserCard(Map<String, dynamic> user) {
    final userId = user['id'] as String? ?? '';
    final username = user['username'] as String? ?? 'Unknown';
    final displayName = user['display_name'] as String? ?? username;
    final avatarUrl = user['avatar_url'] as String?;
    final bio = user['bio'] as String?;
    final isOnline = _isUserOnline(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                color: isOnline
                    ? const Color(0xFF06B6D4).withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOnline
                      ? const Color(0xFF06B6D4).withOpacity(0.12)
                      : const Color(0xFF8B5CF6).withOpacity(0.08),
                  blurRadius: 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: avatarUrl != null && avatarUrl.isNotEmpty
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF8B5CF6),
                                  Color(0xFF06B6D4),
                                ],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildAvatarFallback(username);
                                },
                              )
                            : _buildAvatarFallback(username),
                      ),
                    ),
                    // Online status dot
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0A0A0F),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF06B6D4).withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isOnline)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF06B6D4).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF06B6D4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF06B6D4).withOpacity(0.5),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Color(0xFF06B6D4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: const Color(0xFF8B5CF6).withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.person_outline,
                      onPressed: () => _viewPublicProfile(user),
                      tooltip: 'View Profile',
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      onPressed: () => _startChat(user),
                      tooltip: 'Start Chat',
                      isPrimary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String username) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFF06B6D4),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool isPrimary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF8B5CF6).withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF8B5CF6).withOpacity(0.3)
                  : Colors.white.withOpacity(0.08),
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isPrimary
                ? const Color(0xFF8B5CF6)
                : Colors.white.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF8B5CF6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
