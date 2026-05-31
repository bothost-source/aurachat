import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';

// ============================================================================
// AI MODERATION SERVICE — Content safety scanning
// ============================================================================
class AIModerationService {
  static final AIModerationService _instance = AIModerationService._internal();
  factory AIModerationService() => _instance;
  AIModerationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // OpenAI API key (replace with your actual key or use your own AI backend)
  String? _apiKey;

  void setApiKey(String key) => _apiKey = key;

  // Local profanity/spam patterns (works offline)
  static final List<String> _profanityPatterns = [
    'fuck', 'shit', 'bitch', 'asshole', 'damn', 'cunt', 'dick', 'pussy',
    'nigger', 'faggot', 'retard', 'kill yourself', 'kys',
  ];

  static final List<String> _spamPatterns = [
    'click here', 'free money', 'get rich', 'win prize', 'limited time',
    'act now', '100% free', 'no credit card', 'make money fast',
  ];

  // ==========================================================================
  // SCAN MESSAGE
  // ==========================================================================

  Future<ModerationResult> scanMessage(String content, {MessageType type = MessageType.text}) async {
    // 1. Fast local check (offline capable)
    final localResult = _localScan(content);
    if (localResult.isFlagged) return localResult;

    // 2. AI API check (requires internet)
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        final aiResult = await _aiScan(content);
        return aiResult;
      } catch (e) {
        // Fallback to local if AI fails
        return localResult;
      }
    }

    return localResult;
  }

  // ==========================================================================
  // LOCAL SCAN (Offline)
  // ==========================================================================

  ModerationResult _localScan(String content) {
    final lowerContent = content.toLowerCase();

    // Check profanity
    for (final pattern in _profanityPatterns) {
      if (lowerContent.contains(pattern)) {
        return ModerationResult(
          isFlagged: true,
          flag: ContentFlag.harassment,
          reason: 'Contains inappropriate language: "$pattern"',
          confidence: 0.95,
          action: ModerationAction.restrict,
        );
      }
    }

    // Check spam
    for (final pattern in _spamPatterns) {
      if (lowerContent.contains(pattern)) {
        return ModerationResult(
          isFlagged: true,
          flag: ContentFlag.spam,
          reason: 'Potential spam detected',
          confidence: 0.85,
          action: ModerationAction.restrict,
        );
      }
    }

    // Check ALL CAPS shouting
    final alphaChars = content.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (alphaChars.length > 10 && alphaChars == alphaChars.toUpperCase()) {
      return ModerationResult(
        isFlagged: true,
        flag: ContentFlag.spam,
        reason: 'Excessive capitalization (shouting)',
        confidence: 0.6,
        action: ModerationAction.warn,
      );
    }

    // Check repeated characters (spam pattern)
    if (RegExp(r'(.){4,}').hasMatch(content)) {
      return ModerationResult(
        isFlagged: true,
        flag: ContentFlag.spam,
        reason: 'Repeated characters detected',
        confidence: 0.7,
        action: ModerationAction.warn,
      );
    }

    return ModerationResult.clean();
  }

  // ==========================================================================
  // AI API SCAN (OpenAI Moderation API)
  // ==========================================================================

  Future<ModerationResult> _aiScan(String content) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return ModerationResult.clean();
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/moderations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({'input': content}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results']?[0];

        if (results != null) {
          final isFlagged = results['flagged'] ?? false;
          final categories = results['categories'] as Map<String, dynamic>?;
          final scores = results['category_scores'] as Map<String, dynamic>?;

          if (isFlagged && categories != null) {
            // Find highest scoring category
            String highestCategory = '';
            double highestScore = 0;

            categories.forEach((category, flagged) {
              if (flagged == true) {
                final score = (scores?[category] ?? 0.0).toDouble();
                if (score > highestScore) {
                  highestScore = score;
                  highestCategory = category;
                }
              }
            });

            final flag = _mapOpenAICategory(highestCategory);
            final action = highestScore > 0.9 ? ModerationAction.block : ModerationAction.restrict;

            return ModerationResult(
              isFlagged: true,
              flag: flag,
              reason: 'AI detected: ${_formatCategory(highestCategory)}',
              confidence: highestScore,
              action: action,
            );
          }
        }
      }
    } catch (e) {
      // API failed, return clean
    }

    return ModerationResult.clean();
  }

  // ==========================================================================
  // BAN SYSTEM (2 Strikes = Permanent)
  // ==========================================================================

  Future<UserStrikeStatus> checkUserStrikes(String userId) async {
    final doc = await _firestore.collection('user_strikes').doc(userId).get();

    if (!doc.exists) {
      return UserStrikeStatus(strikes: 0, isBanned: false);
    }

    final data = doc.data()!;
    final strikes = data['strikes'] ?? 0;
    final isBanned = data['isBanned'] ?? false;
    final banExpiresAt = data['banExpiresAt'] != null
        ? (data['banExpiresAt'] as Timestamp).toDate()
        : null;

    // Check if temporary ban expired
    if (isBanned && banExpiresAt != null && DateTime.now().isAfter(banExpiresAt)) {
      // Unban user
      await _firestore.collection('user_strikes').doc(userId).update({
        'isBanned': false,
        'banExpiresAt': null,
      });
      return UserStrikeStatus(strikes: strikes, isBanned: false);
    }

    return UserStrikeStatus(
      strikes: strikes,
      isBanned: isBanned,
      banExpiresAt: banExpiresAt,
    );
  }

  Future<void> addStrike(String userId, ContentFlag violation) async {
    final docRef = _firestore.collection('user_strikes').doc(userId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'userId': userId,
        'strikes': 1,
        'isBanned': false,
        'violations': [violation.name],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = doc.data()!;
    final currentStrikes = (data['strikes'] ?? 0) + 1;
    final violations = List<String>.from(data['violations'] ?? []);
    violations.add(violation.name);

    // 2 strikes = permanent ban
    if (currentStrikes >= 2) {
      await docRef.update({
        'strikes': currentStrikes,
        'isBanned': true,
        'banType': 'permanent',
        'violations': violations,
        'bannedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 1 strike = 24h temporary ban
      await docRef.update({
        'strikes': currentStrikes,
        'isBanned': true,
        'banType': 'temporary',
        'banExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        'violations': violations,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==========================================================================
  // REPORT SYSTEM
  // ==========================================================================

  Future<void> reportMessage({
    required String messageId,
    required String chatId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    await _firestore.collection('reports').add({
      'messageId': messageId,
      'chatId': chatId,
      'reporterId': reporterId,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  ContentFlag _mapOpenAICategory(String category) {
    switch (category) {
      case 'hate': return ContentFlag.harassment;
      case 'hate/threatening': return ContentFlag.violence;
      case 'harassment': return ContentFlag.harassment;
      case 'harassment/threatening': return ContentFlag.violence;
      case 'self-harm': return ContentFlag.violence;
      case 'self-harm/instructions': return ContentFlag.violence;
      case 'sexual': return ContentFlag.explicit;
      case 'sexual/minors': return ContentFlag.illegal;
      case 'violence': return ContentFlag.violence;
      case 'violence/graphic': return ContentFlag.violence;
      default: return ContentFlag.spam;
    }
  }

  String _formatCategory(String category) {
    return category.replaceAll('/', ' ').replaceAll('_', ' ').toUpperCase();
  }
}

// ============================================================================
// MODERATION RESULT
// ============================================================================
class ModerationResult {
  final bool isFlagged;
  final ContentFlag flag;
  final String reason;
  final double confidence;
  final ModerationAction action;

  ModerationResult({
    required this.isFlagged,
    required this.flag,
    required this.reason,
    required this.confidence,
    required this.action,
  });

  factory ModerationResult.clean() => ModerationResult(
    isFlagged: false,
    flag: ContentFlag.none,
    reason: '',
    confidence: 0.0,
    action: ModerationAction.allow,
  );
}

enum ModerationAction { allow, warn, restrict, block }

class UserStrikeStatus {
  final int strikes;
  final bool isBanned;
  final DateTime? banExpiresAt;

  UserStrikeStatus({
    required this.strikes,
    required this.isBanned,
    this.banExpiresAt,
  });

  String get statusText {
    if (isBanned) {
      if (banExpiresAt != null) {
        final hours = banExpiresAt!.difference(DateTime.now()).inHours;
        return 'Banned for $hours more hours';
      }
      return 'Permanently banned';
    }
    if (strikes == 1) return '1 strike — next violation = ban';
    return 'Clean record';
  }
}
