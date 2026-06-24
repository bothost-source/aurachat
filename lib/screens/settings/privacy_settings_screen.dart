import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
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
          child: Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              return Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
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
                        const SizedBox(width: 16),
                        const Text(
                          'Privacy',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // ── Who Can See My Info ──
                        _buildSectionHeader('Who Can See My Info'),
                        _buildGlassToggleTile(
                          icon: Icons.phone_outlined,
                          title: 'Phone Number',
                          subtitle: 'Show my phone number to others',
                          value: settings.phoneNumberVisible,
                          onChanged: (v) => settings.setPhoneNumberVisible(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.access_time_outlined,
                          title: 'Last Seen',
                          subtitle: 'Show when I was last online',
                          value: settings.lastSeenVisible,
                          onChanged: (v) => settings.setLastSeenVisible(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.photo_outlined,
                          title: 'Profile Photo',
                          subtitle: 'Show my profile photo to others',
                          value: settings.profilePhotoVisible,
                          onChanged: (v) => settings.setProfilePhotoVisible(v),
                        ),

                        const SizedBox(height: 24),

                        // ── Messaging ──
                        _buildSectionHeader('Messaging'),
                        _buildGlassToggleTile(
                          icon: Icons.forward_to_inbox_outlined,
                          title: 'Forwarded Messages',
                          subtitle: 'Allow others to forward my messages',
                          value: settings.forwardedMessages,
                          onChanged: (v) => settings.setForwardedMessages(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.group_add_outlined,
                          title: 'Add to Groups',
                          subtitle: 'Allow others to add me to groups',
                          value: settings.addToGroups,
                          onChanged: (v) => settings.setAddToGroups(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.call_outlined,
                          title: 'Voice & Video Calls',
                          subtitle: 'Allow others to call me',
                          value: settings.voiceVideoCallsVisible,
                          onChanged: (v) => settings.setVoiceVideoCallsVisible(v),
                        ),

                        const SizedBox(height: 24),

                        // ── Find Me ──
                        _buildSectionHeader('Find Me'),
                        _buildGlassToggleTile(
                          icon: Icons.phone_android_outlined,
                          title: 'Find by Phone Number',
                          subtitle: 'People can find me using my phone',
                          value: settings.findByPhone,
                          onChanged: (v) => settings.setFindByPhone(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.alternate_email_outlined,
                          title: 'Find by Username',
                          subtitle: 'People can find me using my username',
                          value: settings.findByUsername,
                          onChanged: (v) => settings.setFindByUsername(v),
                        ),

                        const SizedBox(height: 24),

                        // ── Security ──
                        _buildSectionHeader('Security'),
                        _buildGlassToggleTile(
                          icon: Icons.fingerprint,
                          title: 'Biometric Lock',
                          subtitle: 'Lock app with fingerprint/face',
                          value: settings.biometricLock,
                          onChanged: (v) => settings.setBiometricLock(v),
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.lock_outline,
                          title: 'App Passcode',
                          subtitle: 'Lock app with a PIN',
                          value: settings.appPasscode,
                          onChanged: (v) => settings.setAppPasscode(v),
                        ),
                        if (settings.appPasscode)
                          _buildGlassActionTile(
                            icon: Icons.pin_outlined,
                            title: 'Change Passcode',
                            subtitle: settings.passcode.isEmpty ? 'No passcode set' : 'Passcode is set',
                            onTap: () => _showPasscodeDialog(context, settings),
                          ),

                        const SizedBox(height: 24),

                        // ── Info Card ──
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.02),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF8B5CF6),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'These settings control your visibility and how others can interact with you. Changes are saved locally and synced to your account when online.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Section Header ───
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8B5CF6).withOpacity(0.8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ─── Glassmorphism Toggle Tile ───
  Widget _buildGlassToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: value
                    ? const Color(0xFF8B5CF6).withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
              ),
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: -5,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF8B5CF6),
                  activeTrackColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                  inactiveThumbColor: Colors.grey,
                  inactiveTrackColor: Colors.white12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Glassmorphism Action Tile ───
  Widget _buildGlassActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Passcode Dialog ───
  void _showPasscodeDialog(BuildContext context, SettingsProvider settings) {
    String entered = '';
    String confirm = '';
    bool isConfirming = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          isConfirming ? Icons.check_circle_outline : Icons.lock_outline,
                          size: 32,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isConfirming ? 'Confirm Passcode' : 'Enter New Passcode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final current = isConfirming ? confirm : entered;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index < current.length
                                  ? const Color(0xFF8B5CF6)
                                  : Colors.white.withOpacity(0.2),
                              boxShadow: index < current.length
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Number pad
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 1; i <= 9; i++)
                            _buildDigitButton(i.toString(), () {
                              setDialogState(() {
                                if (isConfirming) {
                                  if (confirm.length < 6) confirm += i.toString();
                                  if (confirm.length == 6) {
                                    if (confirm == entered) {
                                      settings.setPasscode(confirm);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Passcode saved'),
                                          backgroundColor: const Color(0xFF8B5CF6),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    } else {
                                      confirm = '';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Passcodes do not match'),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  if (entered.length < 6) entered += i.toString();
                                  if (entered.length == 6) isConfirming = true;
                                }
                              });
                            }),
                          const SizedBox.shrink(),
                          _buildDigitButton('0', () {
                            setDialogState(() {
                              if (isConfirming) {
                                if (confirm.length < 6) confirm += '0';
                              } else {
                                if (entered.length < 6) entered += '0';
                                if (entered.length == 6) isConfirming = true;
                              }
                            });
                          }),
                          IconButton(
                            onPressed: () {
                              setDialogState(() {
                                if (isConfirming && confirm.isNotEmpty) {
                                  confirm = confirm.substring(0, confirm.length - 1);
                                } else if (!isConfirming && entered.isNotEmpty) {
                                  entered = entered.substring(0, entered.length - 1);
                                }
                              });
                            },
                            icon: Icon(
                              Icons.backspace_outlined,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDigitButton(String digit, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
