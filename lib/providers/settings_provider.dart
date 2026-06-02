import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsProvider extends ChangeNotifier {
  final _prefs = SharedPreferences.getInstance();
  final _supabase = Supabase.instance.client;

  // Security Settings
  bool _twoStepVerification = false;
  bool _appPasscode = false;
  bool _biometricLock = false;
  String _passcode = '';

  // Notification Settings
  bool _messageTones = true;
  bool _groupNotifications = true;
  bool _channelNotifications = true;
  bool _voiceVideoCalls = true;
  bool _inAppSounds = true;
  bool _inAppVibrate = true;
  bool _showPreview = true;

  // Privacy Settings
  bool _phoneNumberVisible = true;
  bool _lastSeenVisible = true;
  bool _profilePhotoVisible = true;
  bool _forwardedMessages = true;
  bool _addToGroups = true;
  bool _voiceVideoCallsVisible = true;
  bool _findByPhone = true;
  bool _findByUsername = true;

  // Theme
  ThemeMode _themeMode = ThemeMode.dark;

  // Language
  String _language = 'en';

  // Data Storage
  bool _autoDownloadMedia = true;
  bool _autoDownloadDocuments = false;
  bool _saveToGallery = true;

  // Getters
  bool get twoStepVerification => _twoStepVerification;
  bool get appPasscode => _appPasscode;
  bool get biometricLock => _biometricLock;
  String get passcode => _passcode;

  bool get messageTones => _messageTones;
  bool get groupNotifications => _groupNotifications;
  bool get channelNotifications => _channelNotifications;
  bool get voiceVideoCalls => _voiceVideoCalls;
  bool get inAppSounds => _inAppSounds;
  bool get inAppVibrate => _inAppVibrate;
  bool get showPreview => _showPreview;

  bool get phoneNumberVisible => _phoneNumberVisible;
  bool get lastSeenVisible => _lastSeenVisible;
  bool get profilePhotoVisible => _profilePhotoVisible;
  bool get forwardedMessages => _forwardedMessages;
  bool get addToGroups => _addToGroups;
  bool get voiceVideoCallsVisible => _voiceVideoCallsVisible;
  bool get findByPhone => _findByPhone;
  bool get findByUsername => _findByUsername;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;

  bool get autoDownloadMedia => _autoDownloadMedia;
  bool get autoDownloadDocuments => _autoDownloadDocuments;
  bool get saveToGallery => _saveToGallery;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await _prefs;

    // Security
    _twoStepVerification = prefs.getBool('two_step_verification') ?? false;
    _appPasscode = prefs.getBool('app_passcode') ?? false;
    _biometricLock = prefs.getBool('biometric_lock') ?? false;
    _passcode = prefs.getString('passcode') ?? '';

    // Notifications
    _messageTones = prefs.getBool('message_tones') ?? true;
    _groupNotifications = prefs.getBool('group_notifications') ?? true;
    _channelNotifications = prefs.getBool('channel_notifications') ?? true;
    _voiceVideoCalls = prefs.getBool('voice_video_calls') ?? true;
    _inAppSounds = prefs.getBool('in_app_sounds') ?? true;
    _inAppVibrate = prefs.getBool('in_app_vibrate') ?? true;
    _showPreview = prefs.getBool('show_preview') ?? true;

    // Privacy
    _phoneNumberVisible = prefs.getBool('phone_number_visible') ?? true;
    _lastSeenVisible = prefs.getBool('last_seen_visible') ?? true;
    _profilePhotoVisible = prefs.getBool('profile_photo_visible') ?? true;
    _forwardedMessages = prefs.getBool('forwarded_messages') ?? true;
    _addToGroups = prefs.getBool('add_to_groups') ?? true;
    _voiceVideoCallsVisible = prefs.getBool('voice_video_calls_visible') ?? true;
    _findByPhone = prefs.getBool('find_by_phone') ?? true;
    _findByUsername = prefs.getBool('find_by_username') ?? true;

    // Theme
    final themeString = prefs.getString('theme_mode') ?? 'dark';
    _themeMode = themeString == 'light' ? ThemeMode.light : 
                 themeString == 'system' ? ThemeMode.system : ThemeMode.dark;

    // Language
    _language = prefs.getString('language') ?? 'en';

    // Data
    _autoDownloadMedia = prefs.getBool('auto_download_media') ?? true;
    _autoDownloadDocuments = prefs.getBool('auto_download_documents') ?? false;
    _saveToGallery = prefs.getBool('save_to_gallery') ?? true;

    notifyListeners();

    // Also sync from Supabase if user is logged in
    _syncFromSupabase();
  }

  Future<void> _syncFromSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('user_settings')
          .select()
          .eq('user_id', user.id)
          .single();

      if (response != null) {
        _twoStepVerification = response['two_step_verification'] ?? _twoStepVerification;
        _phoneNumberVisible = response['phone_number_visible'] ?? _phoneNumberVisible;
        _lastSeenVisible = response['last_seen_visible'] ?? _lastSeenVisible;
        _profilePhotoVisible = response['profile_photo_visible'] ?? _profilePhotoVisible;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Sync from Supabase error: $e');
    }
  }

  Future<void> _saveToSupabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('user_settings').upsert({
        'user_id': user.id,
        'two_step_verification': _twoStepVerification,
        'phone_number_visible': _phoneNumberVisible,
        'last_seen_visible': _lastSeenVisible,
        'profile_photo_visible': _profilePhotoVisible,
        'forwarded_messages': _forwardedMessages,
        'add_to_groups': _addToGroups,
        'voice_video_calls_visible': _voiceVideoCallsVisible,
        'find_by_phone': _findByPhone,
        'find_by_username': _findByUsername,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Save to Supabase error: $e');
    }
  }

  // Security Setters
  Future<void> setTwoStepVerification(bool value) async {
    _twoStepVerification = value;
    final prefs = await _prefs;
    await prefs.setBool('two_step_verification', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setAppPasscode(bool value) async {
    _appPasscode = value;
    final prefs = await _prefs;
    await prefs.setBool('app_passcode', value);
    notifyListeners();
  }

  Future<void> setBiometricLock(bool value) async {
    _biometricLock = value;
    final prefs = await _prefs;
    await prefs.setBool('biometric_lock', value);
    notifyListeners();
  }

  Future<void> setPasscode(String value) async {
    _passcode = value;
    final prefs = await _prefs;
    await prefs.setString('passcode', value);
    notifyListeners();
  }

  // Notification Setters
  Future<void> setMessageTones(bool value) async {
    _messageTones = value;
    final prefs = await _prefs;
    await prefs.setBool('message_tones', value);
    notifyListeners();
  }

  Future<void> setGroupNotifications(bool value) async {
    _groupNotifications = value;
    final prefs = await _prefs;
    await prefs.setBool('group_notifications', value);
    notifyListeners();
  }

  Future<void> setChannelNotifications(bool value) async {
    _channelNotifications = value;
    final prefs = await _prefs;
    await prefs.setBool('channel_notifications', value);
    notifyListeners();
  }

  Future<void> setVoiceVideoCalls(bool value) async {
    _voiceVideoCalls = value;
    final prefs = await _prefs;
    await prefs.setBool('voice_video_calls', value);
    notifyListeners();
  }

  Future<void> setInAppSounds(bool value) async {
    _inAppSounds = value;
    final prefs = await _prefs;
    await prefs.setBool('in_app_sounds', value);
    notifyListeners();
  }

  Future<void> setInAppVibrate(bool value) async {
    _inAppVibrate = value;
    final prefs = await _prefs;
    await prefs.setBool('in_app_vibrate', value);
    notifyListeners();
  }

  Future<void> setShowPreview(bool value) async {
    _showPreview = value;
    final prefs = await _prefs;
    await prefs.setBool('show_preview', value);
    notifyListeners();
  }

  // Privacy Setters
  Future<void> setPhoneNumberVisible(bool value) async {
    _phoneNumberVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('phone_number_visible', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setLastSeenVisible(bool value) async {
    _lastSeenVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('last_seen_visible', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setProfilePhotoVisible(bool value) async {
    _profilePhotoVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('profile_photo_visible', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setForwardedMessages(bool value) async {
    _forwardedMessages = value;
    final prefs = await _prefs;
    await prefs.setBool('forwarded_messages', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setAddToGroups(bool value) async {
    _addToGroups = value;
    final prefs = await _prefs;
    await prefs.setBool('add_to_groups', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setVoiceVideoCallsVisible(bool value) async {
    _voiceVideoCallsVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('voice_video_calls_visible', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setFindByPhone(bool value) async {
    _findByPhone = value;
    final prefs = await _prefs;
    await prefs.setBool('find_by_phone', value);
    notifyListeners();
    _saveToSupabase();
  }

  Future<void> setFindByUsername(bool value) async {
    _findByUsername = value;
    final prefs = await _prefs;
    await prefs.setBool('find_by_username', value);
    notifyListeners();
    _saveToSupabase();
  }

  // Theme
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await _prefs;
    String modeString = 'dark';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.system) modeString = 'system';
    await prefs.setString('theme_mode', modeString);
    notifyListeners();
  }

  // Language
  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await _prefs;
    await prefs.setString('language', lang);
    notifyListeners();
  }

  // Data Storage Setters
  Future<void> setAutoDownloadMedia(bool value) async {
    _autoDownloadMedia = value;
    final prefs = await _prefs;
    await prefs.setBool('auto_download_media', value);
    notifyListeners();
  }

  Future<void> setAutoDownloadDocuments(bool value) async {
    _autoDownloadDocuments = value;
    final prefs = await _prefs;
    await prefs.setBool('auto_download_documents', value);
    notifyListeners();
  }

  Future<void> setSaveToGallery(bool value) async {
    _saveToGallery = value;
    final prefs = await _prefs;
    await prefs.setBool('save_to_gallery', value);
    notifyListeners();
  }

  // Reset all settings
  Future<void> resetSettings() async {
    final prefs = await _prefs;
    await prefs.clear();
    await _loadSettings();
  }
}
