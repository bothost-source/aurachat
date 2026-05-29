import 'package:flutter/foundation.dart';
import 'message_model.dart';
import 'user_model.dart';

enum ChatType { private, group, channel, bot, self, secret }
enum ChatMuteDuration { off, oneHour, eightHours, twoDays, forever }

@immutable
class ChatModel {
  final String id;
  final ChatType type;
  final String name;
  final String? description;
  final String? avatarUrl;
  final List<UserModel> participants;
  final List<String> adminIds;
  final List<String> moderatorIds;
  final String? creatorId;
  final MessageModel? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final int pinOrder;
  final bool isArchived;
  final bool isMuted;
  final ChatMuteDuration muteDuration;
  final DateTime? muteExpiry;
  final bool isBlocked;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Group/Channel specific
  final String? inviteLink;
  final bool isPublic;
  final int? memberCount;
  final int? subscriberCount;
  final bool allowComments;
  final bool slowMode;
  final int? slowModeDelay;
  final bool signaturesEnabled;
  final bool reactionsEnabled;
  final bool pollsEnabled;

  // Self-chat specific
  final bool isSelfChat;
  final String? selfChatLabel;

  // Secret chat specific
  final bool isSecret;
  final DateTime? secretChatExpiry;
  final bool selfDestructEnabled;
  final int? selfDestructTimer;

  const ChatModel({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    this.avatarUrl,
    this.participants = const [],
    this.adminIds = const [],
    this.moderatorIds = const [],
    this.creatorId,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.pinOrder = 0,
    this.isArchived = false,
    this.isMuted = false,
    this.muteDuration = ChatMuteDuration.off,
    this.muteExpiry,
    this.isBlocked = false,
    required this.createdAt,
    this.updatedAt,
    this.inviteLink,
    this.isPublic = false,
    this.memberCount,
    this.subscriberCount,
    this.allowComments = true,
    this.slowMode = false,
    this.slowModeDelay,
    this.signaturesEnabled = false,
    this.reactionsEnabled = true,
    this.pollsEnabled = true,
    this.isSelfChat = false,
    this.selfChatLabel,
    this.isSecret = false,
    this.secretChatExpiry,
    this.selfDestructEnabled = false,
    this.selfDestructTimer,
  });

  bool get isGroup => type == ChatType.group;
  bool get isChannel => type == ChatType.channel;
  bool get isPrivate => type == ChatType.private;
  bool get isBotChat => type == ChatType.bot;
  bool get isSecretChat => type == ChatType.secret;

  String get displayName {
    if (isSelfChat) return selfChatLabel ?? 'Saved Messages';
    if (participants.length == 1 && isPrivate) return participants.first.displayName;
    return name;
  }

  String get subtitle {
    if (lastMessage == null) return '';
    if (lastMessage!.isDeleted) return 'This message was deleted';
    if (lastMessage!.isRestricted) return '⚠️ Restricted content';
    if (lastMessage!.type == MessageType.image) return '📷 Photo';
    if (lastMessage!.type == MessageType.video) return '🎥 Video';
    if (lastMessage!.type == MessageType.audio) return '🎵 Audio';
    if (lastMessage!.type == MessageType.document) return '📎 ${lastMessage!.fileName}';
    if (lastMessage!.type == MessageType.voice) return '🎙️ Voice message';
    if (lastMessage!.type == MessageType.location) return '📍 Location';
    if (lastMessage!.type == MessageType.poll) return '📊 Poll';
    return lastMessage!.content;
  }

  String get timeString {
    if (lastMessage == null) return '';
    final now = DateTime.now();
    final msgTime = lastMessage!.createdAt;
    final diff = now.difference(msgTime);

    if (diff.inDays == 0) {
      final hour = msgTime.hour.toString().padLeft(2, '0');
      final minute = msgTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[msgTime.weekday - 1];
    } else {
      return '${msgTime.day}/${msgTime.month}';
    }
  }

  ChatModel copyWith({
    String? id,
    ChatType? type,
    String? name,
    String? description,
    String? avatarUrl,
    List<UserModel>? participants,
    List<String>? adminIds,
    List<String>? moderatorIds,
    String? creatorId,
    MessageModel? lastMessage,
    int? unreadCount,
    bool? isPinned,
    int? pinOrder,
    bool? isArchived,
    bool? isMuted,
    ChatMuteDuration? muteDuration,
    DateTime? muteExpiry,
    bool? isBlocked,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? inviteLink,
    bool? isPublic,
    int? memberCount,
    int? subscriberCount,
    bool? allowComments,
    bool? slowMode,
    int? slowModeDelay,
    bool? signaturesEnabled,
    bool? reactionsEnabled,
    bool? pollsEnabled,
    bool? isSelfChat,
    String? selfChatLabel,
    bool? isSecret,
    DateTime? secretChatExpiry,
    bool? selfDestructEnabled,
    int? selfDestructTimer,
  }) {
    return ChatModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants ?? this.participants,
      adminIds: adminIds ?? this.adminIds,
      moderatorIds: moderatorIds ?? this.moderatorIds,
      creatorId: creatorId ?? this.creatorId,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      pinOrder: pinOrder ?? this.pinOrder,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      muteDuration: muteDuration ?? this.muteDuration,
      muteExpiry: muteExpiry ?? this.muteExpiry,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      inviteLink: inviteLink ?? this.inviteLink,
      isPublic: isPublic ?? this.isPublic,
      memberCount: memberCount ?? this.memberCount,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      allowComments: allowComments ?? this.allowComments,
      slowMode: slowMode ?? this.slowMode,
      slowModeDelay: slowModeDelay ?? this.slowModeDelay,
      signaturesEnabled: signaturesEnabled ?? this.signaturesEnabled,
      reactionsEnabled: reactionsEnabled ?? this.reactionsEnabled,
      pollsEnabled: pollsEnabled ?? this.pollsEnabled,
      isSelfChat: isSelfChat ?? this.isSelfChat,
      selfChatLabel: selfChatLabel ?? this.selfChatLabel,
      isSecret: isSecret ?? this.isSecret,
      secretChatExpiry: secretChatExpiry ?? this.secretChatExpiry,
      selfDestructEnabled: selfDestructEnabled ?? this.selfDestructEnabled,
      selfDestructTimer: selfDestructTimer ?? this.selfDestructTimer,
    );
  }
}
