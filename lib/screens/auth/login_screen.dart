import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../services/notification_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  PhoneNumber? _phoneNumber;
  bool _isLoading = false;
  String? _errorMessage;

  final Set<String> _registeredNumbers = {
    '2341313565656',
    '2348012345678',
  };

  final Set<String> _bannedNumbers = {
    '2349999999999',
    '2348888888888',
  };

  String _generateOTP() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  Future<void> _saveRegisteredNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_numbers') ?? [];
    if (!registered.contains(phone)) {
      registered.add(phone);
      await prefs.setStringList('registered_numbers', registered);
    }
  }

  Future<Set<String>> _getRegisteredNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_numbers') ?? [];
    return {..._registeredNumbers, ...registered};
  }

  Future<Set<String>> _getBannedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final banned = prefs.getStringList('banned_numbers') ?? [];
    return {..._bannedNumbers, ...banned};
  }

  void _requestOTP() async {
    if (_phoneNumber == null || _phoneNumber!.number.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid phone number');
      return;
    }

    String cleanNumber = _phoneNumber!.completeNumber.replaceAll('+', '').replaceAll(' ', '');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    final bannedNumbers = await _getBannedNumbers();
    if (bannedNumbers.contains(cleanNumber)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'This number has been permanently banned. Contact support.';
      });
      return;
    }

        // Check if number is already registered
    final registeredNumbers = await _getRegisteredNumbers();
    if (registeredNumbers.contains(cleanNumber)) {
      // Already registered - just send OTP to log in
      // Don't block, continue with OTP
    }

    final otp = _generateOTP();
    final fullPhone = _phoneNumber!.completeNumber;

    await _saveRegisteredNumber(cleanNumber);
    await NotificationService.showOTP(otp, fullPhone);

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            phoneNumber: fullPhone,
            expectedOtp: otp,
            cleanPhoneNumber: cleanNumber,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.chat_bubble, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 32),
              const Text('Enter your phone number', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text('TARRIFIC CHAT will send you a one-time password to verify your number.', style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5)),
              const SizedBox(height: 40),

              IntlPhoneField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.white),
                dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                dropdownTextStyle: const TextStyle(color: Colors.white),
                flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 12),
                initialCountryCode: 'NG',
                languageCode: 'en',
                onChanged: (phone) {
                  setState(() {
                    _phoneNumber = phone;
                    _errorMessage = null;
                  });
                },
                invalidNumberMessage: 'Invalid phone number for this country',
                disableLengthCheck: false,
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can hide your phone number after signup. Other users will only see your username.',
                        style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Request OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/terms'),
                  child: const Text('Back to Terms', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
