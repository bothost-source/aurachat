import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/online_status_service.dart';
import '../../providers/settings_provider.dart';

class AuraAuthProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  firebase_auth.User? _user;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;
  String? _phoneNumber;
  String? _email;
  String? _userName;
  String? _displayName;
  String? _userBio;
  String? _userPhotoUrl;
  String? _mockUserId;

  firebase_auth.User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get phoneNumber => _phoneNumber;
  String? get email => _email;
  String? get userName => _userName;
  String? get displayName => _displayName;
  String? get userBio => _userBio;
  String? get userPhotoUrl => _userPhotoUrl;

  String? get mockUserId => _mockUserId;

  String? get currentUserId => _user?.uid ?? _mockUserId;

  set mockUserId(String? value) {
    _mockUserId = value;
    notifyListeners();
  }

  AuraAuthProvider() {
    _initAuth();
  }

  /// ==================== INIT AUTH ====================
  Future<void> _initAuth() async {
    _setLoading(true);
    try {
      _user = _auth.currentUser;

      if (_user != null) {
        _isAuthenticated = true;
        await _loadUserProfile();
        await OnlineStatusService.setOnline();
      } else {
        final prefs = await SharedPreferences.getInstance();
        _mockUserId = prefs.getString('mock_user_id');
        if (_mockUserId != null) {
          _isAuthenticated = true;
          _phoneNumber = prefs.getString('mock_phone');
          _userName = prefs.getString('mock_username');
          _displayName = prefs.getString('mock_display_name');
          _userBio = prefs.getString('mock_bio');
          _userPhotoUrl = prefs.getString('mock_avatar');
          _email = prefs.getString('mock_email');
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

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'id': userId,
          'username': data['username'] ?? data['display_name'] ?? 'Unknown',
          'display_name': data['display_name'],
          'avatar_url': data['avatar_url'],
          'bio': data['bio'],
          'phone': data['phone'],
          'is_verified': data['is_verified'] == true,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Get user profile error: $e');
      return null;
    }
  }

  /// ==================== CHECK IF PHONE EXISTS ====================
  Future<Map<String, dynamic>?> checkPhoneExists(String phone) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Check phone error: $e');
      return null;
    }
  }

  /// ==================== LOGIN EXISTING USER (ENFORCES EMAIL OTP) ====================
  Future<bool> loginExistingUser(String phone) async {
    _setLoading(true);
    try {
      final userData = await checkPhoneExists(phone);
      if (userData == null) {
        _error = 'User not found';
        _setLoading(false);
        return false;
      }

      final userId = userData['id'] as String?;
      if (userId == null) {
        _error = 'Invalid user data';
        _setLoading(false);
        return false;
      }

      _phoneNumber = phone;
      _email = userData['email'] as String?;
      _userName = userData['username'] as String?;
      _displayName = userData['display_name'] as String?;
      _userBio = userData['bio'] as String?;
      _userPhotoUrl = userData['avatar_url'] as String?;
      _mockUserId = userId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_mock_user_id', userId);
      await prefs.setString('pending_mock_phone', phone);
      await prefs.setString('pending_mock_username', _userName ?? '');
      await prefs.setString('pending_mock_display_name', _displayName ?? '');
      await prefs.setString('pending_mock_bio', _userBio ?? '');
      await prefs.setString('pending_mock_avatar', _userPhotoUrl ?? '');
      await prefs.setString('pending_mock_email', _email ?? '');

      final isEmailVerified = userData['email_verified'] == true;
      if (isEmailVerified) {
        await _completeLogin(prefs);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Login failed: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Complete login after email verification
  Future<void> _completeLogin(SharedPreferences prefs) async {
    _isAuthenticated = true;

    await prefs.setString('mock_user_id', _mockUserId!);
    await prefs.setString('mock_phone', _phoneNumber ?? '');
    await prefs.setString('mock_username', _userName ?? '');
    await prefs.setString('mock_display_name', _displayName ?? '');
    await prefs.setString('mock_bio', _userBio ?? '');
    await prefs.setString('mock_avatar', _userPhotoUrl ?? '');
    await prefs.setString('mock_email', _email ?? '');

    await prefs.remove('pending_mock_user_id');
    await prefs.remove('pending_mock_phone');
    await prefs.remove('pending_mock_username');
    await prefs.remove('pending_mock_display_name');
    await prefs.remove('pending_mock_bio');
    await prefs.remove('pending_mock_avatar');
    await prefs.remove('pending_mock_email');

    try {
      final settingsProvider = SettingsProvider();
      settingsProvider.setMockUserId(_mockUserId!);
    } catch (e) {
      debugPrint('SettingsProvider sync error: $e');
    }

    notifyListeners();
  }

  /// ==================== SEND EMAIL OTP ====================
  Future<bool> sendEmailOtp() async {
    _setLoading(true);
    try {
      if (_email == null || _mockUserId == null) {
        _error = 'No email available';
        _setLoading(false);
        return false;
      }

      final otp = (100000 + DateTime.now().millisecond * 900000 ~/ 1000).toString().padLeft(6, '0');
      final expiry = DateTime.now().add(const Duration(minutes: 10));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_otp_code', otp);
      await prefs.setString('email_otp_expiry', expiry.toIso8601String());

      debugPrint('EMAIL OTP FOR $_email: $otp');

      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Failed to send OTP: $e';
      _setLoading(false);
      return false;
    }
  }

  /// ==================== VERIFY EMAIL OTP ====================
  Future<bool> verifyEmailOtp(String otpCode) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingUserId = prefs.getString('pending_mock_user_id');
      final storedOtp = prefs.getString('email_otp_code');
      final otpExpiry = prefs.getString('email_otp_expiry');

      if (pendingUserId == null || _mockUserId == null) {
        _error = 'No pending login';
        _setLoading(false);
        return false;
      }

      if (storedOtp == null || otpExpiry == null) {
        _error = 'No OTP sent. Request a new code.';
        _setLoading(false);
        return false;
      }

      final expiry = DateTime.parse(otpExpiry);
      if (DateTime.now().isAfter(expiry)) {
        _error = 'OTP expired. Request a new code.';
        _setLoading(false);
        return false;
      }

      if (otpCode != storedOtp) {
        _error = 'Invalid OTP code';
        _setLoading(false);
        return false;
      }

      await _firestore.collection('users').doc(pendingUserId).update({
        'email_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _completeLogin(prefs);
      await OnlineStatusService.setOnline();

      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Email verification failed: $e';
      _setLoading(false);
      return false;
    }
  }

  void listenToAuthChanges() {
    _auth.authStateChanges().listen((firebase_auth.User? user) {
      if (user != null) {
        _user = user;
        _isAuthenticated = true;
        _loadUserProfile();
        OnlineStatusService.setOnline();
      } else {
        OnlineStatusService.setOffline();
        _clearAuth();
      }
      notifyListeners();
    });
  }

  Future<void> refreshSession() async {
    try {
      _user = _auth.currentUser;
      _isAuthenticated = _user != null || _mockUserId != null;
      if (_isAuthenticated) await _loadUserProfile();
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
    }
    notifyListeners();
  }

  Future<bool> signUpWithEmail(String email, String password, String phone) async {
    _setLoading(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _phoneNumber = phone;
      _email = email;
      _user = cred.user;
      _isAuthenticated = cred.user != null;
      _setLoading(false);
      return cred.user != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = cred.user;
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
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          _error = e.message;
        },
        codeSent: (String verificationId, int? resendToken) {
          _phoneNumber = phone;
          _storeVerificationId(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> _storeVerificationId(String verificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('verification_id', verificationId);
  }

  Future<bool> verifyOtp(String phone, String token) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final verificationId = prefs.getString('verification_id');
      if (verificationId == null) {
        _error = 'Verification ID not found';
        _setLoading(false);
        return false;
      }

      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: token,
      );

      final cred = await _auth.signInWithCredential(credential);
      _user = cred.user;
      _isAuthenticated = cred.user != null;
      _phoneNumber = phone;
      await _loadUserProfile();
      await OnlineStatusService.setOnline();
      _setLoading(false);
      return cred.user != null;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> _loadUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _userName = data['username'] as String?;
        _displayName = data['display_name'] as String?;
        _userBio = data['bio'] as String?;
        _userPhotoUrl = data['avatar_base64'] as String? ?? data['avatar_url'] as String?;
        _phoneNumber = data['phone'] as String? ?? _phoneNumber;
        _email = data['email'] as String? ?? _email;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Profile load error: $e');
      return false;
    }
  }

  void setMockPhone(String phone) {
    _phoneNumber = phone;
    notifyListeners();
  }

  Future<void> createMockUser() async {
    final prefs = await SharedPreferences.getInstance();
    _mockUserId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    _isAuthenticated = true;
    await prefs.setString('mock_user_id', _mockUserId!);

    try {
      final settingsProvider = SettingsProvider();
      settingsProvider.setMockUserId(_mockUserId);
    } catch (e) {
      debugPrint('SettingsProvider sync error: $e');
    }

    notifyListeners();
  }

  Future<bool> setupProfile({
    required String username,
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);
    try {
      final userId = currentUserId ?? 'mock_${DateTime.now().millisecondsSinceEpoch}';

      if (_user == null && _mockUserId == null) {
        _mockUserId = userId;
      }

      final now = DateTime.now().toIso8601String();
      await _firestore.collection('users').doc(userId).set({
        'id': userId,
        'phone': _phoneNumber,
        'email': _email,
        'username': username,
        'display_name': displayName ?? username,
        'bio': bio ?? '',
        'avatar_url': photoUrl,
        'created_at': now,
        'updated_at': now,
      }, SetOptions(merge: true));

      _userName = username;
      _displayName = displayName ?? username;
      _userBio = bio;
      _userPhotoUrl = photoUrl;
      _isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mock_user_id', userId);
      await prefs.setString('mock_phone', _phoneNumber ?? '');
      await prefs.setString('mock_username', username);
      await prefs.setString('mock_display_name', displayName ?? username);
      await prefs.setString('mock_bio', bio ?? '');
      await prefs.setString('mock_avatar', photoUrl ?? '');
      await prefs.setString('mock_email', _email ?? '');

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
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    _setLoading(true);
    try {
      final userId = currentUserId;
      if (userId == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (username != null) updates['username'] = username;
      if (displayName != null) updates['display_name'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (photoUrl != null) updates['avatar_url'] = photoUrl;

      await _firestore.collection('users').doc(userId).set(
        updates,
        SetOptions(merge: true),
      );

      if (username != null) _userName = username;
      if (displayName != null) _displayName = displayName;
      if (bio != null) _userBio = bio;
      if (photoUrl != null) _userPhotoUrl = photoUrl;

      final prefs = await SharedPreferences.getInstance();
      if (username != null) await prefs.setString('mock_username', username);
      if (displayName != null) await prefs.setString('mock_display_name', displayName);
      if (bio != null) await prefs.setString('mock_bio', bio);
      if (photoUrl != null) await prefs.setString('mock_avatar', photoUrl);

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Update failed: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePhoneNumber(String newPhone) async {
    _setLoading(true);
    try {
      final userId = currentUserId;
      if (userId == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      final existing = await checkPhoneExists(newPhone);
      if (existing != null) {
        _error = 'Phone number already in use';
        _setLoading(false);
        return false;
      }

      await _firestore.collection('users').doc(userId).update({
        'phone': newPhone,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _phoneNumber = newPhone;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mock_phone', newPhone);

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Change number failed: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changeEmail(String newEmail) async {
    _setLoading(true);
    try {
      final userId = currentUserId;
      if (userId == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      await _firestore.collection('users').doc(userId).update({
        'email': newEmail,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _email = newEmail;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mock_email', newEmail);

      notifyListeners();
      _setLoading(false);
      return true;
    } catch (e) {
      _error = 'Change email failed: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      if (_user != null) {
        await OnlineStatusService.setOffline();
        await _auth.signOut();
      }
      await _clearAuth();
    } catch (e) {
      _error = 'Sign out failed: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mock_user_id');
    await prefs.remove('mock_phone');
    await prefs.remove('mock_username');
    await prefs.remove('mock_display_name');
    await prefs.remove('mock_bio');
    await prefs.remove('mock_avatar');
    await prefs.remove('mock_email');
    await prefs.remove('pending_mock_user_id');
    await prefs.remove('pending_mock_phone');
    await prefs.remove('pending_mock_username');
    await prefs.remove('pending_mock_display_name');
    await prefs.remove('pending_mock_bio');
    await prefs.remove('pending_mock_avatar');
    await prefs.remove('pending_mock_email');
    await prefs.remove('email_otp_code');
    await prefs.remove('email_otp_expiry');
    await prefs.remove('verification_id');

    _user = null;
    _isAuthenticated = false;
    _phoneNumber = null;
    _email = null;
    _userName = null;
    _displayName = null;
    _userBio = null;
    _userPhotoUrl = null;
    _mockUserId = null;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      final userId = currentUserId;
      if (userId == null) {
        _error = 'Not authenticated';
        _setLoading(false);
        return false;
      }

      await _firestore.collection('messages').where('sender_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('chat_participants').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('user_settings').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('status_views').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('statuses').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('contacts').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('blocked_users').where('user_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('bots').where('creator_id', isEqualTo: userId).get().then((snapshot) {
        for (var doc in snapshot.docs) doc.reference.delete();
      });
      await _firestore.collection('users').doc(userId).delete();

      if (_user != null) {
        await _auth.signOut();
      }
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
