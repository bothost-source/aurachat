import 'package:flutter/foundation.dart';

enum UserStatus { online, offline, recently, lastSeen }
enum AccountType { personal, business, bot }
enum VerificationLevel { none, basic, verified, official }
enum PrivacySetting { everyone, contacts, nobody }
enum AccountRestriction { none, warning, limited, suspended, banned }

@immutable
class UserModel {
  final String id;
  final String phoneNumber;
  final String? username;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final AccountType accountType;
  final VerificationLevel verificationLevel;
  final UserStatus status;
  final DateTime? lastSeen;
  final bool isBot;
  final bool isPremium;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Privacy Settings
  final PrivacySetting phoneVisibility;
  final PrivacySetting lastSeenVisibility;
  final PrivacySetting profilePhotoVisibility;
  final PrivacySetting forwardMessageVisibility;
  final PrivacySetting addToGroups;
  final PrivacySetting voiceCallPermission;
  final PrivacySetting videoCallPermission;
  final bool allowFindingByPhone;
  final bool allowFindingByUsername;

  // Security
  final bool twoFactorEnabled;
  final bool passcodeEnabled;
  final bool biometricEnabled;
  final List<String> activeSessions;
  final List<String> blockedUsers;

  // Moderation
  final AccountRestriction restrictionStatus;
  final String? restrictionReason;
  final DateTime? restrictionExpiry;
  final int strikesCount;
  final bool isFlagged;
  final List<String> reportedBy;

  // Bot-specific (if accountType == bot)
  final String? botToken;
  final String? botDescription;
  final List<String>? botCommands;
  final bool botInlineMode;
  final bool botGroupPrivacy;
  final int? botSubscribers;

  // Business-specific (if accountType == business)
  final String? businessName;
  final String? businessCategory;
  final String? businessAddress;
  final String? businessHours;
  final String? businessWebsite;
  final bool businessVerified;

  const UserModel({
    required this.id,
    required this.phoneNumber,
    this.username,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.accountType = AccountType.personal,
    this.verificationLevel = VerificationLevel.none,
    this.status = UserStatus.offline,
    this.lastSeen,
    this.isBot = false,
    this.isPremium = false,
    required this.createdAt,
    this.updatedAt,
    this.phoneVisibility = PrivacySetting.contacts,
    this.lastSeenVisibility = PrivacySetting.everyone,
    this.profilePhotoVisibility = PrivacySetting.everyone,
    this.forwardMessageVisibility = PrivacySetting.everyone,
    this.addToGroups = PrivacySetting.contacts,
    this.voiceCallPermission = PrivacySetting.contacts,
    this.videoCallPermission = PrivacySetting.contacts,
    this.allowFindingByPhone = true,
    this.allowFindingByUsername = true,
    this.twoFactorEnabled = false,
    this.passcodeEnabled = false,
    this.biometricEnabled = false,
    this.activeSessions = const [],
    this.blockedUsers = const [],
    this.restrictionStatus = AccountRestriction.none,
    this.restrictionReason,
    this.restrictionExpiry,
    this.strikesCount = 0,
    this.isFlagged = false,
    this.reportedBy = const [],
    this.botToken,
    this.botDescription,
    this.botCommands,
    this.botInlineMode = false,
    this.botGroupPrivacy = true,
    this.botSubscribers,
    this.businessName,
    this.businessCategory,
    this.businessAddress,
    this.businessHours,
    this.businessWebsite,
    this.businessVerified = false,
  });

  String get publicIdentifier => username ?? phoneNumber;
  String get handle => username != null ? '@\$username' : '';

  bool get canSendMessages => restrictionStatus != AccountRestriction.suspended && 
                             restrictionStatus != AccountRestriction.banned;
  bool get canCreateBots => !isBot && canSendMessages;
  bool get canCreateChannels => canSendMessages;
  bool get canCreateGroups => canSendMessages;

  bool get isVerified => verificationLevel == VerificationLevel.verified || 
                        verificationLevel == VerificationLevel.official;
  bool get isOfficial => verificationLevel == VerificationLevel.official;

