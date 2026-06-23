import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StatusService {
  static final _supabase = Supabase.instance.client;

  // Upload image/video status
  static Future<String?> uploadStatusMedia(File file, String userId, String type) async {
    try {
      final ext = path.extension(file.path);
      final fileName = 'statuses/$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
      
      await _supabase.storage.from('statuses').upload(
        fileName,
        file,
        fileOptions: FileOptions(
          contentType: type == 'video' ? 'video/mp4' : 'image/jpeg',
        ),
      );

      return _supabase.storage.from('statuses').getPublicUrl(fileName);
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Create text status
  static Future<bool> createTextStatus(String userId, String caption) async {
    try {
      await _supabase.from('statuses').insert({
        'user_id': userId,
        'caption': caption,
        'type': 'text',
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Create text status error: $e');
      return false;
    }
  }

  // Create media status
  static Future<bool> createMediaStatus(String userId, String mediaUrl, String type, {String caption = ''}) async {
    try {
      await _supabase.from('statuses').insert({
        'user_id': userId,
        'media_url': mediaUrl,
        'caption': caption,
        'type': type,
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Create media status error: $e');
      return false;
    }
  }

  // Get active statuses (not expired)
  static Future<List<Map<String, dynamic>>> getActiveStatuses() async {
    try {
      final response = await _supabase
          .from('statuses')
          .select('*, users!inner(username, avatar_url)')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get statuses error: $e');
      return [];
    }
  }

  // Get my statuses
  static Future<List<Map<String, dynamic>>> getMyStatuses(String userId) async {
    try {
      final response = await _supabase
          .from('statuses')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Get my statuses error: $e');
      return [];
    }
  }

  // Delete expired statuses (call periodically)
  static Future<void> deleteExpiredStatuses() async {
    try {
      await _supabase
          .from('statuses')
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());
    } catch (e) {
      print('Delete expired error: $e');
    }
  }
}
