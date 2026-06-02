import 'package:flutter/foundation.dart';

enum MessageType { text, image, video, audio, voice, document, location, contact, sticker, poll, forwarded, reply, botCommand, system }
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
    return '\$hour:\$minute';
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

  // Check if message is read by a specific user
  bool isReadBy(String userId) => readBy.contains(userId);

  // Check if message is delivered to a specific user
  bool isDeliveredTo(String userId) => deliveredTo.contains(userId);

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

  // Convert to JSON for Supabase (snake_case)
  Map<String, dynamic> toJson() => {
    'id': id,
    'chat_id': chatId,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_avatar': senderAvatar,
    'type': type.name,
    'content': content,
    'media_url': mediaUrl,
    'media_thumbnail': mediaThumbnail,
    'file_name': fileName,
    'file_size': fileSize,
    'duration': duration,
    'latitude': latitude,
    'longitude': longitude,
    'reply_to_message_id': replyToMessageId,
    'reply_to_message': replyToMessage?.toJson(),
    'forward_from_chat_id': forwardFromChatId,
    'forward_from_message_id': forwardFromMessageId,
    'forward_from_name': forwardFromName,
    'reactions': reactions,
    'poll_options': pollOptions,
    'poll_votes': pollVotes?.map((k, v) => MapEntry(k, v)),
    'is_edited': isEdited,
    'edited_at': editedAt?.toIso8601String(),
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'is_deleted': isDeleted,
    'deleted_at': deletedAt?.toIso8601String(),
    'is_pinned': isPinned,
    'pin_order': pinOrder,
    'content_flag': contentFlag.name,
    'ai_safety_score': aiSafetyScore,
    'ai_flag_reason': aiFlagReason,
    'is_restricted': isRestricted,
    'restriction_note': restrictionNote,
    'read_by': readBy,
    'delivered_to': deliveredTo,
    'metadata': metadata,
  };

  // Create from JSON from Supabase (snake_case)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? '',
      chatId: json['chat_id'] ?? json['chatId'] ?? '',
      senderId: json['sender_id'] ?? json['senderId'] ?? '',
      senderName: json['sender_name'] ?? json['senderName'],
      senderAvatar: json['sender_avatar'] ?? json['senderAvatar'],
      type: _parseType(json['type']),
      content: json['content'] ?? '',
      mediaUrl: json['media_url'] ?? json['mediaUrl'],
      mediaThumbnail: json['media_thumbnail'] ?? json['mediaThumbnail'],
      fileName: json['file_name'] ?? json['fileName'],
      fileSize: json['file_size'] ?? json['fileSize'],
      duration: json['duration'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      replyToMessageId: json['reply_to_message_id'] ?? json['replyToMessageId'],
      replyToMessage: json['reply_to_message'] != null 
          ? MessageModel.fromJson(json['reply_to_message'] as Map<String, dynamic>)
          : json['replyToMessage'] != null 
              ? MessageModel.fromJson(json['replyToMessage'] as Map<String, dynamic>)
              : null,
      forwardFromChatId: json['forward_from_chat_id'] ?? json['forwardFromChatId'],
      forwardFromMessageId: json['forward_from_message_id'] ?? json['forwardFromMessageId'],
      forwardFromName: json['forward_from_name'] ?? json['forwardFromName'],
      reactions: (json['reactions'] as List<dynamic>?)?.cast<String>() ?? [],
      pollOptions: json['poll_options'] != null 
          ? Map<String, int>.from(json['poll_options'])
          : json['pollOptions'] != null 
              ? Map<String, int>.from(json['pollOptions'])
              : null,
      pollVotes: json['poll_votes'] != null 
          ? (json['poll_votes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()))
          : json['pollVotes'] != null 
              ? (json['pollVotes'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()))
              : null,
      isEdited: json['is_edited'] ?? json['isEdited'] ?? false,
      editedAt: json['edited_at'] != null 
          ? DateTime.parse(json['edited_at'])
          : json['editedAt'] != null 
              ? DateTime.parse(json['editedAt'])
              : null,
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null 
              ? DateTime.parse(json['createdAt'])
              : DateTime.now(),
      isDeleted: json['is_deleted'] ?? json['isDeleted'] ?? false,
      deletedAt: json['deleted_at'] != null 
          ? DateTime.parse(json['deleted_at'])
          : json['deletedAt'] != null 
              ? DateTime.parse(json['deletedAt'])
              : null,
      isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
      pinOrder: json['pin_order'] ?? json['pinOrder'],
      contentFlag: _parseFlag(json['content_flag'] ?? json['contentFlag']),
      aiSafetyScore: json['ai_safety_score']?.toDouble() ?? json['aiSafetyScore']?.toDouble(),
      aiFlagReason: json['ai_flag_reason'] ?? json['aiFlagReason'],
      isRestricted: json['is_restricted'] ?? json['isRestricted'] ?? false,
      restrictionNote: json['restriction_note'] ?? json['restrictionNote'],
      readBy: (json['read_by'] as List<dynamic>?)?.cast<String>() ?? 
              (json['readBy'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveredTo: (json['delivered_to'] as List<dynamic>?)?.cast<String>() ?? 
                   (json['deliveredTo'] as List<dynamic>?)?.cast<String>() ?? [],
      metadata: json['metadata'],
    );
  }

  static MessageType _parseType(String? type) {
    switch (type) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'voice': return MessageType.voice;
      case 'document': return MessageType.document;
      case 'location': return MessageType.location;
      case 'contact': return MessageType.contact;
      case 'sticker': return MessageType.sticker;
      case 'poll': return MessageType.poll;
      case 'forwarded': return MessageType.forwarded;
      case 'reply': return MessageType.reply;
      case 'botCommand': return MessageType.botCommand;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'sending': return MessageStatus.sending;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      case 'failed': return MessageStatus.failed;
      default: return MessageStatus.sent;
    }
  }

  static ContentFlag _parseFlag(String? flag) {
    switch (flag) {
      case 'spam': return ContentFlag.spam;
      case 'illegal': return ContentFlag.illegal;
      case 'harassment': return ContentFlag.harassment;
      case 'violence': return ContentFlag.violence;
      case 'explicit': return ContentFlag.explicit;
      case 'misinformation': return ContentFlag.misinformation;
      case 'copyright': return ContentFlag.copyright;
      default: return ContentFlag.none;
    }
  }
}
