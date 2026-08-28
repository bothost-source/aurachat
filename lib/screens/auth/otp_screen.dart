import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/app_localizations.dart';
import 'email_verification_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String expectedOtp;
  final String cleanPhoneNumber;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.expectedOtp,
    required this.cleanPhoneNumber,
  });

  /// Public static method to clear pending OTP state from anywhere
  static Future<void> clearPendingOtpState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_otp_phone');
    await prefs.remove('pending_otp_expected');
    await prefs.remove('pending_otp_timestamp');
  }

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _savePendingOtpState();
  }

  Future<void> _savePendingOtpState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_otp_phone', widget.cleanPhoneNumber);
    await prefs.setString('pending_otp_expected', widget.expectedOtp);
    await prefs.setInt('pending_otp_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() => _resendTimer--);
        _startResendTimer();
      }
    });
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    _checkComplete();
  }

  void _checkComplete() {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      _verifyOTP();
    }
  }

  // ==========================================================================
  // FIXED: _verifyOTP() — Proper error handling, no fake delay, no silent failures
  // ==========================================================================
  void _verifyOTP() async {
    final enteredOtp = _controllers.map((c) => c.text).join();

    setState(() => _isLoading = true);

    try {
      // Wrong OTP
      if (enteredOtp != widget.expectedOtp) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.get('invalid_otp')),
              backgroundColor: Colors.red.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      authProvider.setMockPhone(widget.cleanPhoneNumber);

      final existingUser = await authProvider.checkPhoneExists(widget.cleanPhoneNumber);

      if (existingUser != null) {
        // ========== EXISTING USER ==========
        final success = await authProvider.loginExistingUser(
          widget.cleanPhoneNumber,
          userData: existingUser,
        );

        if (!success) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.error ?? 'Login failed. Please try again.'),
                backgroundColor: Colors.red.withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }

        final existingEmail = existingUser['email'] as String?;

        if (existingEmail != null && existingEmail.isNotEmpty) {
          // User has email — send OTP and navigate
          final otpSent = await authProvider.sendEmailOtp();

          if (!otpSent) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(authProvider.error ?? 'Failed to send email OTP'),
                  backgroundColor: Colors.red.withOpacity(0.9),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
            return;
          }

          setState(() => _isLoading = false);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EmailVerificationScreen(
                  userId: existingUser['id'] as String,
                  backendUrl: 'https://aurachat-backend-5utu.onrender.com',
                  autoDetectedEmail: existingEmail,
                  isLoginFlow: true,
                ),
              ),
            );
          }
        } else {
          // Existing user but no email — go to profile setup
          await _completeLoginAndClear(authProvider);
        }

      } else {
        // ========== NEW USER ==========
        await authProvider.createMockUser();
        setState(() => _isLoading = false);
        if (mounted) {
          // New users: go to email verification to collect email
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                userId: authProvider.mockUserId!,
                backendUrl: 'https://aurachat-backend-5utu.onrender.com',
                isLoginFlow: false,
              ),
            ),
          );
        }
      }

    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      debugPrint('OTP verification error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _completeLoginAndClear(AuraAuthProvider authProvider) async {
    final prefs = await SharedPreferences.getInstance();
    final mockUserId = authProvider.mockUserId;
    if (mockUserId != null) {
      await prefs.setString('mock_user_id', mockUserId);
      await prefs.setString('mock_phone', widget.cleanPhoneNumber);
    }
    await OtpScreen.clearPendingOtpState();
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/setup_profile');
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white.withOpacity(0.7),
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                  ).createShader(bounds),
                  child: Text(
                    AppLocalizations.get('verify_number'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: AppLocalizations.get('enter_code_sent_to') + ' '),
                      TextSpan(
                        text: widget.phoneNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _focusNodes[index].hasFocus
                                  ? const Color(0xFF8B5CF6).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.08),
                              width: _focusNodes[index].hasFocus ? 2 : 1,
                            ),
                            boxShadow: _focusNodes[index].hasFocus
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                      blurRadius: 12,
                                      spreadRadius: -2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (v) => _onOtpDigitChanged(index, v),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),

                Center(
                  child: _resendTimer > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Text(
                            '${AppLocalizations.get('resend_code_in')} $_resendTimer seconds',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _resendTimer = 60),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.get('resend_code'),
                              style: const TextStyle(
                                color: Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                ),
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
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOTP,
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
                              AppLocalizations.get('verify'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
