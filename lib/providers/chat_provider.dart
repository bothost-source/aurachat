import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class ChatProvider extends ChangeNotifier {
  List<<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  ChatModel? _selectedChat;
  bool _isLoading = false;
  String? _searchQuery;

  List<<ChatModel> get chats => _searchQuery == null || _searchQuery!.isEmpty
      ? _chats
      : _chats.where((c) => 
          c.displayName.toLowerCase().contains(_searchQuery!.toLowerCase()) ||
          (c.lastMessage?.content.toLowerCase().contains(_searchQuery!.toLowerCase()) ?? false)
        ).toList();

  List<<ChatModel> get pinnedChats => chats.where((c) => c.isPinned).toList();
  List<<ChatModel> get unpinnedChats => chats.where((c) => !c.isPinned).toList();
  List<<ChatModel> get archivedChats => _chats.where((c) => c.isArchived).toList();
  int get totalUnread => _chats.fold(0, (sum, c) => sum + c.unreadCount);
  ChatModel? get selectedChat => _selectedChat;
  bool get isLoading => _isLoading;
  List<MessageModel> get messages => _messages;

  ChatProvider() {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    final me = UserModel(
      id: 'me',
      phoneNumber: '+2348012345678',
      username: 'tarrific_user',
      displayName: 'You',
      status: UserStatus.online,
      createdAt: now.subtract(const Duration(days: 30)),
    );

    final danny = UserModel(
      id: 'danny',
      phoneNumber: '+2348098765432',
      username: 'danny_dev',
      displayName: 'DANNY',
      bio: 'Backend Developer | TARRIFIC',
      status: UserStatus.online,
      verificationLevel: VerificationLevel.verified,
      createdAt: now.subtract(const Duration(days: 60)),
    );

    final nicky = UserModel(
      id: 'nicky',
      phoneNumber: '+2348076543210',
      username: 'nicky_tech',
      displayName: 'NICKY TECH',
      bio: 'Mobile Developer | AI Explorer',
      status: UserStatus.recently,
      verificationLevel: VerificationLevel.verified,
      createdAt: now.subtract(const Duration(days: 45)),
    );

    final zeus = UserModel(
      id: 'zeus',
      phoneNumber: '+2348065432109',
      username: 'zeus_ai',
      displayName: 'ZEUS',
      bio: 'AI Engineer | TARRIFIC',
      status: UserStatus.offline,
      lastSeen: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(days: 50)),
    );

    final gui = UserModel(
      id: 'gui',
      phoneNumber: '+2348054321098',
      username: 'gui_vii',
      displayName: 'GUI - VII',
      bio: 'UI/UX Designer | TARRIFIC',
      status: UserStatus.online,
      createdAt: now.subtract(const Duration(days: 40)),
    );

    _chats = [
      // Self-chat (Saved Messages)
      ChatModel(
        id: 'self_chat',
        type: ChatType.self,
        name: 'Saved Messages',
        isSelfChat: true,
        selfChatLabel: 'Saved Messages',
        participants: [me],
        lastMessage: MessageModel(
          id: 'msg_1',
          chatId: 'self_chat',
          senderId: 'me',
          type: MessageType.text,
          content: 'Remember to check the new UI update',
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(minutes: 30)),
          readBy: ['me'],
        ),
        unreadCount: 0,
        isPinned: true,
        pinOrder: 1,
        createdAt: now.subtract(const Duration(days: 30)),
      ),

      // Private chats
      ChatModel(
        id: 'chat_danny',
        type: ChatType.private,
        name: 'DANNY',
        participants: [danny],
        lastMessage: MessageModel(
          id: 'msg_2',
          chatId: 'chat_danny',
          senderId: 'danny',
          senderName: 'DANNY',
          type: MessageType.text,
          content: 'Check the new UI update. It looks fire! 🔥',
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(minutes: 45)),
          readBy: ['me'],
        ),
        unreadCount: 0,
        isPinned: true,
        pinOrder: 2,
        createdAt: now.subtract(const Duration(days: 20)),
      ),

      ChatModel(
        id: 'chat_nicky',
        type: ChatType.private,
        name: 'NICKY TECH',
        participants: [nicky],
        lastMessage: MessageModel(
          id: 'msg_3',
          chatId: 'chat_nicky',
          senderId: 'nicky',
          senderName: 'NICKY TECH',
          type: MessageType.text,
          content: 'This feature is awesome! The AI moderation is working perfectly.',
          status: MessageStatus.delivered,
          createdAt: now.subtract(const Duration(hours: 2)),
          deliveredTo: ['me'],
        ),
        unreadCount: 2,
        isPinned: true,
        pinOrder: 3,
        createdAt: now.subtract(const Duration(days: 15)),
      ),

      ChatModel(
        id: 'chat_zeus',
        type: ChatType.private,
        name: 'ZEUS',
        participants: [zeus],
        lastMessage: MessageModel(
          id: 'msg_4',
          chatId: 'chat_zeus',
          senderId: 'zeus',
          senderName: 'ZEUS',
          type: MessageType.text,
          content: "Let's deploy it today. The bot API is ready.",
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(hours: 5)),
          readBy: ['me'],
        ),
        unreadCount: 0,
        createdAt: now.subtract(const Duration(days: 10)),
      ),

      ChatModel(
        id: 'chat_gui',
        type: ChatType.private,
        name: 'GUI - VII',
        participants: [gui],
        lastMessage: MessageModel(
          id: 'msg_5',
          chatId: 'chat_gui',
          senderId: 'gui',
          senderName: 'GUI - VII',
          type: MessageType.text,
          content: 'Working on the AI module. Need to finish the dark theme gradients.',
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(hours: 8)),
          readBy: ['me'],
        ),
        unreadCount: 0,
        createdAt: now.subtract(const Duration(days: 8)),
      ),

      // Group chat
      ChatModel(
        id: 'chat_dev_team',
        type: ChatType.group,
        name: 'Dev Team',
        description: 'TARRIFIC CHAT Development Team',
        participants: [danny, nicky, zeus, gui, me],
        adminIds: ['danny', 'me'],
        creatorId: 'danny',
        memberCount: 5,
        lastMessage: MessageModel(
          id: 'msg_6',
          chatId: 'chat_dev_team',
          senderId: 'danny',
          senderName: 'DANNY',
          type: MessageType.text,
          content: 'DANNY: Push the code to staging. We need to test the new features.',
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(hours: 12)),
          readBy: ['me', 'nicky', 'zeus'],
        ),
        unreadCount: 0,
        createdAt: now.subtract(const Duration(days: 25)),
      ),

      // Channel
      ChatModel(
        id: 'chat_updates',
        type: ChatType.channel,
        name: 'TARRIFIC Updates',
        description: 'Official updates and announcements',
        participants: [me],
        adminIds: ['nicky'],
        creatorId: 'nicky',
        subscriberCount: 12500,
        isPublic: true,
        lastMessage: MessageModel(
          id: 'msg_7',
          chatId: 'chat_updates',
          senderId: 'nicky',
          senderName: 'NICKY TECH',
          type: MessageType.text,
          content: '🚀 New features are live! Check out the AI Studio and Bot Creator.',
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(days: 1)),
          readBy: ['me'],
        ),
        unreadCount: 1,
        createdAt: now.subtract(const Duration(days: 30)),
      ),

      // Bot chat
      ChatModel(
        id: 'chat_tarrific_bot',
        type: ChatType.bot,
        name: 'TARRIFIC Bot',
        participants: [me],
        lastMessage: MessageModel(
          id: 'msg_8',
          chatId: 'chat_tarrific_bot',
          senderId: 'bot_1',
          senderName: 'TARRIFIC Bot',
          type: MessageType.text,
          content: "Hello! I'm your AI assistant. How can I help your business today?",
          status: MessageStatus.read,
          createdAt: now.subtract(const Duration(days: 2)),
          readBy: ['me'],
        ),
        unreadCount: 0,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];

    notifyListeners();
  }

  void selectChat(ChatModel chat) {
    _selectedChat = chat;
    _loadMessages(chat.id);
    notifyListeners();
  }

  void _loadMessages(String chatId) {
    final now = DateTime.now();
    _messages = [
      MessageModel(
        id: 'm1',
        chatId: chatId,
        senderId: 'other',
        senderName: 'DANNY',
        type: MessageType.text,
        content: 'Hey! Have you seen the new design mockups?',
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(hours: 3)),
        readBy: ['me'],
      ),
      MessageModel(
        id: 'm2',
        chatId: chatId,
        senderId: 'me',
        type: MessageType.text,
        content: 'Yeah, they look incredible! The dark theme is perfect.',
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 55)),
        readBy: ['other'],
      ),
      MessageModel(
        id: 'm3',
        chatId: chatId,
        senderId: 'other',
        senderName: 'DANNY',
        type: MessageType.image,
        content: '',
        mediaUrl: 'https://example.com/design.png',
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(hours: 2)),
        readBy: ['me'],
      ),
      MessageModel(
        id: 'm4',
        chatId: chatId,
        senderId: 'me',
        type: MessageType.text,
        content: 'This is exactly what we need. The green accents pop so well on the black background.',
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 50)),
        readBy: ['other'],
      ),
      MessageModel(
        id: 'm5',
        chatId: chatId,
        senderId: 'other',
        senderName: 'DANNY',
        type: MessageType.text,
        content: 'Check the new UI update. It looks fire! 🔥',
        status: MessageStatus.read,
        createdAt: now.subtract(const Duration(minutes: 45)),
        readBy: ['me'],
      ),
    ];
  }

  void sendMessage(String content, {MessageType type = MessageType.text}) {
    if (_selectedChat == null) return;

    final message = MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      chatId: _selectedChat!.id,
      senderId: 'me',
      type: type,
      content: content,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    _messages.add(message);
    notifyListeners();

    // Simulate sending
    Future.delayed(const Duration(milliseconds: 500), () {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(status: MessageStatus.sent);
        notifyListeners();
      }
    });

    Future.delayed(const Duration(seconds: 2), () {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.delivered,
          deliveredTo: ['other'],
        );
        notifyListeners();
      }
    });
  }

  void pinChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isPinned: true, pinOrder: _chats.where((c) => c.isPinned).length + 1);
      notifyListeners();
    }
  }

  void unpinChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isPinned: false, pinOrder: 0);
      notifyListeners();
    }
  }

  void archiveChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isArchived: true, isPinned: false);
      notifyListeners();
    }
  }

  void unarchiveChat(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isArchived: false);
      notifyListeners();
    }
  }

  void deleteChat(String chatId) {
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
  }

  void markAsRead(String chatId) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void muteChat(String chatId, ChatMuteDuration duration) {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      DateTime? expiry;
      final now = DateTime.now();
      switch (duration) {
        case ChatMuteDuration.oneHour:
          expiry = now.add(const Duration(hours: 1));
          break;
        case ChatMuteDuration.eightHours:
          expiry = now.add(const Duration(hours: 8));
          break;
        case ChatMuteDuration.twoDays:
          expiry = now.add(const Duration(days: 2));
          break;
        case ChatMuteDuration.forever:
          expiry = null;
          break;
        default:
          break;
      }
      _chats[index] = _chats[index].copyWith(
        isMuted: duration != ChatMuteDuration.off,
        muteDuration: duration,
        muteExpiry: expiry,
      );
      notifyListeners();
    }
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }
}
