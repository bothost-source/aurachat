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

  // Demo: In production, these come from your backend database
  // Format: phone number without + (e.g., "2341313565656")
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

  // Save registered number locally (for demo purposes)
  Future<void> _saveRegisteredNumber(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_numbers') ?? [];
    if (!registered.contains(phone)) {
      registered.add(phone);
      await prefs.setStringList('registered_numbers', registered);
    }
  }

  // Get all registered numbers
  Future<Set<String>> _getRegisteredNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final registered = prefs.getStringList('registered_numbers') ?? [];
    return {..._registeredNumbers, ...registered};
  }

  // Get all banned numbers
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

    // Clean the number for checking
    String cleanNumber = _phoneNumber!.completeNumber.replaceAll('+', '').replaceAll(' ', '');
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate network

    // Check if number is banned
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
      setState(() {
        _isLoading = false;
        _errorMessage = 'This number is already registered. Please log in instead.';
      });
      // Optionally: Navigate to login with this number
      return;
    }

    // Generate OTP
    final otp = _generateOTP();
    final fullPhone = _phoneNumber!.completeNumber;
    
    // Save as registered (for demo - in production, save after OTP verification)
    await _saveRegisteredNumber(cleanNumber);
    
    // Show local notification with OTP
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
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.chat_bubble, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 32),
              const Text('Enter your phone number', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('TARRIFIC CHAT will send you a one-time password to verify your number.', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 40),
              
              // NEW: Real phone validation with country picker
              IntlPhoneField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                  filled: true,
                  fillColor: AppTheme.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.error, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                ),
                style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                dropdownIcon: const Icon(Icons.arrow_drop_down, color: AppTheme.textTertiary),
                dropdownTextStyle: const TextStyle(color: AppTheme.textPrimary),
                flagsButtonPadding: const EdgeInsets.symmetric(horizontal: 12),
                initialCountryCode: 'NG', // Default to Nigeria
                languageCode: 'en',
                onChanged: (phone) {
                  setState(() {
                    _phoneNumber = phone;
                    _errorMessage = null;
                  });
                },
                onCountryChanged: (country) {
                  print('Country changed to: ${country.name}');
                },
                invalidNumberMessage: 'Invalid phone number for this country',
                disableLengthCheck: false, // Enforces country-specific length
              ),
              
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppTheme.bgSecondary, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can hide your phone number after signup. Other users will only see your username.',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
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
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.bgElevated,
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
                  child: const Text('Back to Terms', style: TextStyle(color: AppTheme.textTertiary)),
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

