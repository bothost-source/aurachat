import 'package:flutter/foundation.dart';

enum BotStatus { draft, pending, active, suspended, banned }
enum BotCapability { messaging, inline, payments, games, stickers, customKeyboard }

@immutable
class BotModel {
  final String botId;
  final String name;
  final String username;
  final String? description;
  final String? avatarUrl;
  final String? about;
  final List<String> commands;
  final Map<String, String> commandDescriptions;
  final BotStatus status;
  final String ownerId;
  final String? token;
  final List<BotCapability> capabilities;
  final bool inlineMode;
  final bool groupPrivacy;
  final bool canJoinGroups;
  final bool canReadAllGroupMessages;
  final int subscriberCount;
  final int messageCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastActivity;
  final String? webhookUrl;
  final bool aiPowered;
  final String? aiModel;
  final Map<String, dynamic>? aiConfig;
  final bool autoReply;
  final List<String> autoReplyKeywords;
  final bool moderationEnabled;
  final List<String> allowedDomains;
  final List<String> blockedDomains;
  final Map<String, dynamic>? analytics;

  const BotModel({
    required this.botId,
    required this.name,
    required this.username,
    this.description,
    this.avatarUrl,
    this.about,
    this.commands = const [],
    this.commandDescriptions = const {},
    this.status = BotStatus.draft,
    required this.ownerId,
    this.token,
    this.capabilities = const [],
    this.inlineMode = false,
    this.groupPrivacy = true,
    this.canJoinGroups = true,
    this.canReadAllGroupMessages = false,
    this.subscriberCount = 0,
    this.messageCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.lastActivity,
    this.webhookUrl,
    this.aiPowered = false,
    this.aiModel,
    this.aiConfig,
    this.autoReply = false,
    this.autoReplyKeywords = const [],
    this.moderationEnabled = true,
    this.allowedDomains = const [],
    this.blockedDomains = const [],
    this.analytics,
  });

  bool get isActive => status == BotStatus.active;
  bool get canBeEdited => status == BotStatus.draft || status == BotStatus.active;
  String get botUrl => 'https://tarrific.chat/$username';
  String get mention => '@$username';

  BotModel copyWith({
    String? id,
    String? name,
    String? username,
    String? description,
    String? avatarUrl,
    String? about,
    List<String>? commands,
    Map<String, String>? commandDescriptions,
    BotStatus? status,
    String? ownerId,
    String? token,
    List<BotCapability>? capabilities,
    bool? inlineMode,
    bool? groupPrivacy,
    bool? canJoinGroups,
    bool? canReadAllGroupMessages,
    int? subscriberCount,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastActivity,
    String? webhookUrl,
    bool? aiPowered,
    String? aiModel,
    Map<String, dynamic>? aiConfig,
    bool? autoReply,
    List<String>? autoReplyKeywords,
    bool? moderationEnabled,
    List<String>? allowedDomains,
    List<String>? blockedDomains,
    Map<String, dynamic>? analytics,
  }) {
    return BotModel(
      botId: Id ?? this.botId,
      name: name ?? this.name,
      username: username ?? this.username,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      about: about ?? this.about,
      commands: commands ?? this.commands,
      commandDescriptions: commandDescriptions ?? this.commandDescriptions,
      status: status ?? this.status,
      ownerId: ownerId ?? this.ownerId,
      token: token ?? this.token,
      capabilities: capabilities ?? this.capabilities,
      inlineMode: inlineMode ?? this.inlineMode,
      groupPrivacy: groupPrivacy ?? this.groupPrivacy,
      canJoinGroups: canJoinGroups ?? this.canJoinGroups,
      canReadAllGroupMessages: canReadAllGroupMessages ?? this.canReadAllGroupMessages,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      aiPowered: aiPowered ?? this.aiPowered,
      aiModel: aiModel ?? this.aiModel,
      aiConfig: aiConfig ?? this.aiConfig,
      autoReply: autoReply ?? this.autoReply,
      autoReplyKeywords: autoReplyKeywords ?? this.autoReplyKeywords,
      moderationEnabled: moderationEnabled ?? this.moderationEnabled,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      blockedDomains: blockedDomains ?? this.blockedDomains,
      analytics: analytics ?? this.analytics,
    );
  }
}
