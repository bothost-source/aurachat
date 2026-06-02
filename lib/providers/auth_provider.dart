import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  String? _phoneNumber;
  String? _userName;
  String? _userBio;
  String? _userPhotoUrl;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  String? get userName => _userName;
  String? get userBio => _userBio;
  String? get userPhotoUrl => _userPhotoUrl;

  AuthProvider() {
    _checkSession();
  }

  /// Check if user has a valid session on app start
  Future<void> _checkSession() async {
    _setLoading(true);

    try {
      final session = _supabase.auth.currentSession;

      if (session != null && !session.isExpired) {
        _user = session.user;
        _isAuthenticated = true;
        await _loadUserProfile();
      } else {
        // Try to refresh session
        await refreshSession();
      }
    } catch (e) {
      _error = 'Session check failed: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh session when app resumes
  Future<void> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;

      if (session != null) {
        if (session.isExpired) {
          final response = await _supabase.auth.refreshSession();
          if (response.session != null) {
            _user = response.user;
            _isAuthenticated = true;
            await _loadUserProfile();
          }
        } else {
          _user = session.user;
          _isAuthenticated = true;
          await _loadUserProfile();
        }
      } else {
        _isAuthenticated = false;
        _user = null;
      }
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
    }
    notifyListeners();
  }

  /// Send OTP to phone number
  Future<bool> sendOTP(String phoneNumber) async {
    _setLoading(true);
    _error = null;

    try {
      // Format phone with country code if needed
      String formattedPhone = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        formattedPhone = '+$phoneNumber';
      }

      await _supabase.auth.signInWithOtp(
        phone: formattedPhone,
      );

      _phoneNumber = formattedPhone;
      await _secureStorage.write(key: 'pending_phone', value: formattedPhone);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to send OTP: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Verify OTP and sign in
  Future<bool> verifyOTP(String otp) async {
    _setLoading(true);
    _error = null;

    try {
      final phone = _phoneNumber ?? await _secureStorage.read(key: 'pending_phone');

      if (phone == null) {
        _error = 'Phone number not found. Please start over.';
        _setLoading(false);
        return false;
      }

      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.session != null) {
        _user = response.user;
        _isAuthenticated = true;
        _phoneNumber = phone;

        // Save session data
        await _secureStorage.write(key: 'user_phone', value: phone);

        // Check if user profile exists
        await _loadUserProfile();

        _setLoading(false);
        return true;
      } else {
        _error = 'Invalid OTP. Please try again.';
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      _error = e.message;
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Verification failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Check if user profile exists in database
  Future<bool> _loadUserProfile() async {
    if (_user == null) return false;

    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', _user!.id)
          .single();

      if (response != null) {
        _userName = response['username'];
        _userBio = response['bio'];
        _userPhotoUrl = response['avatar_url'];
        _phoneNumber = response['phone'];
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Create or update user profile
  Future<bool> setupProfile({
    required String username,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);

    try {
      if (_user == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      await _supabase.from('users').upsert({
        'id': _user!.id,
        'phone': _phoneNumber,
        'username': username,
        'bio': bio ?? '',
        'avatar_url': photoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _userName = username;
      _userBio = bio;
      _userPhotoUrl = photoUrl;

      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Profile setup failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Update profile
  Future<bool> updateProfile({
    String? username,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);

    try {
      if (_user == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (photoUrl != null) updates['avatar_url'] = photoUrl;

      await _supabase.from('users').update(updates).eq('id', _user!.id);

      if (username != null) _userName = username;
      if (bio != null) _userBio = bio;
      if (photoUrl != null) _userPhotoUrl = photoUrl;

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Update failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);

    try {
      await _supabase.auth.signOut();
      await _secureStorage.deleteAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _user = null;
      _isAuthenticated = false;
      _phoneNumber = null;
      _userName = null;
      _userBio = null;
      _userPhotoUrl = null;

      notifyListeners();
    } catch (e) {
      _error = 'Sign out failed: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Delete account permanently
  Future<bool> deleteAccount() async {
    _setLoading(true);

    try {
      if (_user == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      // Delete user data from all tables
      await _supabase.from('messages').delete().eq('sender_id', _user!.id);
      await _supabase.from('chat_participants').delete().eq('user_id', _user!.id);
      await _supabase.from('user_settings').delete().eq('user_id', _user!.id);
      await _supabase.from('status_views').delete().eq('user_id', _user!.id);
      await _supabase.from('statuses').delete().eq('user_id', _user!.id);
      await _supabase.from('contacts').delete().eq('user_id', _user!.id);
      await _supabase.from('blocked_users').delete().eq('user_id', _user!.id);
      await _supabase.from('bots').delete().eq('creator_id', _user!.id);

      // Delete user profile
      await _supabase.from('users').delete().eq('id', _user!.id);

      // Sign out from auth
      await _supabase.auth.signOut();
      await _secureStorage.deleteAll();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _user = null;
      _isAuthenticated = false;
      _phoneNumber = null;
      _userName = null;
      _userBio = null;
      _userPhotoUrl = null;

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Account deletion failed: $e';
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
