import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _verifyOTP() async {
    final enteredOtp = _controllers.map((c) => c.text).join();

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);

    if (enteredOtp == widget.expectedOtp) {
      if (mounted) Navigator.pushReplacementNamed(context, '/setup_profile');
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Verify your number', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit code sent to '),
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => Container(
                  width: 50,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _focusNodes[index].hasFocus ? Theme.of(context).primaryColor : Colors.grey,
                      width: _focusNodes[index].hasFocus ? 2 : 1,
                    ),
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: (v) => _onOtpDigitChanged(index, v),
                  ),
                )),
              ),
              const SizedBox(height: 32),
              Center(
                child: _resendTimer > 0
                    ? Text('Resend code in $_resendTimer seconds', style: TextStyle(fontSize: 14, color: Colors.grey))
                    : TextButton(
                        onPressed: () => setState(() => _resendTimer = 60),
                        child: Text('Resend Code', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                      ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
