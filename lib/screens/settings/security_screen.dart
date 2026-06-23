import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import '../../providers/settings_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  final _passcodeController = TextEditingController();
  final _confirmPasscodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      List<BiometricType> availableBiometrics = [];
      
      if (canCheck) {
        availableBiometrics = await _localAuth.getAvailableBiometrics();
      }

      if (mounted) {
        setState(() {
          _canCheckBiometrics = canCheck;
          _isBiometricAvailable = availableBiometrics.isNotEmpty;
          _availableBiometrics = availableBiometrics;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric check error: $e');
      if (mounted) {
        setState(() {
          _canCheckBiometrics = false;
          _isBiometricAvailable = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmPasscodeController.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometric(bool value) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    if (value) {
      if (!_isBiometricAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No biometric credentials are enrolled on this device. Please set up fingerprint or face ID in your device settings first.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      try {
        bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to enable biometric lock',
          authMessages: const [
            AndroidAuthMessages(
              signInTitle: 'Biometric Authentication',
              cancelButton: 'Cancel',
              biometricHint: 'Verify your identity',
              biometricNotRecognized: 'Not recognized, try again',
              biometricRequiredTitle: 'Biometric authentication required',
              biometricSuccess: 'Authentication successful',
              deviceCredentialsRequiredTitle: 'Device credentials required',
              deviceCredentialsSetupDescription: 'Please set up device credentials',
              goToSettingsButton: 'Go to Settings',
              goToSettingsDescription: 'Please set up biometric authentication in your device settings',
            ),
            IOSAuthMessages(
              cancelButton: 'Cancel',
              goToSettingsButton: 'Go to Settings',
              goToSettingsDescription: 'Please set up biometric authentication in your device settings',
              lockOut: 'Please re-enable biometric authentication',
            ),
          ],
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
            sensitiveTransaction: true,
            useErrorDialogs: true,
          ),
        );

        if (didAuthenticate) {
          await settingsProvider.setBiometricLock(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric lock enabled'),
                backgroundColor: Color(0xFF8B5CF6),
              ),
            );
          }
        }
      } on PlatformException catch (e) {
        debugPrint('Biometric auth error: $e');
        if (mounted) {
          String message = 'Biometric authentication failed';
          if (e.code == 'NotAvailable') {
            message = 'Biometric authentication is not available on this device';
          } else if (e.code == 'NotEnrolled') {
            message = 'No biometric credentials are enrolled. Please set up fingerprint or face ID in your device settings.';
          } else if (e.code == 'PasscodeNotSet') {
            message = 'Please set a device passcode first';
          } else if (e.code == 'no_fragment_activity') {
            message = 'App configuration issue. Please update the app.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        debugPrint('Unexpected biometric error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric error: $e')),
          );
        }
      }
    } else {
      await settingsProvider.setBiometricLock(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric lock disabled'),
            backgroundColor: Color(0xFF8B5CF6),
          ),
        );
      }
    }
  }

  void _showPasscodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Set App Passcode',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passcodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Enter 6-digit passcode',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasscodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Confirm passcode',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: Border.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _passcodeController.clear();
              _confirmPasscodeController.clear();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_passcodeController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passcode must be 6 digits')),
                );
                return;
              }
              if (_passcodeController.text != _confirmPasscodeController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passcodes do not match')),
                );
                return;
              }

              await Provider.of<SettingsProvider>(context, listen: false)
                  .setPasscode(_passcodeController.text);
              await Provider.of<SettingsProvider>(context, listen: false)
                  .setAppPasscode(true);

              _passcodeController.clear();
              _confirmPasscodeController.clear();

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passcode set successfully'),
                    backgroundColor: Color(0xFF8B5CF6),
                  ),
                );
              }
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Authentication',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6).withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          _buildToggleCard(
            icon: Icons.verified_user_outlined,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Two-Step Verification',
            subtitle: 'Add extra security to your account',
            value: settingsProvider.twoStepVerification,
            onChanged: (value) => settingsProvider.setTwoStepVerification(value),
          ),

          _buildToggleCard(
            icon: Icons.lock_outline,
            iconColor: const Color(0xFF06B6D4),
            title: 'App Passcode',
            subtitle: settingsProvider.appPasscode
                ? 'Passcode is set'
                : 'Lock app with a 6-digit code',
            value: settingsProvider.appPasscode,
            onChanged: (value) {
              if (value) {
                _showPasscodeDialog();
              } else {
                settingsProvider.setAppPasscode(false);
                settingsProvider.setPasscode('');
              }
            },
          ),

          if (_canCheckBiometrics)
            _buildToggleCard(
              icon: Icons.fingerprint,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Biometric Lock',
              subtitle: _isBiometricAvailable
                  ? 'Use fingerprint or face ID'
                  : 'No biometric credentials enrolled',
              value: settingsProvider.biometricLock,
              onChanged: _isBiometricAvailable ? _toggleBiometric : null,
            ),

          if (!_canCheckBiometrics)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fingerprint,
                      color: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biometric Lock',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Not available on this device',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          Text(
            'Security Info',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6).withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Color(0xFF06B6D4),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'About Security Features',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Two-Step Verification: Requires OTP every time you sign in on a new device.\n\n'
                  'App Passcode: Locks the app when you close it. You will need to enter the passcode to open it.\n\n'
                  'Biometric Lock: Uses your device fingerprint or face recognition to unlock the app.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.4),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    Function(bool)? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? iconColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: iconColor,
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
