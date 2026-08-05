import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class AIModerationService {
  static const String _backendUrl = 'https://aurachat-backend-5utu.onrender.com';

  /// Send report to backend AI moderation
  static Future<Map<String, dynamic>> analyzeReport({
    required String messageContent,
    required String reporterId,
    required String reportedUserId,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/moderation/report'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messageContent': messageContent,
          'reporterId': reporterId,
          'reportedUserId': reportedUserId,
          'chatId': chatId,
          'messageId': messageId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'status': 'error', 'message': error['error'] ?? 'Report failed'};
      }
    } catch (e) {
      debugPrint('Report to backend error: $e');
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  /// Check ban status from backend
  static Future<Map<String, dynamic>?> checkBanStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/moderation/ban-status/$userId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Ban status check error: $e');
      return null;
    }
  }
}
