import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/online_status_service.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;
  String? _phoneNumber;
  String? _email;
  String? _userName;
  String? _userBio;
  String? _userPhotoUrl;
  String? _mockUserId;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  String? get email => _email;
  String? get userName => _userName;
  String? get userBio => _userBio;
  String? get userPhotoUrl => _userPhotoUrl;
  String? get mockUserId => _mockUserId;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _setLoading(true);
    try {
      final session = _supabase.auth.currentSession;

      if (session != null) {
        _user = session.user;
        _isAuthenticated = true;

        if (session.isExpired) {
          try {
            final response = await _supabase.auth.refreshSession();
            if (response.session != null) {
              _user = response.user;
              _isAuthenticated = true;
            } else {
              _isAuthenticated = false;
              _user = null;
            }
          } catch (e) {
            _isAuthenticated = false;
            _user = null;
          }
        }

        if (_isAuthenticated) {
          await _loadUserProfile();
          await OnlineStatusService.setOnline();
        }
      } else {
        // Check for mock user
        final prefs = await SharedPreferences.getInstance();
        _mockUserId = prefs.getString('mock_user_id');
        if (_mockUserId != null) {
          _isAuthenticated = true;
          _phoneNumber = prefs.getString('mock_phone');
          _userName = prefs.getString('mock_username');
          _userBio = prefs.getString('mock_bio');
          _userPhotoUrl = prefs.getString('mock_avatar');
          await _loadUserProfile();
        }
      }
    } catch (e) {
      _error = 'Auth init failed: \$e';
      debugPrint('Auth init error: \$e');
    } finally {
      _setLoading(false);
    }
  }

  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.initialSession:
          _user = session?.user;
          _isAuthenticated = session != null;
          if (_isAuthenticated) {
            _loadUserProfile();
            OnlineStatusService.setOnline();
          }
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          OnlineStatusService.setOffline();
          _clearAuth();
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  Future<void> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null && session.isExpired) {
        final response = await _supabase.auth.refreshSession();
        _user = response.user;
        _isAuthenticated = response.session != null;
        if (_isAuthenticated) await _loadUserProfile();
      } else if (session != null) {
        _user = session.user;
        _isAuthenticated = true;
        await _loadUserProfile();
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

  Future<bool> signUpWithEmail(String email, String password, String phone) async {
    _setLoading(true);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      _phoneNumber = phone;
      _email = email;
      _user = response.user;
      _isAuthenticated = response.user != null;
      _setLoading(false);
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _user = response.user;
      _isAuthenticated = true;
      _email = email;
      await _loadUserProfile();
      await OnlineStatusService.setOnline();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithOtp(String phone) async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
      _phoneNumber = phone;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String token) async {
    _setLoading(true);
    try {
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      _user = response.user;
      _isAuthenticated = response.user != null;
      _phoneNumber = phone;
      await _loadUserProfile();
      await OnlineStatusService.setOnline();
      _setLoading(false);
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    final userId = _user?.id ?? _mockUserId;
    if (userId == null) return false;
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _userName = response['username'] as String?;
        _userBio = response['bio'] as String?;
        _userPhotoUrl = response['avatar_url'] as String?;
        _phoneNumber = response['phone'] as String? ?? _phoneNumber;
        _email = response['email'] as String? ?? _email;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Profile load error: \$e');
      return false;
    }
  }

  void setMockPhone(String phone) {
    _phoneNumber = phone;
    notifyListeners();
  }

  Future<bool> setupProfile({
    required String username,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);
    try {
      // Allow mock users (no real Supabase user)
      final userId = _user?.id ?? _mockUserId ?? 'mock_\${DateTime.now().millisecondsSinceEpoch}';

      if (_user == null && _mockUserId == null) {
        _mockUserId = userId;
      }

      final now = DateTime.now().toIso8601String();
      await _supabase.from('users').upsert({
        'id': userId,
        'phone': _phoneNumber,
        'email': _email,
        'username': username,
        'bio': bio ?? '',
        'avatar_url': photoUrl,
        'created_at': now,
        'updated_at': now,
      }, onConflict: 'id');

      _userName = username;
      _userBio = bio;
      _userPhotoUrl = photoUrl;
      _isAuthenticated = true;

      // Save mock user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mock_user_id', userId);
      await prefs.setString('mock_phone', _phoneNumber ?? '');
      await prefs.setString('mock_username', username);
      await prefs.setString('mock_bio', bio ?? '');
      await prefs.setString('mock_avatar', photoUrl ?? '');

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Profile setup failed: \$e';
      debugPrint('Profile setup error: \$e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfile({
    String? username,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);
    try {
      final userId = _user?.id ?? _mockUserId;
      if (userId == null) {
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

      await _supabase.from('users').update(updates).eq('id', userId);

      if (username != null) _userName = username;
      if (bio != null) _userBio = bio;
      if (photoUrl != null) _userPhotoUrl = photoUrl;

      // Update mock prefs too
      final prefs = await SharedPreferences.getInstance();
      if (username != null) await prefs.setString('mock_username', username);
      if (bio != null) await prefs.setString('mock_bio', bio);
      if (photoUrl != null) await prefs.setString('mock_avatar', photoUrl);

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Update failed: \$e';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      if (_user != null) {
        await OnlineStatusService.setOffline();
        await _supabase.auth.signOut();
      }
      await _clearAuth();
    } catch (e) {
      _error = 'Sign out failed: \$e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _user = null;
    _isAuthenticated = false;
    _phoneNumber = null;
    _email = null;
    _userName = null;
    _userBio = null;
    _userPhotoUrl = null;
    _mockUserId = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      final userId = _user?.id ?? _mockUserId;
      if (userId == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      await _supabase.from('messages').delete().eq('sender_id', userId);
      await _supabase.from('chat_participants').delete().eq('user_id', userId);
      await _supabase.from('user_settings').delete().eq('user_id', userId);
      await _supabase.from('status_views').delete().eq('user_id', userId);
      await _supabase.from('statuses').delete().eq('user_id', userId);
      await _supabase.from('contacts').delete().eq('user_id', userId);
      await _supabase.from('blocked_users').delete().eq('user_id', userId);
      await _supabase.from('bots').delete().eq('creator_id', userId);
      await _supabase.from('users').delete().eq('id', userId);

      if (_user != null) {
        await _supabase.auth.signOut();
      }
      await _clearAuth();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Account deletion failed: \$e';
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
