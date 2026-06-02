import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _chatsSubscription;

  List<Map<String, dynamic>> get chats => _chats;
  List<Map<String, dynamic>> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChatProvider() {
    loadChats();
    _subscribeToChats();
  }

  Future<void> loadChats() async {
    _setLoading(true);
    _error = null;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _setLoading(false);
        return;
      }

      final response = await _supabase
          .from('chat_participants')
          .select('chat_id, role, chats!inner(id, name, description, avatar_url, type, created_by, created_at, last_message, last_message_at)')
          .eq('user_id', userId)
          .order('chats(last_message_at)', ascending: false);

      final List<Map<String, dynamic>> formattedChats = [];

      for (final item in response) {
        final chat = item['chats'] as Map<String, dynamic>;
        final chatId = chat['id'];

        final unreadResponse = await _supabase
            .from('messages')
            .select('id')
            .eq('chat_id', chatId)
            .eq('is_read', false)
            .neq('sender_id', userId);

        final unreadCount = unreadResponse.length;

        int participantsCount = 0;
        if (chat['type'] == 'group' || chat['type'] == 'channel') {
          final participantsResponse = await _supabase
              .from('chat_participants')
              .select('id')
              .eq('chat_id', chatId);
          participantsCount = participantsResponse.length;
        }

        formattedChats.add({
          ...chat,
          'role': item['role'],
          'unread_count': unreadCount,
          'participants_count': participantsCount,
        });
      }

      _chats = formattedChats;
      _setLoading(false);
    } catch (e) {
      _error = 'Failed to load chats: $e';
      _setLoading(false);
    }
  }

  void _subscribeToChats() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatsSubscription = _supabase
        .channel('chats:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            loadChats();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            loadChats();
          },
        )
        .subscribe();
  }

  Future<void> loadContacts() async {
    _setLoading(true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _setLoading(false);
        return;
      }

      final response = await _supabase
          .from('users')
          .select('id, username, avatar_url, phone, bio')
          .neq('id', userId)
          .order('username');

      _contacts = List<Map<String, dynamic>>.from(response);
      _setLoading(false);
    } catch (e) {
      _error = 'Failed to load contacts: $e';
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> startDirectChat(String otherUserId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final chatId = const Uuid().v4();

      await _supabase.from('chats').insert({
        'id': chatId,
        'type': 'direct',
        'created_at': DateTime.now().toIso8601String(),
      });

      await _supabase.from('chat_participants').insert([
        {
          'chat_id': chatId,
          'user_id': userId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
        {
          'chat_id': chatId,
          'user_id': otherUserId,
          'role': 'member',
          'joined_at': DateTime.now().toIso8601String(),
        },
      ]);

      await loadChats();

      return _chats.firstWhere(
        (chat) => chat['id'] == chatId,
        orElse: () => {'id': chatId},
      );
    } catch (e) {
      _error = 'Failed to start chat: $e';
      return null;
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('chat_id', chatId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      final index = _chats.indexWhere((chat) => chat['id'] == chatId);
      if (index >= 0) {
        _chats[index]['unread_count'] = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('chat_participants')
          .delete()
          .eq('chat_id', chatId)
          .eq('user_id', userId);

      await loadChats();
    } catch (e) {
      _error = 'Failed to delete chat: $e';
    }
  }

  Future<void> archiveChat(String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('chat_participants')
          .update({'is_archived': true})
          .eq('chat_id', chatId)
          .eq('user_id', userId);

      await loadChats();
    } catch (e) {
      _error = 'Failed to archive chat: $e';
    }
  }

  Future<void> unarchiveChat(String chatId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('chat_participants')
          .update({'is_archived': false})
          .eq('chat_id', chatId)
          .eq('user_id', userId);

      await loadChats();
    } catch (e) {
      _error = 'Failed to unarchive chat: $e';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatsSubscription?.unsubscribe();
    super.dispose();
  }
}
