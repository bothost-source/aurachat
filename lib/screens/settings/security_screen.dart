import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/settings_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  final _passcodeController = TextEditingController();
  final _confirmPasscodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheck = await _localAuth.canCheckBiometrics;
    setState(() {
      _canCheckBiometrics = canCheck;
    });
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    _confirmPasscodeController.dispose();
    super.dispose();
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      try {
        bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to enable biometric lock',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        if (didAuthenticate) {
          await Provider.of<SettingsProvider>(context, listen: false)
              .setBiometricLock(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric error: $e')),
          );
        }
      }
    } else {
      await Provider.of<SettingsProvider>(context, listen: false)
          .setBiometricLock(false);
    }
  }

  void _showPasscodeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set App Passcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _passcodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter 6-digit passcode',
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasscodeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm passcode',
                counterText: '',
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
            child: const Text('Cancel'),
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
                  const SnackBar(content: Text('Passcode set successfully')),
                );
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Authentication'),

          _buildToggleTile(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Two-Step Verification',
            subtitle: 'Add extra security to your account',
            value: settingsProvider.twoStepVerification,
            onChanged: (value) => settingsProvider.setTwoStepVerification(value),
          ),

          _buildToggleTile(
            context,
            icon: Icons.lock_outline,
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
            _buildToggleTile(
              context,
              icon: Icons.fingerprint,
              title: 'Biometric Lock',
              subtitle: 'Use fingerprint or face ID',
              value: settingsProvider.biometricLock,
              onChanged: _toggleBiometric,
            ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Security Info'),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About Security Features',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Two-Step Verification: Requires OTP every time you sign in on a new device.\n\n'
                  'App Passcode: Locks the app when you close it. You will need to enter the passcode to open it.\n\n'
                  'Biometric Lock: Uses your device fingerprint or face recognition to unlock the app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
