import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  String? get email => _email;
  String? get userName => _userName;
  String? get userBio => _userBio;
  String? get userPhotoUrl => _userPhotoUrl;

  AuthProvider() {
    _initAuth();
  }

  /// Initialize auth state
  Future<void> _initAuth() async {
    _setLoading(true);
    try {
      // Supabase automatically restores session from local storage
      final session = _supabase.auth.currentSession;
      
      if (session != null) {
        _user = session.user;
        _isAuthenticated = true;
        
        // Try to refresh if expired
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
        }
      }
    } catch (e) {
      _error = 'Auth init failed: $e';
      debugPrint('Auth init error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Listen to auth changes (call this from main.dart or splash)
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
          if (_isAuthenticated) _loadUserProfile();
          break;
        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
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

  /// Sign up with email (for profile creation after OTP verification)
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

  /// Sign in with email and password
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
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  /// Phone OTP sign in
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

  /// Verify OTP and complete sign in
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
      _setLoading(false);
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    if (_user == null) return false;
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', _user!.id)
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
      debugPrint('Profile load error: $e');
      return false;
    }
  }

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

      final now = DateTime.now().toIso8601String();
      await _supabase.from('users').upsert({
        'id': _user!.id,
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
      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Profile setup failed: $e';
      debugPrint('Profile setup error: $e');
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

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
      await _clearAuth();
    } catch (e) {
      _error = 'Sign out failed: $e';
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
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      if (_user == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      await _supabase.from('messages').delete().eq('sender_id', _user!.id);
      await _supabase.from('chat_participants').delete().eq('user_id', _user!.id);
      await _supabase.from('user_settings').delete().eq('user_id', _user!.id);
      await _supabase.from('status_views').delete().eq('user_id', _user!.id);
      await _supabase.from('statuses').delete().eq('user_id', _user!.id);
      await _supabase.from('contacts').delete().eq('user_id', _user!.id);
      await _supabase.from('blocked_users').delete().eq('user_id', _user!.id);
      await _supabase.from('bots').delete().eq('creator_id', _user!.id);
      await _supabase.from('users').delete().eq('id', _user!.id);

      await _supabase.auth.signOut();
      await _clearAuth();
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
