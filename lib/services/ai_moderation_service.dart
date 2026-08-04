import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'api_config.dart';

/// AI-powered moderation service using Google Gemini (Free tier)
class AIModerationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// API key from GitHub Secrets (injected at build time)
  static const String _apiKey = ApiConfig.geminiApiKey;

  /// Rate limit: minimum seconds between processing reports from same reporter
  static const int _rateLimitSeconds = 3600; // 1 hour

  /// Analyze a reported message using AI
  static Future<Map<String, dynamic>> analyzeReport({
    required String messageContent,
    required String reporterId,
    required String reportedUserId,
    required String chatId,
    required String messageId,
  }) async {
    try {
      // Check rate limit for reporter
      final canProceed = await _checkRateLimit(reporterId);
      if (!canProceed) {
        return {
          'status': 'rate_limited',
          'message': 'Please wait before submitting another report',
        };
      }

      // Check if reporter is spamming reports (fake reporter detection)
      final isReliable = await _checkReporterReliability(reporterId);
      if (!isReliable) {
        return {
          'status': 'reporter_flagged',
          'message': 'Your reporting privileges are under review',
        };
      }

      // Call Gemini AI for analysis
      final analysis = await _callGeminiAI(messageContent);

      // Store report
      final reportId = _firestore.collection('reports').doc().id;
      await _firestore.collection('reports').doc(reportId).set({
        'message_id': messageId,
        'chat_id': chatId,
        'reported_user_id': reportedUserId,
        'reporter_id': reporterId,
        'message_content': messageContent,
        'ai_category': analysis['category'],
        'ai_confidence': analysis['confidence'],
        'ai_reasoning': analysis['reasoning'],
        'status': analysis['confidence'] > 0.85 ? 'auto_actioned' : 'pending_review',
        'created_at': FieldValue.serverTimestamp(),
        'reviewed_by': null,
        'reviewed_at': null,
        'action_taken': analysis['confidence'] > 0.85 ? analysis['recommended_action'] : null,
      });

      // Auto-action if confidence is high
      if (analysis['confidence'] > 0.85) {
        await _autoAction(
          reportedUserId: reportedUserId,
          action: analysis['recommended_action'],
          reason: analysis['category'],
          reportId: reportId,
        );
      }

      return {
        'status': 'success',
        'analysis': analysis,
        'report_id': reportId,
      };
    } catch (e) {
      debugPrint('AI Moderation error: $e');
      return {
        'status': 'error',
        'message': 'Analysis failed: $e',
      };
    }
  }

  /// Check if enough time has passed since last report from this user
  static Future<bool> _checkRateLimit(String reporterId) async {
    final lastReport = await _firestore
        .collection('reports')
        .where('reporter_id', isEqualTo: reporterId)
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (lastReport.docs.isEmpty) return true;

    final lastTime = lastReport.docs.first.data()['created_at'] as Timestamp?;
    if (lastTime == null) return true;

    final secondsSince = DateTime.now().difference(lastTime.toDate()).inSeconds;
    return secondsSince >= _rateLimitSeconds;
  }

  /// Check if reporter has too many dismissed reports (fake reporter)
  static Future<bool> _checkReporterReliability(String reporterId) async {
    final reports = await _firestore
        .collection('reports')
        .where('reporter_id', isEqualTo: reporterId)
        .get();

    if (reports.docs.length < 5) return true;

    final dismissed = reports.docs.where((d) => d.data()['status'] == 'dismissed').length;
    final dismissalRate = dismissed / reports.docs.length;

    return dismissalRate < 0.7;
  }

  /// Call Google Gemini AI for content analysis
  static Future<Map<String, dynamic>> _callGeminiAI(String messageContent) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt = '''
You are a content moderation AI for a chat app called AURA. Analyze the following message and classify it.

Message: "$messageContent"

Respond ONLY with a JSON object in this exact format:
{
  "category": "spam|harassment|scam|hate_speech|clean",
  "confidence": 0.0 to 1.0,
  "reasoning": "brief explanation",
  "recommended_action": "none|warn|mute_24h|ban_24h|ban_30d|permanent_ban"
}

Rules:
- spam = unsolicited promotions, ads, repeated messages
- harassment = bullying, threats, personal attacks
- scam = financial fraud, phishing, asking for money/personal info
- hate_speech = racism, sexism, discrimination, slurs
- clean = normal conversation

Confidence guide:
- 0.0-0.3 = clean/normal
- 0.3-0.7 = suspicious but unclear
- 0.7-0.85 = likely violation
- 0.85-1.0 = clear violation, auto-action recommended
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('No JSON found in AI response');
      }

      final jsonStr = jsonMatch.group(0)!;
      final result = jsonDecode(jsonStr) as Map<String, dynamic>;

      return {
        'category': result['category'] ?? 'clean',
        'confidence': (result['confidence'] as num?)?.toDouble() ?? 0.0,
        'reasoning': result['reasoning'] ?? 'No reasoning provided',
        'recommended_action': result['recommended_action'] ?? 'none',
      };
    } catch (e) {
      debugPrint('Gemini API error: $e');
      // Fallback to keyword detection if API fails
      return _fallbackAnalysis(messageContent);
    }
  }

  /// Fallback keyword-based analysis if Gemini API fails
  static Map<String, dynamic> _fallbackAnalysis(String messageContent) {
    final lowerContent = messageContent.toLowerCase();

    if (lowerContent.contains('spam') || lowerContent.contains('buy now') || lowerContent.contains('click here')) {
      return {
        'category': 'spam',
        'confidence': 0.92,
        'reasoning': 'Message contains typical spam patterns and promotional language',
        'recommended_action': 'mute_24h',
      };
    } else if (lowerContent.contains('hate') || lowerContent.contains('kill') || lowerContent.contains('stupid')) {
      return {
        'category': 'harassment',
        'confidence': 0.88,
        'reasoning': 'Message contains hostile or threatening language',
        'recommended_action': 'ban_24h',
      };
    } else if (lowerContent.contains('scam') || lowerContent.contains('send money') || lowerContent.contains('bank details')) {
      return {
        'category': 'scam',
        'confidence': 0.95,
        'reasoning': 'Message attempts to solicit financial information',
        'recommended_action': 'permanent_ban',
      };
    }

    return {
      'category': 'clean',
      'confidence': 0.15,
      'reasoning': 'No harmful content detected',
      'recommended_action': 'none',
    };
  }

  /// Auto-action based on AI recommendation
  static Future<void> _autoAction({
    required String reportedUserId,
    required String action,
    required String reason,
    required String reportId,
  }) async {
    switch (action) {
      case 'warn':
        await _firestore.collection('users').doc(reportedUserId).update({
          'warnings': FieldValue.arrayUnion([{
            'reason': reason,
            'report_id': reportId,
            'timestamp': FieldValue.serverTimestamp(),
          }]),
        });
        break;

      case 'mute_24h':
      case 'ban_24h':
        await _banUser(
          userId: reportedUserId,
          duration: const Duration(hours: 24),
          reason: reason,
          reportId: reportId,
        );
        break;

      case 'ban_30d':
        await _banUser(
          userId: reportedUserId,
          duration: const Duration(days: 30),
          reason: reason,
          reportId: reportId,
        );
        break;

      case 'permanent_ban':
        await _banUser(
          userId: reportedUserId,
          duration: null,
          reason: reason,
          reportId: reportId,
        );
        break;
    }
  }

  /// Ban a user with escalating durations
  static Future<void> _banUser({
    required String userId,
    required Duration? duration,
    required String reason,
    required String reportId,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    final banHistory = List<Map<String, dynamic>>.from(userData['ban_history'] ?? []);

    Duration actualDuration;
    String banLevel;
    final banCount = banHistory.length;

    if (duration == null || banCount >= 5) {
      actualDuration = Duration.zero;
      banLevel = 'permanent';
    } else if (banCount == 0) {
      actualDuration = const Duration(hours: 24);
      banLevel = '24h';
    } else if (banCount >= 1 && banCount <= 3) {
      actualDuration = const Duration(hours: 24);
      banLevel = '24h';
    } else if (banCount == 4) {
      actualDuration = const Duration(days: 30);
      banLevel = '30d';
    } else {
      actualDuration = Duration.zero;
      banLevel = 'permanent';
    }

    final bannedUntil = actualDuration == Duration.zero
        ? null
        : Timestamp.fromDate(DateTime.now().add(actualDuration));

    await _firestore.collection('users').doc(userId).update({
      'is_banned': true,
      'banned_until': bannedUntil,
      'ban_reason': reason,
      'ban_report_id': reportId,
      'ban_level': banLevel,
      'ban_history': FieldValue.arrayUnion([{
        'report_id': reportId,
        'reason': reason,
        'level': banLevel,
        'banned_at': FieldValue.serverTimestamp(),
        'banned_until': bannedUntil,
      }]),
    });
  }

  /// Check if a user is currently banned
  static Future<Map<String, dynamic>?> checkBanStatus(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    if (data['is_banned'] != true) return null;

    final bannedUntil = data['banned_until'] as Timestamp?;

    if (bannedUntil != null && DateTime.now().isAfter(bannedUntil.toDate())) {
      await _unbanUser(userId);
      return null;
    }

    return {
      'is_banned': true,
      'banned_until': bannedUntil?.toDate(),
      'ban_reason': data['ban_reason'],
      'ban_level': data['ban_level'],
    };
  }

  /// Unban a user (auto or manual)
  static Future<void> _unbanUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'is_banned': false,
      'banned_until': null,
      'ban_reason': null,
      'ban_report_id': null,
      'ban_level': null,
    });
  }

  /// Manual review by admin
  static Future<void> reviewReport({
    required String reportId,
    required String adminId,
    required String decision,
    required String notes,
  }) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': decision == 'upheld' ? 'resolved' : 'dismissed',
      'reviewed_by': adminId,
      'reviewed_at': FieldValue.serverTimestamp(),
      'admin_notes': notes,
    });

    final report = await _firestore.collection('reports').doc(reportId).get();
    final reporterId = report.data()?['reporter_id'];
    if (reporterId != null && decision == 'dismissed') {
      await _checkReporterReliability(reporterId);
    }
  }
}
