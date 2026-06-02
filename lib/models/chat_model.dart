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

  // NEW: Demo flag to filter out fake chats
  final bool isDemo;

  // NEW: Online count for groups/channels
  final int onlineCount;

  // NEW: Members list for groups
  final List<GroupMember> members;

  // NEW: Subscribers list for channels
  final List<GroupMember> subscribers;

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
    // NEW fields with defaults
    this.isDemo = false,
    this.onlineCount = 0,
    this.members = const [],
    this.subscribers = const [],
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
    if (lastMessage == null) {
      if (isGroup) return '\$memberCount members';
      if (isChannel) return '\$subscriberCount subscribers';
      return '';
    }
    if (lastMessage!.isDeleted) return 'This message was deleted';
    if (lastMessage!.isRestricted) return '⚠️ Restricted content';
    if (lastMessage!.type == MessageType.image) return '📷 Photo';
    if (lastMessage!.type == MessageType.video) return '🎥 Video';
    if (lastMessage!.type == MessageType.audio) return '🎵 Audio';
    if (lastMessage!.type == MessageType.document) return '📎 \${lastMessage!.fileName}';
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
      return '\$hour:\$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[msgTime.weekday - 1];
    } else {
      return '\${msgTime.day}/\${msgTime.month}';
    }
  }

  // ==========================================================================
  // JSON SERIALIZATION
  // ==========================================================================

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      type: ChatType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'private'),
        orElse: () => ChatType.private,
      ),
      name: json['name'] as String? ?? 'Unknown',
      description: json['description'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      participants: (json['participants'] as List<dynamic>?)
          ?.map((p) => UserModel.fromJson(p as Map<String, dynamic>))
          .toList() ?? [],
      adminIds: (json['admin_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      moderatorIds: (json['moderator_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      creatorId: json['creator_id'] as String?,
      lastMessage: json['last_message'] != null
          ? MessageModel.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      pinOrder: json['pin_order'] as int? ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      muteDuration: ChatMuteDuration.values.firstWhere(
        (e) => e.name == (json['mute_duration'] as String? ?? 'off'),
        orElse: () => ChatMuteDuration.off,
      ),
      muteExpiry: json['mute_expiry'] != null
          ? DateTime.parse(json['mute_expiry'] as String)
          : null,
      isBlocked: json['is_blocked'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      inviteLink: json['invite_link'] as String?,
      isPublic: json['is_public'] as bool? ?? false,
      memberCount: json['member_count'] as int?,
      subscriberCount: json['subscriber_count'] as int?,
      allowComments: json['allow_comments'] as bool? ?? true,
      slowMode: json['slow_mode'] as bool? ?? false,
      slowModeDelay: json['slow_mode_delay'] as int?,
      signaturesEnabled: json['signatures_enabled'] as bool? ?? false,
      reactionsEnabled: json['reactions_enabled'] as bool? ?? true,
      pollsEnabled: json['polls_enabled'] as bool? ?? true,
      isSelfChat: json['is_self_chat'] as bool? ?? false,
      selfChatLabel: json['self_chat_label'] as String?,
      isSecret: json['is_secret'] as bool? ?? false,
      secretChatExpiry: json['secret_chat_expiry'] != null
          ? DateTime.parse(json['secret_chat_expiry'] as String)
          : null,
      selfDestructEnabled: json['self_destruct_enabled'] as bool? ?? false,
      selfDestructTimer: json['self_destruct_timer'] as int?,
      isDemo: json['is_demo'] as bool? ?? false,
      onlineCount: json['online_count'] as int? ?? 0,
      members: (json['members'] as List<dynamic>?)
          ?.map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      subscribers: (json['subscribers'] as List<dynamic>?)
          ?.map((s) => GroupMember.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'participants': participants.map((p) => p.toJson()).toList(),
      'admin_ids': adminIds,
      'moderator_ids': moderatorIds,
      'creator_id': creatorId,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'is_pinned': isPinned,
      'pin_order': pinOrder,
      'is_archived': isArchived,
      'is_muted': isMuted,
      'mute_duration': muteDuration.name,
      'mute_expiry': muteExpiry?.toIso8601String(),
      'is_blocked': isBlocked,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'invite_link': inviteLink,
      'is_public': isPublic,
      'member_count': memberCount,
      'subscriber_count': subscriberCount,
      'allow_comments': allowComments,
      'slow_mode': slowMode,
      'slow_mode_delay': slowModeDelay,
      'signatures_enabled': signaturesEnabled,
      'reactions_enabled': reactionsEnabled,
      'polls_enabled': pollsEnabled,
      'is_self_chat': isSelfChat,
      'self_chat_label': selfChatLabel,
      'is_secret': isSecret,
      'secret_chat_expiry': secretChatExpiry?.toIso8601String(),
      'self_destruct_enabled': selfDestructEnabled,
      'self_destruct_timer': selfDestructTimer,
      'is_demo': isDemo,
      'online_count': onlineCount,
      'members': members.map((m) => m.toJson()).toList(),
      'subscribers': subscribers.map((s) => s.toJson()).toList(),
    };
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
    // NEW copyWith params
    bool? isDemo,
    int? onlineCount,
    List<GroupMember>? members,
    List<GroupMember>? subscribers,
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
      // NEW
      isDemo: isDemo ?? this.isDemo,
      onlineCount: onlineCount ?? this.onlineCount,
      members: members ?? this.members,
      subscribers: subscribers ?? this.subscribers,
    );
  }
}

// ============================================================================
// GROUP MEMBER
// ============================================================================
@immutable
class GroupMember {
  final String id;
  final String name;
  final String? photoUrl;
  final MemberRole role;
  final bool isOnline;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.name,
    this.photoUrl,
    this.role = MemberRole.member,
    this.isOnline = false,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String?,
      role: MemberRole.values.firstWhere(
        (e) => e.name == (json['role'] as String? ?? 'member'),
        orElse: () => MemberRole.member,
      ),
      isOnline: json['is_online'] as bool? ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photo_url': photoUrl,
      'role': role.name,
      'is_online': isOnline,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  GroupMember copyWith({
    String? id,
    String? name,
    String? photoUrl,
    MemberRole? role,
    bool? isOnline,
    DateTime? joinedAt,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

enum MemberRole {
  admin,
  moderator,
  member,
}