  String get verificationBadge {
    switch (verificationLevel) {
      case VerificationLevel.verified:
        return 'verified';
      case VerificationLevel.official:
        return 'official';
      default:
        return '';
    }
  }

  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    AccountType? accountType,
    VerificationLevel? verificationLevel,
    UserStatus? status,
    DateTime? lastSeen,
    bool? isBot,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? updatedAt,
    PrivacySetting? phoneVisibility,
    PrivacySetting? lastSeenVisibility,
    PrivacySetting? profilePhotoVisibility,
    PrivacySetting? forwardMessageVisibility,
    PrivacySetting? addToGroups,
    PrivacySetting? voiceCallPermission,
    PrivacySetting? videoCallPermission,
    bool? allowFindingByPhone,
    bool? allowFindingByUsername,
    bool? twoFactorEnabled,
    bool? passcodeEnabled,
    bool? biometricEnabled,
    List<String>? activeSessions,
    List<String>? blockedUsers,
    AccountRestriction? restrictionStatus,
    String? restrictionReason,
    DateTime? restrictionExpiry,
    int? strikesCount,
    bool? isFlagged,
    List<String>? reportedBy,
    String? botToken,
    String? botDescription,
    List<String>? botCommands,
    bool? botInlineMode,
    bool? botGroupPrivacy,
    int? botSubscribers,
    String? businessName,
    String? businessCategory,
    String? businessAddress,
    String? businessHours,
    String? businessWebsite,
    bool? businessVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accountType: accountType ?? this.accountType,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      isBot: isBot ?? this.isBot,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      phoneVisibility: phoneVisibility ?? this.phoneVisibility,
      lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
      profilePhotoVisibility: profilePhotoVisibility ?? this.profilePhotoVisibility,
      forwardMessageVisibility: forwardMessageVisibility ?? this.forwardMessageVisibility,
      addToGroups: addToGroups ?? this.addToGroups,
      voiceCallPermission: voiceCallPermission ?? this.voiceCallPermission,
      videoCallPermission: videoCallPermission ?? this.videoCallPermission,
      allowFindingByPhone: allowFindingByPhone ?? this.allowFindingByPhone,
      allowFindingByUsername: allowFindingByUsername ?? this.allowFindingByUsername,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      passcodeEnabled: passcodeEnabled ?? this.passcodeEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      activeSessions: activeSessions ?? this.activeSessions,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      restrictionStatus: restrictionStatus ?? this.restrictionStatus,
      restrictionReason: restrictionReason ?? this.restrictionReason,
      restrictionExpiry: restrictionExpiry ?? this.restrictionExpiry,
      strikesCount: strikesCount ?? this.strikesCount,
      isFlagged: isFlagged ?? this.isFlagged,
      reportedBy: reportedBy ?? this.reportedBy,
      botToken: botToken ?? this.botToken,
      botDescription: botDescription ?? this.botDescription,
      botCommands: botCommands ?? this.botCommands,
      botInlineMode: botInlineMode ?? this.botInlineMode,
      botGroupPrivacy: botGroupPrivacy ?? this.botGroupPrivacy,
      botSubscribers: botSubscribers ?? this.botSubscribers,
      businessName: businessName ?? this.businessName,
      businessCategory: businessCategory ?? this.businessCategory,
      businessAddress: businessAddress ?? this.businessAddress,
      businessHours: businessHours ?? this.businessHours,
      businessWebsite: businessWebsite ?? this.businessWebsite,
      businessVerified: businessVerified ?? this.businessVerified,
    );
  }

  // Convert to JSON for Supabase (snake_case)
  Map<String, dynamic> toJson() => {
    'id': id,
    'phone_number': phoneNumber,
    'username': username,
    'display_name': displayName,
    'bio': bio,
    'avatar_url': avatarUrl,
    'account_type': accountType.name,
    'verification_level': verificationLevel.name,
    'status': status.name,
    'last_seen': lastSeen?.toIso8601String(),
    'is_bot': isBot,
    'is_premium': isPremium,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'phone_visibility': phoneVisibility.name,
    'last_seen_visibility': lastSeenVisibility.name,
    'profile_photo_visibility': profilePhotoVisibility.name,
    'forward_message_visibility': forwardMessageVisibility.name,
    'add_to_groups': addToGroups.name,
    'voice_call_permission': voiceCallPermission.name,
    'video_call_permission': videoCallPermission.name,
    'allow_finding_by_phone': allowFindingByPhone,
    'allow_finding_by_username': allowFindingByUsername,
    'two_factor_enabled': twoFactorEnabled,
    'passcode_enabled': passcodeEnabled,
    'biometric_enabled': biometricEnabled,
    'active_sessions': activeSessions,
    'blocked_users': blockedUsers,
    'restriction_status': restrictionStatus.name,
    'restriction_reason': restrictionReason,
    'restriction_expiry': restrictionExpiry?.toIso8601String(),
    'strikes_count': strikesCount,
    'is_flagged': isFlagged,
    'reported_by': reportedBy,
    'bot_token': botToken,
    'bot_description': botDescription,
    'bot_commands': botCommands,
    'bot_inline_mode': botInlineMode,
    'bot_group_privacy': botGroupPrivacy,
    'bot_subscribers': botSubscribers,
    'business_name': businessName,
    'business_category': businessCategory,
    'business_address': businessAddress,
    'business_hours': businessHours,
    'business_website': businessWebsite,
    'business_verified': businessVerified,
  };

  // Create from JSON from Supabase (supports both snake_case and camelCase)
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    phoneNumber: json['phone_number'] ?? json['phoneNumber'],
    username: json['username'],
    displayName: json['display_name'] ?? json['displayName'],
    bio: json['bio'],
    avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
    accountType: AccountType.values.byName(json['account_type'] ?? json['accountType'] ?? 'personal'),
    verificationLevel: VerificationLevel.values.byName(json['verification_level'] ?? json['verificationLevel'] ?? 'none'),
    status: UserStatus.values.byName(json['status'] ?? 'offline'),
    lastSeen: json['last_seen'] != null 
        ? DateTime.parse(json['last_seen'])
        : json['lastSeen'] != null 
            ? DateTime.parse(json['lastSeen'])
            : null,
    isBot: json['is_bot'] ?? json['isBot'] ?? false,
    isPremium: json['is_premium'] ?? json['isPremium'] ?? false,
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'])
        : DateTime.parse(json['createdAt']),
    updatedAt: json['updated_at'] != null 
        ? DateTime.parse(json['updated_at'])
        : json['updatedAt'] != null 
            ? DateTime.parse(json['updatedAt'])
            : null,
    phoneVisibility: PrivacySetting.values.byName(json['phone_visibility'] ?? json['phoneVisibility'] ?? 'contacts'),
    lastSeenVisibility: PrivacySetting.values.byName(json['last_seen_visibility'] ?? json['lastSeenVisibility'] ?? 'everyone'),
    profilePhotoVisibility: PrivacySetting.values.byName(json['profile_photo_visibility'] ?? json['profilePhotoVisibility'] ?? 'everyone'),
    forwardMessageVisibility: PrivacySetting.values.byName(json['forward_message_visibility'] ?? json['forwardMessageVisibility'] ?? 'everyone'),
    addToGroups: PrivacySetting.values.byName(json['add_to_groups'] ?? json['addToGroups'] ?? 'contacts'),
    voiceCallPermission: PrivacySetting.values.byName(json['voice_call_permission'] ?? json['voiceCallPermission'] ?? 'contacts'),
    videoCallPermission: PrivacySetting.values.byName(json['video_call_permission'] ?? json['videoCallPermission'] ?? 'contacts'),
    allowFindingByPhone: json['allow_finding_by_phone'] ?? json['allowFindingByPhone'] ?? true,
    allowFindingByUsername: json['allow_finding_by_username'] ?? json['allowFindingByUsername'] ?? true,
    twoFactorEnabled: json['two_factor_enabled'] ?? json['twoFactorEnabled'] ?? false,
    passcodeEnabled: json['passcode_enabled'] ?? json['passcodeEnabled'] ?? false,
    biometricEnabled: json['biometric_enabled'] ?? json['biometricEnabled'] ?? false,
    activeSessions: List<String>.from(json['active_sessions'] ?? json['activeSessions'] ?? []),
    blockedUsers: List<String>.from(json['blocked_users'] ?? json['blockedUsers'] ?? []),
    restrictionStatus: AccountRestriction.values.byName(json['restriction_status'] ?? json['restrictionStatus'] ?? 'none'),
    restrictionReason: json['restriction_reason'] ?? json['restrictionReason'],
    restrictionExpiry: json['restriction_expiry'] != null 
        ? DateTime.parse(json['restriction_expiry'])
        : json['restrictionExpiry'] != null 
            ? DateTime.parse(json['restrictionExpiry'])
            : null,
    strikesCount: json['strikes_count'] ?? json['strikesCount'] ?? 0,
    isFlagged: json['is_flagged'] ?? json['isFlagged'] ?? false,
    reportedBy: List<String>.from(json['reported_by'] ?? json['reportedBy'] ?? []),
    botToken: json['bot_token'] ?? json['botToken'],
    botDescription: json['bot_description'] ?? json['botDescription'],
    botCommands: json['bot_commands'] != null 
        ? List<String>.from(json['bot_commands'])
        : json['botCommands'] != null 
            ? List<String>.from(json['botCommands'])
            : null,
    botInlineMode: json['bot_inline_mode'] ?? json['botInlineMode'] ?? false,
    botGroupPrivacy: json['bot_group_privacy'] ?? json['botGroupPrivacy'] ?? true,
    botSubscribers: json['bot_subscribers'] ?? json['botSubscribers'],
    businessName: json['business_name'] ?? json['businessName'],
    businessCategory: json['business_category'] ?? json['businessCategory'],
    businessAddress: json['business_address'] ?? json['businessAddress'],
    businessHours: json['business_hours'] ?? json['businessHours'],
    businessWebsite: json['business_website'] ?? json['businessWebsite'],
    businessVerified: json['business_verified'] ?? json['businessVerified'] ?? false,
  );
}
