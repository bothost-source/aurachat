import 'package:supabase_flutter/supabase_flutter.dart';

class OnlineStatusService {
  static final _supabase = Supabase.instance.client;

  /// Call when user logs in or app comes to foreground
  static Future<void> setOnline() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('online_status').upsert({
        'user_id': userId,
        'is_online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('setOnline error: $e');
    }
  }

  /// Call when user logs out or app goes to background
  static Future<void> setOffline() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('online_status').upsert({
        'user_id': userId,
        'is_online': false,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('setOffline error: $e');
    }
  }
}
