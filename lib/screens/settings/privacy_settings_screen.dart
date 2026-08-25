import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;

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
                          onChanged: (v) {
                            settings.setPhoneNumberVisible(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.access_time_outlined,
                          title: 'Last Seen',
                          subtitle: 'Show when I was last online',
                          value: settings.lastSeenVisible,
                          onChanged: (v) {
                            settings.setLastSeenVisible(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.photo_outlined,
                          title: 'Profile Photo',
                          subtitle: 'Show my profile photo to others',
                          value: settings.profilePhotoVisible,
                          onChanged: (v) {
                            settings.setProfilePhotoVisible(v);
                            _syncToFirestore(settings);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Messaging ──
                        _buildSectionHeader('Messaging'),
                        _buildGlassToggleTile(
                          icon: Icons.forward_to_inbox_outlined,
                          title: 'Forwarded Messages',
                          subtitle: 'Allow others to forward my messages',
                          value: settings.forwardedMessages,
                          onChanged: (v) {
                            settings.setForwardedMessages(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.group_add_outlined,
                          title: 'Add to Groups',
                          subtitle: 'Allow others to add me to groups',
                          value: settings.addToGroups,
                          onChanged: (v) {
                            settings.setAddToGroups(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.call_outlined,
                          title: 'Voice & Video Calls',
                          subtitle: 'Allow others to call me',
                          value: settings.voiceVideoCallsVisible,
                          onChanged: (v) {
                            settings.setVoiceVideoCallsVisible(v);
                            _syncToFirestore(settings);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Find Me ──
                        _buildSectionHeader('Find Me'),
                        _buildGlassToggleTile(
                          icon: Icons.phone_android_outlined,
                          title: 'Find by Phone Number',
                          subtitle: 'People can find me using my phone',
                          value: settings.findByPhone,
                          onChanged: (v) {
                            settings.setFindByPhone(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.alternate_email_outlined,
                          title: 'Find by Username',
                          subtitle: 'People can find me using my username',
                          value: settings.findByUsername,
                          onChanged: (v) {
                            settings.setFindByUsername(v);
                            _syncToFirestore(settings);
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Security ──
                        _buildSectionHeader('Security'),
                        _buildGlassToggleTile(
                          icon: Icons.fingerprint,
                          title: 'Biometric Lock',
                          subtitle: 'Lock app with fingerprint/face',
                          value: settings.biometricLock,
                          onChanged: (v) {
                            settings.setBiometricLock(v);
                            _syncToFirestore(settings);
                          },
                        ),
                        _buildGlassToggleTile(
                          icon: Icons.lock_outline,
                          title: 'App Passcode',
                          subtitle: 'Lock app with a PIN',
                          value: settings.appPasscode,
                          onChanged: (v) {
                            settings.setAppPasscode(v);
                            _syncToFirestore(settings);
                          },
                        ),

                        // Auto-lock timeout picker
                        if (settings.appPasscode || settings.biometricLock)
                          _buildGlassActionTile(
                            icon: Icons.timer_outlined,
                            title: 'Auto-Lock Timeout',
                            subtitle: '${settings.autoLockTimeout} minute${settings.autoLockTimeout == 1 ? '' : 's'}',
                            onTap: () => _showTimeoutPicker(context, settings),
                          ),

                        // Change Passcode
                        if (settings.appPasscode)
                          _buildGlassActionTile(
                            icon: Icons.pin_outlined,
                            title: 'Change Passcode',
                            subtitle: settings.passcode.isEmpty ? 'No passcode set' : 'Passcode is set',
                            onTap: () => _showPasscodeDialog(context, settings),
                          ),

                        // Lock Now button
                        if (settings.appPasscode || settings.biometricLock)
                          _buildGlassActionTile(
                            icon: Icons.lock_person_outlined,
                            title: 'Lock Now',
                            subtitle: 'Manually lock the app immediately',
                            onTap: () {
                              settings.lock();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('App locked. Reopen to authenticate.'),
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
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

  Future<void> _syncToFirestore(SettingsProvider settings) async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? authProvider.mockUserId;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'privacy_settings': {
        'phone_number_visible': settings.phoneNumberVisible,
        'last_seen_visible': settings.lastSeenVisible,
        'profile_photo_visible': settings.profilePhotoVisible,
        'forwarded_messages': settings.forwardedMessages,
        'add_to_groups': settings.addToGroups,
        'voice_video_calls_visible': settings.voiceVideoCallsVisible,
        'find_by_phone': settings.findByPhone,
        'find_by_username': settings.findByUsername,
        'biometric_lock': settings.biometricLock,
        'app_passcode': settings.appPasscode,
        'auto_lock_timeout': settings.autoLockTimeout,
      },
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Auto-Lock Timeout Picker ───
  void _showTimeoutPicker(BuildContext context, SettingsProvider settings) {
    final options = [1, 5, 15, 30];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Auto-Lock Timeout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...options.map((minutes) => ListTile(
                leading: Icon(
                  Icons.timer_outlined,
                  color: settings.autoLockTimeout == minutes
                      ? const Color(0xFF8B5CF6)
                      : Colors.white54,
                ),
                title: Text(
                  '$minutes minute${minutes == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: settings.autoLockTimeout == minutes
                        ? const Color(0xFF8B5CF6)
                        : Colors.white,
                    fontWeight: settings.autoLockTimeout == minutes
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: settings.autoLockTimeout == minutes
                    ? const Icon(Icons.check_circle, color: Color(0xFF8B5CF6))
                    : null,
                onTap: () {
                  settings.setAutoLockTimeout(minutes);
                  _syncToFirestore(settings);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 16),
            ],
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

  // ─── Passcode Dialog with Old Passcode Validation ───
  void _showPasscodeDialog(BuildContext context, SettingsProvider settings) {
    // Steps: 0 = enter old, 1 = enter new, 2 = confirm new
    int step = settings.passcode.isEmpty ? 1 : 0;
    String oldEntered = '';
    String newEntered = '';
    String confirm = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String getTitle() {
            switch (step) {
              case 0: return 'Enter Current Passcode';
              case 1: return 'Enter New Passcode';
              case 2: return 'Confirm New Passcode';
              default: return '';
            }
          }

          String getSubtitle() {
            switch (step) {
              case 0: return 'Verify your identity first';
              case 1: return 'Choose a 6-digit PIN';
              case 2: return 'Enter it again to confirm';
              default: return '';
            }
          }

          String currentInput() {
            switch (step) {
              case 0: return oldEntered;
              case 1: return newEntered;
              case 2: return confirm;
              default: return '';
            }
          }

          void onDigit(String d) {
            setDialogState(() {
              switch (step) {
                case 0:
                  if (oldEntered.length < 6) oldEntered += d;
                  if (oldEntered.length == 6) {
                    if (oldEntered == settings.passcode) {
                      step = 1;
                      oldEntered = '';
                    } else {
                      oldEntered = '';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Incorrect passcode. Try again.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                  break;
                case 1:
                  if (newEntered.length < 6) newEntered += d;
                  if (newEntered.length == 6) step = 2;
                  break;
                case 2:
                  if (confirm.length < 6) confirm += d;
                  if (confirm.length == 6) {
                    if (confirm == newEntered) {
                      settings.setPasscode(confirm);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Passcode updated successfully'),
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
                          content: const Text('Passcodes do not match. Try again.'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                  break;
              }
            });
          }

          void onBackspace() {
            setDialogState(() {
              switch (step) {
                case 0:
                  if (oldEntered.isNotEmpty) oldEntered = oldEntered.substring(0, oldEntered.length - 1);
                  break;
                case 1:
                  if (newEntered.isNotEmpty) newEntered = newEntered.substring(0, newEntered.length - 1);
                  break;
                case 2:
                  if (confirm.isNotEmpty) confirm = confirm.substring(0, confirm.length - 1);
                  break;
              }
            });
          }

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
                          step == 0 ? Icons.lock_outline : Icons.pin_outlined,
                          size: 32,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        getTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getSubtitle(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final current = currentInput();
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
                            _buildDigitButton(i.toString(), () => onDigit(i.toString())),
                          const SizedBox.shrink(),
                          _buildDigitButton('0', () => onDigit('0')),
                          IconButton(
                            onPressed: onBackspace,
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
