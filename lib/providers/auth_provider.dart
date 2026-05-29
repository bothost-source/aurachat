import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _termsAccepted = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get termsAccepted => _termsAccepted;
  bool get canCreateBots => _currentUser?.canCreateBots ?? false;
  bool get isRestricted => _currentUser?.restrictionStatus != AccountRestriction.none;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void acceptTerms() {
    _termsAccepted = true;
    notifyListeners();
  }

  Future<void> loginWithPhone(String phoneNumber) async {
    setLoading(true);
    setError(null);
    await Future.delayed(const Duration(seconds: 2));
    setLoading(false);
  }

  Future<void> verifyOTP(String otp) async {
    setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      phoneNumber: '+2348012345678',
      username: 'tarrific_user',
      displayName: 'TARRIFIC User',
      bio: 'Building the future with TARRIFIC CHAT',
      avatarUrl: null,
      accountType: AccountType.personal,
      verificationLevel: VerificationLevel.verified,
      status: UserStatus.online,
      createdAt: DateTime.now(),
    );
    setLoading(false);
    notifyListeners();
  }

  Future<void> setupProfile({required String displayName, String? username, String? bio}) async {
    if (_currentUser == null) return;
    setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      username: username,
      bio: bio,
    );
    setLoading(false);
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _termsAccepted = false;
    notifyListeners();
  }

  void updatePrivacySetting(String setting, PrivacySetting value) {
    if (_currentUser == null) return;
    switch (setting) {
      case 'phone':
        _currentUser = _currentUser!.copyWith(phoneVisibility: value);
        break;
      case 'lastSeen':
        _currentUser = _currentUser!.copyWith(lastSeenVisibility: value);
        break;
      case 'profilePhoto':
        _currentUser = _currentUser!.copyWith(profilePhotoVisibility: value);
        break;
      case 'forward':
        _currentUser = _currentUser!.copyWith(forwardMessageVisibility: value);
        break;
      case 'groups':
        _currentUser = _currentUser!.copyWith(addToGroups: value);
        break;
      case 'voiceCall':
        _currentUser = _currentUser!.copyWith(voiceCallPermission: value);
        break;
      case 'videoCall':
        _currentUser = _currentUser!.copyWith(videoCallPermission: value);
        break;
    }
    notifyListeners();
  }

  void toggleTwoFactor(bool enabled) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(twoFactorEnabled: enabled);
    notifyListeners();
  }

  void togglePasscode(bool enabled) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(passcodeEnabled: enabled);
    notifyListeners();
  }

  void blockUser(String userId) {
    if (_currentUser == null) return;
    final blocked = [..._currentUser!.blockedUsers, userId];
    _currentUser = _currentUser!.copyWith(blockedUsers: blocked);
    notifyListeners();
  }

  void unblockUser(String userId) {
    if (_currentUser == null) return;
    final blocked = _currentUser!.blockedUsers.where((id) => id != userId).toList();
    _currentUser = _currentUser!.copyWith(blockedUsers: blocked);
    notifyListeners();
  }
}
