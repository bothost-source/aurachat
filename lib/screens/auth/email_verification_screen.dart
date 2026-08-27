import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/app_localizations.dart';
import 'otp_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String userId;
  final String backendUrl;
  final String? autoDetectedEmail;
  final bool isLoginFlow;

  const EmailVerificationScreen({
    super.key,
    required this.userId,
    required this.backendUrl,
    this.autoDetectedEmail,
    this.isLoginFlow = false,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _emailController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _codeSent = false;
  int _resendTimer = 60;
  String? _error;
  String? _sentEmail;

  @override
  void initState() {
    super.initState();
    if (widget.autoDetectedEmail != null) {
      _emailController.text = widget.autoDetectedEmail!;
      if (widget.isLoginFlow) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
      }
    }
    _savePendingEmailState();
  }

  Future<void> _savePendingEmailState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_email_user_id', widget.userId);
    await prefs.setBool('pending_email_verification', true);
    await prefs.setInt('pending_email_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _clearPendingEmailState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_email_user_id');
    await prefs.remove('pending_email_verification');
    await prefs.remove('pending_email_timestamp');
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final response = await http.post(
        Uri.parse('${widget.backendUrl}/api/auth/send-email-verification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'userId': widget.userId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _codeSent = true;
          _resendTimer = 60;
          _sentEmail = email;
        });
        _startResendTimer();
      } else {
        final backendError = data['details'] ?? data['error'] ?? 'Unknown error';
        setState(() => _error = 'Backend: $backendError');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> _verifyCode() async {
    final code = _codeControllers.map((c) => c.text).join();

    setState(() { _isLoading = true; _error = null; });

    try {
      // 1. Verify via backend API
      final response = await http.post(
        Uri.parse('${widget.backendUrl}/api/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': widget.userId, 'code': code}),
      );

      if (response.statusCode == 200) {
        // 2. Backend verified — now complete local auth
        final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
        final verified = await authProvider.verifyEmailOtp(code);
        
        if (!verified) {
          setState(() => _error = authProvider.error ?? 'Verification failed');
          setState(() => _isLoading = false);
          return;
        }

        // FIX: Clear ALL pending states so AuthRouter doesn't loop back
        await _clearPendingEmailState();
        await OtpScreen.clearPendingOtpState();

        // FIX: Ensure mock user is persisted for app restarts
        final prefs = await SharedPreferences.getInstance();
        final mockUserId = authProvider.mockUserId;
        if (mockUserId != null) {
          await prefs.setString('mock_user_id', mockUserId);
        }

        if (mounted) {
          // FIX: Always go to main app after verification
          // Setup profile should have been done before OTP for new users
          // Existing users already have profiles
          Navigator.pushReplacementNamed(context, '/main');
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() => _error = data['error'] ?? 'Invalid code');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _codeControllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
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
                  const SizedBox(height: 40),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    ).createShader(bounds),
                    child: const Text(
                      'Verify Email',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (widget.isLoginFlow && widget.autoDetectedEmail != null) ...[
                    Text(
                      'We detected your email. Sending verification code to:',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email, color: Color(0xFF8B5CF6), size: 20),
                          const SizedBox(width: 12),
                          Text(
                            widget.autoDetectedEmail!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Text(
                      _codeSent
                        ? 'Enter the 6-digit code sent to your email'
                        : 'Enter your email to receive a verification code',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  if (!_codeSent && !widget.isLoginFlow) ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
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
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                  ] else if (_codeSent) ...[
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

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],

                  const Spacer(),

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
                        onPressed: _isLoading ? null : (_codeSent ? _verifyCode : _sendCode),
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
                                _codeSent ? 'Verify Code' : 'Send Code',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  if (_codeSent && _resendTimer > 0) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Resend in $_resendTimer seconds',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else if (_codeSent) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _sendCode,
                        child: const Text(
                          'Resend Code',
                          style: TextStyle(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
