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
  String get handle => username != null ? '@$username' : '';

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneNumber': phoneNumber,
    'username': username,
    'displayName': displayName,
    'bio': bio,
    'avatarUrl': avatarUrl,
    'accountType': accountType.name,
    'verificationLevel': verificationLevel.name,
    'status': status.name,
    'lastSeen': lastSeen?.toIso8601String(),
    'isBot': isBot,
    'isPremium': isPremium,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'phoneVisibility': phoneVisibility.name,
    'lastSeenVisibility': lastSeenVisibility.name,
    'profilePhotoVisibility': profilePhotoVisibility.name,
    'forwardMessageVisibility': forwardMessageVisibility.name,
    'addToGroups': addToGroups.name,
    'voiceCallPermission': voiceCallPermission.name,
    'videoCallPermission': videoCallPermission.name,
    'allowFindingByPhone': allowFindingByPhone,
    'allowFindingByUsername': allowFindingByUsername,
    'twoFactorEnabled': twoFactorEnabled,
    'passcodeEnabled': passcodeEnabled,
    'biometricEnabled': biometricEnabled,
    'activeSessions': activeSessions,
    'blockedUsers': blockedUsers,
    'restrictionStatus': restrictionStatus.name,
    'restrictionReason': restrictionReason,
    'restrictionExpiry': restrictionExpiry?.toIso8601String(),
    'strikesCount': strikesCount,
    'isFlagged': isFlagged,
    'reportedBy': reportedBy,
    'botToken': botToken,
    'botDescription': botDescription,
    'botCommands': botCommands,
    'botInlineMode': botInlineMode,
    'botGroupPrivacy': botGroupPrivacy,
    'botSubscribers': botSubscribers,
    'businessName': businessName,
    'businessCategory': businessCategory,
    'businessAddress': businessAddress,
    'businessHours': businessHours,
    'businessWebsite': businessWebsite,
    'businessVerified': businessVerified,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'],
    phoneNumber: json['phoneNumber'],
    username: json['username'],
    displayName: json['displayName'],
    bio: json['bio'],
    avatarUrl: json['avatarUrl'],
    accountType: AccountType.values.byName(json['accountType'] ?? 'personal'),
    verificationLevel: VerificationLevel.values.byName(json['verificationLevel'] ?? 'none'),
    status: UserStatus.values.byName(json['status'] ?? 'offline'),
    lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    isBot: json['isBot'] ?? false,
    isPremium: json['isPremium'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    phoneVisibility: PrivacySetting.values.byName(json['phoneVisibility'] ?? 'contacts'),
    lastSeenVisibility: PrivacySetting.values.byName(json['lastSeenVisibility'] ?? 'everyone'),
    profilePhotoVisibility: PrivacySetting.values.byName(json['profilePhotoVisibility'] ?? 'everyone'),
    forwardMessageVisibility: PrivacySetting.values.byName(json['forwardMessageVisibility'] ?? 'everyone'),
    addToGroups: PrivacySetting.values.byName(json['addToGroups'] ?? 'contacts'),
    voiceCallPermission: PrivacySetting.values.byName(json['voiceCallPermission'] ?? 'contacts'),
    videoCallPermission: PrivacySetting.values.byName(json['videoCallPermission'] ?? 'contacts'),
    allowFindingByPhone: json['allowFindingByPhone'] ?? true,
    allowFindingByUsername: json['allowFindingByUsername'] ?? true,
    twoFactorEnabled: json['twoFactorEnabled'] ?? false,
    passcodeEnabled: json['passcodeEnabled'] ?? false,
    biometricEnabled: json['biometricEnabled'] ?? false,
    activeSessions: List<String>.from(json['activeSessions'] ?? []),
    blockedUsers: List<String>.from(json['blockedUsers'] ?? []),
    restrictionStatus: AccountRestriction.values.byName(json['restrictionStatus'] ?? 'none'),
    restrictionReason: json['restrictionReason'],
    restrictionExpiry: json['restrictionExpiry'] != null ? DateTime.parse(json['restrictionExpiry']) : null,
    strikesCount: json['strikesCount'] ?? 0,
    isFlagged: json['isFlagged'] ?? false,
    reportedBy: List<String>.from(json['reportedBy'] ?? []),
    botToken: json['botToken'],
    botDescription: json['botDescription'],
    botCommands: json['botCommands'] != null ? List<String>.from(json['botCommands']) : null,
    botInlineMode: json['botInlineMode'] ?? false,
    botGroupPrivacy: json['botGroupPrivacy'] ?? true,
    botSubscribers: json['botSubscribers'],
    businessName: json['businessName'],
    businessCategory: json['businessCategory'],
    businessAddress: json['businessAddress'],
    businessHours: json['businessHours'],
    businessWebsite: json['businessWebsite'],
    businessVerified: json['businessVerified'] ?? false,
  );
}
