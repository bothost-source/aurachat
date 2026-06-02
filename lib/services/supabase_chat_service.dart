import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class SupabaseChatService {
  static final SupabaseChatService _instance = SupabaseChatService._internal();
  factory SupabaseChatService() => _instance;
  SupabaseChatService._internal();

  final _supabase = Supabase.instance.client;
  String? _currentUserId;

  void initialize() {
    _currentUserId = _supabase.auth.currentUser?.id;
  }

  String? get currentUserId => _currentUserId;

  // ==========================================================================
  // STREAMS (Real-time)
  // ==========================================================================

  Stream<List<ChatModel>> getUserChats() {
    return _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .map((data) => data
            .map((json) => ChatModel.fromJson(json as Map<String, dynamic>))
            .toList());
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .map((data) => data
            .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
            .toList());
  }

  Stream<List<String>> getTypingUsers(String chatId) {
    return _supabase
        .from('typing')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .map((data) => data
            .map((d) => d['user_id'] as String)
            .toList());
  }

  // ==========================================================================
  // MESSAGES
  // ==========================================================================

  Future<void> sendMessage({
    required String chatId,
    required String content,
    required MessageType type,
  }) async {
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': _currentUserId,
      'content': content,
      'type': type.name,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markAsRead(String chatId) async {
    await _supabase.from('chats').update({
      'unread_count': 0,
    }).eq('id', chatId);
  }

  // ==========================================================================
  // TYPING STATUS
  // ==========================================================================

  Future<void> setTypingStatus(String chatId, bool isTyping) async {
    final userId = _currentUserId;
    if (userId == null) return;

    if (isTyping) {
      await _supabase.from('typing').upsert({
        'chat_id': chatId,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } else {
      await _supabase.from('typing').delete().eq('user_id', userId);
    }
  }

  // ==========================================================================
  // CHAT CREATION
  // ==========================================================================

  Future<String> createDirectChat(String otherUserId) async {
    final currentUser = _currentUserId;
    if (currentUser == null) throw Exception('User not authenticated');

    final chatId = '\${currentUser}_\$otherUserId';
    await _supabase.from('chats').insert({
      'id': chatId,
      'name': 'Chat',
      'type': 'private',
      'participants': [currentUser, otherUserId],
      'created_at': DateTime.now().toIso8601String(),
    });
    return chatId;
  }

  Future<void> createGroupChat({
    required String name,
    String? description,
    required List<String> memberIds,
    bool isPublic = true,
  }) async {
    await _supabase.from('chats').insert({
      'name': name,
      'type': 'group',
      'description': description,
      'participants': memberIds,
      'is_public': isPublic,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    await _supabase.from('chats').insert({
      'name': name,
      'type': 'channel',
      'description': description,
      'is_public': isPublic,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await _supabase
        .from('users')
        .select()
        .ilike('username', '%\$query%');
    return response;
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

  void dispose() {}
}
