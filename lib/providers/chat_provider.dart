import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/firebase_chat_service.dart';
import '../services/ai_moderation_service.dart';
import '../services/connectivity.dart';

// ============================================================================
// CHAT PROVIDER — With AI Moderation
// ============================================================================
class ChatProvider extends ChangeNotifier {
  final FirebaseChatService _firebaseService = FirebaseChatService();
  final AIModerationService _moderationService = AIModerationService();

  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  ChatModel? _selectedChat;
  String? _searchQuery;
  bool _isLoading = false;
  String? _error;
  List<String> _typingUsers = [];

  // Streams
  StreamSubscription<List<ChatModel>>? _chatsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<List<String>>? _typingSubscription;

  // Getters
  List<ChatModel> get chats => _filterChats(_chats);
  List<ChatModel> get pinnedChats => _filterChats(_chats.where((c) => c.isPinned).toList());
  List<ChatModel> get unpinnedChats => _filterChats(_chats.where((c) => !c.isPinned).toList());
  List<MessageModel> get messages => _messages;
  ChatModel? get selectedChat => _selectedChat;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get typingUsers => _typingUsers;
  bool get isTyping => _typingUsers.isNotEmpty;
  String get typingText => _typingUsers.length == 1 
      ? 'typing...' 
      : '${_typingUsers.length} people typing...';

  // ✅ FIX 3: Added totalUnread getter
  int get totalUnread => _chats.fold(0, (sum, chat) => sum + chat.unreadCount);

  // AI Moderation status
  bool _aiModerationEnabled = true;
  bool get aiModerationEnabled => _aiModerationEnabled;
  void toggleAIModeration() {
    _aiModerationEnabled = !_aiModerationEnabled;
    notifyListeners();
  }

  ChatProvider() {
    _firebaseService.initialize();
    _loadChats();
  }

  // ==========================================================================
  // CHAT LOADING
  // ==========================================================================

