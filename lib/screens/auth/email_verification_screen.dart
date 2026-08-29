import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _error;
  String? _sentEmail;
  String? _userId;
  bool _codeSent = false;
  bool _isExistingUser = false;
  int _resendTimer = 0;
  bool _resendLoading = false;

  // Store user data locally — don't touch provider until verified
  Map<String, dynamic>? _existingUserData;

  final String _backendUrl = 'https://aurachat-backend-5utu.onrender.com';

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _codeControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    if (_resendTimer > 0) return;
    setState(() => _resendTimer = 60);
    _tickResendTimer();
  }

  void _tickResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _tickResendTimer();
      }
    });
  }

  /// STEP 1: Send OTP — Check Firestore, call backend
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
      // Check Firestore for existing email
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      String userId;
      bool isExisting = false;
      Map<String, dynamic>? existingData;

      if (snapshot.docs.isNotEmpty) {
        // EXISTING USER
        isExisting = true;
        existingData = snapshot.docs.first.data();
        existingData['id'] = snapshot.docs.first.id;
        userId = snapshot.docs.first.id;
      } else {
        // NEW USER
        userId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Save to SharedPreferences directly (NOT through provider)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_email_user_id', userId);
      await prefs.setString('pending_email', email);
      if (existingData != null) {
        await prefs.setString('pending_phone', existingData['phone'] ?? '');
        await prefs.setString('pending_username', existingData['username'] ?? '');
        await prefs.setString('pending_display_name', existingData['display_name'] ?? '');
        await prefs.setString('pending_bio', existingData['bio'] ?? '');
        await prefs.setString('pending_avatar', existingData['avatar_url'] ?? '');
      }

      // Call backend to send OTP
      final response = await http.post(
        Uri.parse('$_backendUrl/api/auth/send-email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'userId': userId}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _codeSent = true;
          _sentEmail = email;
          _userId = userId;
          _isExistingUser = isExisting;
          _existingUserData = existingData;
          _isLoading = false;
        });
        _startResendTimer();
      } else {
        setState(() {
          _isLoading = false;
          _error = data['details'] ?? data['error'] ?? 'Failed to send OTP';
        });
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Request timed out. Try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  /// RESEND OTP — Same as send but without Firestore check (we already have userId)
  Future<void> _resendCode() async {
    if (_resendTimer > 0 || _sentEmail == null || _userId == null) return;

    setState(() {
      _resendLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/auth/send-email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _sentEmail, 'userId': _userId}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _resendLoading = false;
        });
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New code sent!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _resendLoading = false;
          _error = data['details'] ?? data['error'] ?? 'Failed to resend OTP';
        });
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _resendLoading = false;
        _error = 'Request timed out. Try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resendLoading = false;
        _error = 'Error: $e';
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

  /// STEP 2: Verify OTP — Call backend, then set up provider
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
      final response = await http.post(
        Uri.parse('$_backendUrl/api/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId, 'code': code}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['error'] ?? 'Invalid code';
          _isLoading = false;
        });
        for (final c in _codeControllers) c.clear();
        _focusNodes[0].requestFocus();
        return;
      }

      // Backend confirmed — NOW set up provider
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();

      final userId = _userId!;
      final email = _sentEmail!;

      // Set provider state
      authProvider.mockUserId = userId;
      authProvider.setMockEmail(email);

      // Save permanent prefs
      await prefs.setString('mock_user_id', userId);
      await prefs.setString('mock_email', email);

      if (_isExistingUser && _existingUserData != null) {
        // Existing user — restore their data
        final phone = _existingUserData!['phone'] as String?;
        final username = _existingUserData!['username'] as String?;
        final displayName = _existingUserData!['display_name'] as String?;
        final bio = _existingUserData!['bio'] as String?;
        final avatar = _existingUserData!['avatar_url'] as String?;

        await prefs.setString('mock_phone', phone ?? '');
        await prefs.setString('mock_username', username ?? '');
        await prefs.setString('mock_display_name', displayName ?? '');
        await prefs.setString('mock_bio', bio ?? '');
        await prefs.setString('mock_avatar', avatar ?? '');

        // Update Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'email_verified': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Clean up pending
      await prefs.remove('pending_email_user_id');
      await prefs.remove('pending_email');
      await prefs.remove('pending_phone');
      await prefs.remove('pending_username');
      await prefs.remove('pending_display_name');
      await prefs.remove('pending_bio');
      await prefs.remove('pending_avatar');

      if (!mounted) return;
      setState(() => _isLoading = false);

      // BOTH existing and new users go to setup_profile to confirm/change info
      Navigator.pushReplacementNamed(context, '/setup_profile');

    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Request timed out. Try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Network error: $e';
      });
    }
  }

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
                Color(0xFF0f172a),
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
                          : _resendLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _resendCode,
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
                            _resendTimer = 0;
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

                  const SizedBox(height: 16),

                  // TERMS & PRIVACY LINK
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/terms'),
                      child: Text(
                        'Terms of Service & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
