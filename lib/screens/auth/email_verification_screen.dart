import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/app_localizations.dart';

/// ============================================================================
/// EMAIL VERIFICATION SCREEN — Main Login Entry Point
/// 
/// This is the FIRST screen users see. They enter their email, we send an OTP
/// via the backend, they verify it, and we route them accordingly.
/// ============================================================================
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // Step 1: Email input
  final _emailController = TextEditingController();

  // Step 2: OTP input
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  // State
  bool _isLoading = false;
  String? _error;
  String? _sentEmail;
  String? _userId;
  bool _codeSent = false;
  bool _isExistingUser = false;
  int _resendTimer = 60;

  final String _backendUrl = 'https://aurachat-backend-5utu.onrender.com';

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _codeControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  /// ==========================================================================
  /// STEP 1: Send OTP to email (via backend)
  /// ==========================================================================
  Future<void> _sendCode() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);

      // Check if this email already has an account
      final existingUser = await authProvider.checkEmailExists(email);

      String userId;
      bool isExisting;

      if (existingUser != null) {
        // Existing user
        userId = existingUser['id'] as String;
        isExisting = true;

        // Save their data to provider
        authProvider.setMockEmail(email);
        authProvider.setMockUserId(userId);
        await authProvider.savePendingUserData(
          userId: userId,
          email: email,
          phone: existingUser['phone'] as String?,
          username: existingUser['username'] as String?,
          displayName: existingUser['display_name'] as String?,
          bio: existingUser['bio'] as String?,
          avatarUrl: existingUser['avatar_url'] as String?,
        );
      } else {
        // New user - create a temp ID
        userId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
        isExisting = false;

        authProvider.setMockEmail(email);
        authProvider.setMockUserId(userId);
        await authProvider.savePendingUserData(
          userId: userId,
          email: email,
        );
      }

      // Call backend to send email OTP
      final response = await http.post(
        Uri.parse('$_backendUrl/api/auth/send-email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'userId': userId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _codeSent = true;
          _resendTimer = 60;
          _sentEmail = email;
          _userId = userId;
          _isExistingUser = isExisting;
          _isLoading = false;
        });
        _startResendTimer();
      } else {
        setState(() {
          _isLoading = false;
          _error = data['details'] ?? data['error'] ?? 'Failed to send OTP';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Network error: $e';
      });
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_codeControllers.every((c) => c.text.isNotEmpty)) {
      _verifyCode();
    }
  }

  /// ==========================================================================
  /// STEP 2: Verify OTP with backend
  /// ==========================================================================
  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();

    if (code.length != 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verify with BACKEND (source of truth)
      final response = await http.post(
        Uri.parse('$_backendUrl/api/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'code': code}),
      );

      debugPrint('Backend verify response: ${response.statusCode} - ${response.body}');

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['error'] ?? 'Invalid code';
          _isLoading = false;
        });
        // Clear code fields for retry
        for (final c in _codeControllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        return;
      }

      // Backend confirmed — complete login locally
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final verified = await authProvider.completeEmailVerification(_userId!);

      if (!verified) {
        setState(() {
          _error = authProvider.error ?? 'Verification failed';
          _isLoading = false;
        });
        return;
      }

      // Clean up
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_email_user_id');
      await prefs.remove('pending_email_verification');
      await prefs.remove('pending_email_timestamp');

      // Route based on user type
      if (mounted) {
        setState(() => _isLoading = false);

        if (_isExistingUser) {
          // Existing user -> Main app
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          // New user -> Profile setup
          Navigator.pushReplacementNamed(context, '/setup_profile');
        }
      }

    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  /// ==========================================================================
  /// UI
  /// ==========================================================================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0A0F),
                Color(0xFF1a103c),
                Color(0xFF0d1b2a),
                Color(0xFF0A0A0F),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ).createShader(bounds),
                    child: Text(
                      _codeSent ? 'Verify Email' : 'Welcome to AURA',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    _codeSent
                        ? 'Enter the 6-digit code sent to $_sentEmail'
                        : "Enter your email to get started. We'll send you a verification code.",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email input (Step 1)
                  if (!_codeSent) ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'your@email.com',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                        ),
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF8B5CF6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      ),
                    ),
                  ],

                  // OTP input (Step 2)
                  if (_codeSent) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _focusNodes[index].hasFocus
                                  ? const Color(0xFF8B5CF6).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _codeControllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (v) => _onCodeChanged(index, v),
                          ),
                        );
                      }),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Error display
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Spacer(),

                  // Main button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_codeSent ? _verifyCode : _sendCode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _codeSent ? 'Verify Code' : 'Continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  // Resend / Back options
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: _resendTimer > 0
                          ? Text(
                              'Resend in $_resendTimer seconds',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 14,
                              ),
                            )
                          : TextButton(
                              onPressed: _sendCode,
                              child: const Text(
                                'Resend Code',
                                style: TextStyle(color: Color(0xFF8B5CF6)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _codeSent = false;
                            _error = null;
                            for (final c in _codeControllers) {
                              c.clear();
                            }
                          });
                        },
                        child: const Text(
                          'Use different email',
                          style: TextStyle(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Terms
                  if (!_codeSent)
                    Center(
                      child: Text(
                        'By continuing, you agree to our Terms and Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
