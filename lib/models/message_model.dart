import 'package:flutter/foundation.dart';

enum MessageType { text, image, video, audio, document, location, contact, sticker, poll, forwarded, reply, botCommand, system }
enum MessageStatus { sending, sent, delivered, read, failed }
enum ContentFlag { none, spam, illegal, harassment, violence, explicit, misinformation, copyright }

@immutable
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final String? mediaThumbnail;
  final String? fileName;
  final int? fileSize;
  final int? duration; // For audio/video in seconds
  final double? latitude;
  final double? longitude;
  final String? replyToMessageId;
  final MessageModel? replyToMessage;
  final String? forwardFromChatId;
  final String? forwardFromMessageId;
  final String? forwardFromName;
  final List<String> reactions;
  final Map<String, int>? pollOptions;
  final Map<String, List<String>>? pollVotes;
  final bool isEdited;
  final DateTime? editedAt;
  final MessageStatus status;
  final DateTime createdAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool isPinned;
  final int? pinOrder;
  final ContentFlag contentFlag;
  final double? aiSafetyScore;
  final String? aiFlagReason;
  final bool isRestricted;
  final String? restrictionNote;
  final List<String> readBy;
  final List<String> deliveredTo;
  final Map<String, dynamic>? metadata;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    this.type = MessageType.text,
    required this.content,
    this.mediaUrl,
    this.mediaThumbnail,
    this.fileName,
    this.fileSize,
    this.duration,
    this.latitude,
    this.longitude,
    this.replyToMessageId,
    this.replyToMessage,
    this.forwardFromChatId,
    this.forwardFromMessageId,
    this.forwardFromName,
    this.reactions = const [],
    this.pollOptions,
    this.pollVotes,
    this.isEdited = false,
    this.editedAt,
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
    this.isPinned = false,
    this.pinOrder,
    this.contentFlag = ContentFlag.none,
    this.aiSafetyScore,
    this.aiFlagReason,
    this.isRestricted = false,
    this.restrictionNote,
    this.readBy = const [],
    this.deliveredTo = const [],
    this.metadata,
  });

  bool get isMedia => type == MessageType.image || type == MessageType.video || type == MessageType.audio || type == MessageType.document;
  bool get isTextOnly => type == MessageType.text && !isMedia;
  bool get hasReactions => reactions.isNotEmpty;
  bool get isForwarded => forwardFromMessageId != null;
  bool get isReply => replyToMessageId != null;
  bool get isPoll => type == MessageType.poll;
  bool get isSystem => type == MessageType.system;
  bool get isFlaggedByAI => contentFlag != ContentFlag.none || aiSafetyScore != null;

  String get formattedTime {
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get statusIcon {
    switch (status) {
      case MessageStatus.sending: return '⏳';
      case MessageStatus.sent: return '✓';
      case MessageStatus.delivered: return '✓✓';
      case MessageStatus.read: return '✓✓';
      case MessageStatus.failed: return '!';
    }
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    String? mediaUrl,
    String? mediaThumbnail,
    String? fileName,
    int? fileSize,
    int? duration,
    double? latitude,
    double? longitude,
    String? replyToMessageId,
    MessageModel? replyToMessage,
    String? forwardFromChatId,
    String? forwardFromMessageId,
    String? forwardFromName,
    List<String>? reactions,
    Map<String, int>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool? isEdited,
    DateTime? editedAt,
    MessageStatus? status,
    DateTime? createdAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool? isPinned,
    int? pinOrder,
    ContentFlag? contentFlag,
    double? aiSafetyScore,
    String? aiFlagReason,
    bool? isRestricted,
    String? restrictionNote,
    List<String>? readBy,
    List<String>? deliveredTo,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnail: mediaThumbnail ?? this.mediaThumbnail,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessage: replyToMessage ?? this.replyToMessage,
      forwardFromChatId: forwardFromChatId ?? this.forwardFromChatId,
      forwardFromMessageId: forwardFromMessageId ?? this.forwardFromMessageId,
      forwardFromName: forwardFromName ?? this.forwardFromName,
      reactions: reactions ?? this.reactions,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      isPinned: isPinned ?? this.isPinned,
      pinOrder: pinOrder ?? this.pinOrder,
      contentFlag: contentFlag ?? this.contentFlag,
      aiSafetyScore: aiSafetyScore ?? this.aiSafetyScore,
      aiFlagReason: aiFlagReason ?? this.aiFlagReason,
      isRestricted: isRestricted ?? this.isRestricted,
      restrictionNote: restrictionNote ?? this.restrictionNote,
      readBy: readBy ?? this.readBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chatId': chatId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'type': type.name,
    'content': content,
    'mediaUrl': mediaUrl,
    'mediaThumbnail': mediaThumbnail,
    'fileName': fileName,
    'fileSize': fileSize,
    'duration': duration,
    'latitude': latitude,
    'longitude': longitude,
    'replyToMessageId': replyToMessageId,
    'replyToMessage': replyToMessage?.toJson(),
    'forwardFromChatId': forwardFromChatId,
    'forwardFromMessageId': forwardFromMessageId,
    'forwardFromName': forwardFromName,
    'reactions': reactions,
    'pollOptions': pollOptions,
    'pollVotes': pollVotes,
    'isEdited': isEdited,
    'editedAt': editedAt?.toIso8601String(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'isPinned': isPinned,
    'pinOrder': pinOrder,
    'contentFlag': contentFlag.name,
    'aiSafetyScore': aiSafetyScore,
    'aiFlagReason': aiFlagReason,
    'isRestricted': isRestricted,
    'restrictionNote': restrictionNote,
    'readBy': readBy,
    'deliveredTo': deliveredTo,
    'metadata': metadata,
  };
}