  void _loadChats() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _chatsSubscription?.cancel();
    _chatsSubscription = _firebaseService.getUserChats().listen(
      (chats) {
        _chats = chats;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> refreshChats() async {
    _loadChats();
  }

  // ==========================================================================
  // CHAT SELECTION
  // ==========================================================================

  void selectChat(ChatModel chat) {
    _selectedChat = chat;
    _messages = [];
    _typingUsers = [];
    notifyListeners();

    _messagesSubscription?.cancel();
    _messagesSubscription = _firebaseService.getMessages(chat.id).listen(
      (messages) {
        _messages = messages.reversed.toList();
        notifyListeners();
      },
    );

    _typingSubscription?.cancel();
    _typingSubscription = _firebaseService.getTypingUsers(chat.id).listen(
      (users) {
        _typingUsers = users;
        notifyListeners();
      },
    );

    _firebaseService.markAsRead(chat.id);
  }

  void selectChatById(String chatId) {
    final chat = _chats.firstWhere(
      (c) => c.id == chatId,
      orElse: () => ChatModel(
        id: chatId,
        name: 'Unknown',
        type: ChatType.private, 
        participants: [],
        createdAt: DateTime.now(),
      ),
    );
    selectChat(chat);
  }

  // ==========================================================================
  // MESSAGING WITH AI MODERATION
  // ==========================================================================

  Future<ModerationResult?> sendMessage(String content, {MessageType type = MessageType.text}) async {
    if (_selectedChat == null) return null;
    if (content.trim().isEmpty) return null;

    // 1. Check user ban status first
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId != null) {
      final strikeStatus = await _moderationService.checkUserStrikes(currentUserId);
      if (strikeStatus.isBanned) {
        return ModerationResult(
          isFlagged: true,
          flag: ContentFlag.none,
          reason: 'You are banned: ${strikeStatus.statusText}',
          confidence: 1.0,
          action: ModerationAction.block,
        );
      }
    }

    // 2. AI Moderation scan
    if (_aiModerationEnabled) {
      final moderationResult = await _moderationService.scanMessage(content, type: type);

      if (moderationResult.action == ModerationAction.block) {
        // Block message entirely
        if (currentUserId != null) {
          await _moderationService.addStrike(currentUserId, moderationResult.flag);
        }
        return moderationResult;
      }

      if (moderationResult.action == ModerationAction.restrict) {
        // Send but flag it
        await _sendWithFlag(content, type, moderationResult);
        return moderationResult;
      }

      if (moderationResult.action == ModerationAction.warn) {
        // Allow but warn user
        await _sendNormal(content, type);
        return moderationResult;
      }
    }

    // 3. Normal send
    await _sendNormal(content, type);
    return ModerationResult.clean();
  }

  Future<void> _sendNormal(String content, MessageType type) async {
    final chatId = _selectedChat!.id;

    final tempMessage = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      content: content,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    _messages.add(tempMessage);
    notifyListeners();

    try {
      await _firebaseService.sendMessage(
        chatId: chatId,
        content: content,
        type: type,
      );

      _messages.removeWhere((m) => m.id == tempMessage.id);
      notifyListeners();
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == tempMessage.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
    }
  }

  Future<void> _sendWithFlag(String content, MessageType type, ModerationResult moderation) async {
    final chatId = _selectedChat!.id;

    final tempMessage = MessageModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: 'me',
      content: content,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      contentFlag: moderation.flag,
      isRestricted: true,
      restrictionNote: moderation.reason,
    );

    _messages.add(tempMessage);
    notifyListeners();

    try {
      await _firebaseService.sendMessage(
        chatId: chatId,
        content: content,
        type: type,
      );

      _messages.removeWhere((m) => m.id == tempMessage.id);
      notifyListeners();
    } catch (e) {
      final index = _messages.indexWhere((m) => m.id == tempMessage.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
    }
  }

  Future<void> retryFailedMessage(String messageId) async {
    final message = _messages.firstWhere((m) => m.id == messageId);
    if (message.status != MessageStatus.failed) return;

    final index = _messages.indexWhere((m) => m.id == messageId);
    _messages[index] = message.copyWith(status: MessageStatus.sending);
    notifyListeners();

    try {
      await _firebaseService.sendMessage(
        chatId: message.chatId,
        content: message.content,
        type: message.type,
      );
      _messages.removeAt(index);
      notifyListeners();
    } catch (e) {
      _messages[index] = message.copyWith(status: MessageStatus.failed);
      notifyListeners();
    }
  }

  // ==========================================================================
  // TYPING
  // ==========================================================================

  Timer? _typingTimer;

  void setTyping(bool isTyping) {
    if (_selectedChat == null) return;

    _firebaseService.setTypingStatus(_selectedChat!.id, isTyping);

    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _firebaseService.setTypingStatus(_selectedChat!.id, false);
      });
    }
  }

  // ==========================================================================
  // CHAT ACTIONS
  // ==========================================================================

  Future<void> createDirectChat(String otherUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final chatId = await _firebaseService.createDirectChat(otherUserId);
      await refreshChats();

      final newChat = _chats.firstWhere((c) => c.id == chatId);
      selectChat(newChat);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createGroupChat({
    required String name,
    String? description,
    required List<String> memberIds,
    bool isPublic = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.createGroupChat(
        name: name,
        description: description,
        memberIds: memberIds,
        isPublic: isPublic,
      );
      await refreshChats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.createChannel(
        name: name,
        description: description,
        isPublic: isPublic,
      );
      await refreshChats();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addChat(ChatModel chat) {
    if (!_chats.any((c) => c.id == chat.id)) {
      _chats.add(chat);
      notifyListeners();
    }
  }

  void pinChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isPinned: !_chats[index].isPinned);
      notifyListeners();
    }
  }

  void archiveChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isArchived: true);
      notifyListeners();
    }
  }

  void markAsRead(String chatId) {
    _firebaseService.markAsRead(chatId);

    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void clearAllChats() {
    _chats = [];
    _messages = [];
    _selectedChat = null;
    notifyListeners();
  }

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<ChatModel> _filterChats(List<ChatModel> chats) {
    if (_searchQuery == null || _searchQuery!.isEmpty) return chats;

    final query = _searchQuery!.toLowerCase();
    return chats.where((chat) {
      return chat.displayName.toLowerCase().contains(query) ||
          chat.participants.any((p) => 
             (p.username ?? '').toLowerCase().contains(query) ||  // ✅ FIX 2: Added || and null-safe
              p.displayName.toLowerCase().contains(query));
    }).toList();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    return await _firebaseService.searchUsers(query);
  }

  // ==========================================================================
  // MODERATION
  // ==========================================================================

  Future<void> reportMessage({
    required String messageId,
    required String reason,
    String? details,
  }) async {
    if (_selectedChat == null) return;

    await _moderationService.reportMessage(
      messageId: messageId,
      chatId: _selectedChat!.id,
      reporterId: _firebaseService.currentUserId ?? 'unknown',
      reason: reason,
      details: details,
    );
  }

  Future<UserStrikeStatus> checkMyStrikes() async {
    final userId = _firebaseService.currentUserId;
    if (userId == null) return UserStrikeStatus(strikes: 0, isBanned: false);
    return await _moderationService.checkUserStrikes(userId);
  }

  // ==========================================================================
  // CLEANUP
  // ==========================================================================

    @override
  void dispose() {
    _chatsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _firebaseService.dispose();
    super.dispose();
  }

  // ========== ARCHIVED CHATS ==========
  
  List<ChatModel> get archivedChats => _chats.where((c) => c.isArchived).toList();

  void unarchiveChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isArchived: false);
      notifyListeners();
    }
  }

  // ========== MUTE DURATION ENUM ==========
  
  void muteChat(String chatId, ChatMuteDuration duration) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isMuted: true);
      notifyListeners();
    }
  }
}

// Enum goes OUTSIDE the class
enum ChatMuteDuration { oneHour, eightHours, twoDays, forever }
