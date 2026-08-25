import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsProvider extends ChangeNotifier {
  final _prefs = SharedPreferences.getInstance();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Security Settings
  bool _twoStepVerification = false;
  bool _appPasscode = false;
  bool _biometricLock = false;
  String _passcode = '';
  int _autoLockTimeout = 5; // minutes

  // Notification Settings
  bool _messageTones = true;
  bool _groupNotifications = true;
  bool _channelNotifications = true;
  bool _voiceVideoCalls = true;
  bool _inAppSounds = true;
  bool _inAppVibrate = true;
  bool _showPreview = true;

  // Call Ringtone
  String _callRingtone = 'default';

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

  // =========================================================================
  // APP LOCK TRACKING
  // =========================================================================
  DateTime? _lastBackgroundTime;
  bool _isLocked = false;

  bool get isLocked => _isLocked;

  /// Call this when app goes to background (paused/detached)
  Future<void> onAppBackground() async {
    // Only track if lock is actually configured
    if (!_appPasscode && !_biometricLock) return;

    final now = DateTime.now();
    _lastBackgroundTime = now;
    final prefs = await _prefs;
    await prefs.setInt('last_background_time', now.millisecondsSinceEpoch);
    await prefs.setBool('has_ever_backgrounded', true);
  }

  /// Call this when app resumes — returns true if lock screen should show
  Future<bool> shouldShowLockScreen() async {
    // No lock configured
    if (!_appPasscode && !_biometricLock) return false;

    // Already locked (e.g. manually locked)
    if (_isLocked) return true;

    final prefs = await _prefs;
    final lastBg = prefs.getInt('last_background_time');

    // No background time recorded — app was killed or first launch
    if (lastBg == null) {
      // Only lock if this is a resume from background (not first install)
      final hasEverBeenBackgrounded = prefs.getBool('has_ever_backgrounded') ?? false;
      if (!hasEverBeenBackgrounded) {
        return false; // First time user, don't lock
      }
      
      _isLocked = true;
      notifyListeners();
      return true;
    }

    final lastBgTime = DateTime.fromMillisecondsSinceEpoch(lastBg);
    final now = DateTime.now();
    final diff = now.difference(lastBgTime).inMinutes;

    if (diff >= _autoLockTimeout) {
      _isLocked = true;
      notifyListeners();
      return true;
    }

    // Timeout not reached — clear background time, stay unlocked
    await prefs.remove('last_background_time');
    _lastBackgroundTime = null;
    return false;
  }

  /// Call this after successful unlock (biometric or passcode)
  Future<void> unlock() async {
    _isLocked = false;
    final prefs = await _prefs;
    await prefs.remove('last_background_time');
    notifyListeners();
  }

  /// For manual lock trigger
  Future<void> lock() async {
    _isLocked = true;
    notifyListeners();
  }

  /// Check if device supports biometric authentication
  Future<bool> canUseBiometric() async {
    // This would need local_auth package — return true for now
    // In real implementation, check with LocalAuthentication().isDeviceSupported()
    return true;
  }
  // =========================================================================
  // END APP LOCK TRACKING
  // =========================================================================

  // Getters
  bool get twoStepVerification => _twoStepVerification;
  bool get appPasscode => _appPasscode;
  bool get biometricLock => _biometricLock;
  String get passcode => _passcode;
  int get autoLockTimeout => _autoLockTimeout;

  // Alias for appPasscode (used by lock screen)
  bool get passcodeLock => _appPasscode;

  bool get messageTones => _messageTones;
  bool get groupNotifications => _groupNotifications;
  bool get channelNotifications => _channelNotifications;
  bool get voiceVideoCalls => _voiceVideoCalls;
  bool get inAppSounds => _inAppSounds;
  bool get inAppVibrate => _inAppVibrate;
  bool get showPreview => _showPreview;

  // Call Ringtone Getter
  String get callRingtone => _callRingtone;

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
    _autoLockTimeout = prefs.getInt('auto_lock_timeout') ?? 5;

    // Notifications
    _messageTones = prefs.getBool('message_tones') ?? true;
    _groupNotifications = prefs.getBool('group_notifications') ?? true;
    _channelNotifications = prefs.getBool('channel_notifications') ?? true;
    _voiceVideoCalls = prefs.getBool('voice_video_calls') ?? true;
    _inAppSounds = prefs.getBool('in_app_sounds') ?? true;
    _inAppVibrate = prefs.getBool('in_app_vibrate') ?? true;
    _showPreview = prefs.getBool('show_preview') ?? true;

    // Load Call Ringtone
    _callRingtone = prefs.getString('call_ringtone') ?? 'default';

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

    _syncFromFirebase();
  }

  String? _mockUserId;

  void setMockUserId(String? id) {
    _mockUserId = id;
  }

  Future<void> _syncFromFirebase() async {
    try {
      final userId = _auth.currentUser?.uid ?? _mockUserId;
      if (userId == null) return;

      final doc = await _firestore.collection('user_settings').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        // Security
        _twoStepVerification = data['two_step_verification'] ?? _twoStepVerification;
        _appPasscode = data['app_passcode'] ?? _appPasscode;
        _biometricLock = data['biometric_lock'] ?? _biometricLock;
        _passcode = data['passcode'] ?? _passcode;
        _autoLockTimeout = data['auto_lock_timeout'] ?? _autoLockTimeout;
        // Notifications
        _messageTones = data['message_tones'] ?? _messageTones;
        _groupNotifications = data['group_notifications'] ?? _groupNotifications;
        _channelNotifications = data['channel_notifications'] ?? _channelNotifications;
        _voiceVideoCalls = data['voice_video_calls'] ?? _voiceVideoCalls;
        _inAppSounds = data['in_app_sounds'] ?? _inAppSounds;
        _inAppVibrate = data['in_app_vibrate'] ?? _inAppVibrate;
        _showPreview = data['show_preview'] ?? _showPreview;
        // Sync Call Ringtone from Firebase
        _callRingtone = data['call_ringtone'] ?? _callRingtone;
        // Privacy
        _phoneNumberVisible = data['phone_number_visible'] ?? _phoneNumberVisible;
        _lastSeenVisible = data['last_seen_visible'] ?? _lastSeenVisible;
        _profilePhotoVisible = data['profile_photo_visible'] ?? _profilePhotoVisible;
        _forwardedMessages = data['forwarded_messages'] ?? _forwardedMessages;
        _addToGroups = data['add_to_groups'] ?? _addToGroups;
        _voiceVideoCallsVisible = data['voice_video_calls_visible'] ?? _voiceVideoCallsVisible;
        _findByPhone = data['find_by_phone'] ?? _findByPhone;
        _findByUsername = data['find_by_username'] ?? _findByUsername;
        // Theme
        final themeString = data['theme_mode'] ?? 'dark';
        _themeMode = themeString == 'light' ? ThemeMode.light : 
                     themeString == 'system' ? ThemeMode.system : ThemeMode.dark;
        // Language
        _language = data['language'] ?? _language;
        // Data
        _autoDownloadMedia = data['auto_download_media'] ?? _autoDownloadMedia;
        _autoDownloadDocuments = data['auto_download_documents'] ?? _autoDownloadDocuments;
        _saveToGallery = data['save_to_gallery'] ?? _saveToGallery;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Sync from Firebase error: $e');
    }
  }

  Future<void> _saveToFirebase() async {
    try {
      final userId = _auth.currentUser?.uid ?? _mockUserId;
      if (userId == null) return;

      await _firestore.collection('user_settings').doc(userId).set({
        'user_id': userId,
        // Security
        'two_step_verification': _twoStepVerification,
        'app_passcode': _appPasscode,
        'biometric_lock': _biometricLock,
        'auto_lock_timeout': _autoLockTimeout,
        // Privacy
        'phone_number_visible': _phoneNumberVisible,
        'last_seen_visible': _lastSeenVisible,
        'profile_photo_visible': _profilePhotoVisible,
        'forwarded_messages': _forwardedMessages,
        'add_to_groups': _addToGroups,
        'voice_video_calls_visible': _voiceVideoCallsVisible,
        'find_by_phone': _findByPhone,
        'find_by_username': _findByUsername,
        // Data Storage
        'auto_download_media': _autoDownloadMedia,
        'auto_download_documents': _autoDownloadDocuments,
        'save_to_gallery': _saveToGallery,
        // Theme & Language
        'theme_mode': _themeMode == ThemeMode.light ? 'light' : _themeMode == ThemeMode.system ? 'system' : 'dark',
        'language': _language,
        // Call Ringtone
        'call_ringtone': _callRingtone,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save to Firebase error: $e');
    }
  }

  // Security Setters
  Future<void> setTwoStepVerification(bool value) async {
    _twoStepVerification = value;
    final prefs = await _prefs;
    await prefs.setBool('two_step_verification', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setAppPasscode(bool value) async {
    _appPasscode = value;
    final prefs = await _prefs;
    await prefs.setBool('app_passcode', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setBiometricLock(bool value) async {
    _biometricLock = value;
    final prefs = await _prefs;
    await prefs.setBool('biometric_lock', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setPasscode(String value) async {
    _passcode = value;
    final prefs = await _prefs;
    await prefs.setString('passcode', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setAutoLockTimeout(int value) async {
    _autoLockTimeout = value;
    final prefs = await _prefs;
    await prefs.setInt('auto_lock_timeout', value);
    notifyListeners();
    _saveToFirebase();
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

  // Call Ringtone Setter
  Future<void> setCallRingtone(String ringtoneId) async {
    _callRingtone = ringtoneId;
    final prefs = await _prefs;
    await prefs.setString('call_ringtone', ringtoneId);
    notifyListeners();
    _saveToFirebase();
  }

  // Privacy Setters
  Future<void> setPhoneNumberVisible(bool value) async {
    _phoneNumberVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('phone_number_visible', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setLastSeenVisible(bool value) async {
    _lastSeenVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('last_seen_visible', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setProfilePhotoVisible(bool value) async {
    _profilePhotoVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('profile_photo_visible', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setForwardedMessages(bool value) async {
    _forwardedMessages = value;
    final prefs = await _prefs;
    await prefs.setBool('forwarded_messages', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setAddToGroups(bool value) async {
    _addToGroups = value;
    final prefs = await _prefs;
    await prefs.setBool('add_to_groups', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setVoiceVideoCallsVisible(bool value) async {
    _voiceVideoCallsVisible = value;
    final prefs = await _prefs;
    await prefs.setBool('voice_video_calls_visible', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setFindByPhone(bool value) async {
    _findByPhone = value;
    final prefs = await _prefs;
    await prefs.setBool('find_by_phone', value);
    notifyListeners();
    _saveToFirebase();
  }

  Future<void> setFindByUsername(bool value) async {
    _findByUsername = value;
    final prefs = await _prefs;
    await prefs.setBool('find_by_username', value);
    notifyListeners();
    _saveToFirebase();
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
