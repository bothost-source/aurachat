import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_moderation_service.dart';

/// Screen shown when user is banned
class BannedScreen extends StatefulWidget {
  final Map<String, dynamic> banStatus;

  const BannedScreen({super.key, required this.banStatus});

  @override
  State<BannedScreen> createState() => _BannedScreenState();
}

class _BannedScreenState extends State<BannedScreen> {
  late Duration _timeRemaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final bannedUntil = widget.banStatus['banned_until'] as DateTime?;
    if (bannedUntil == null) {
      setState(() => _timeRemaining = Duration.zero);
      return;
    }
    final remaining = bannedUntil.difference(DateTime.now());
    setState(() => _timeRemaining = remaining.isNegative ? Duration.zero : remaining);
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return 'Permanent';
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    return '${minutes}m ${seconds}s';
  }

  String _getBanMessage(String? level) {
    switch (level) {
      case '24h':
        return 'Your account has been temporarily banned for 24 hours due to a violation of our community guidelines.';
      case '30d':
        return 'Your account has been banned for 30 days due to repeated violations of our community guidelines.';
      case 'permanent':
        return 'Your account has been permanently banned due to severe or repeated violations of our community guidelines.';
      default:
        return 'Your account has been temporarily banned due to a violation of our community guidelines.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPermanent = widget.banStatus['ban_level'] == 'permanent';
    final banReason = widget.banStatus['ban_reason'] ?? 'Violation of community guidelines';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.block, size: 64, color: Colors.red),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Account Banned',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  _getBanMessage(widget.banStatus['ban_level']),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Text('Reason', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        banReason.toString().toUpperCase(),
                        style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (!isPermanent) ...[
                  const SizedBox(height: 32),
                  Text('Time Remaining', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_timeRemaining),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account will be automatically unbanned when the timer reaches zero.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 48),
                if (!isPermanent)
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Please wait for the ban to expire'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _showAppealDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Appeal'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppealDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a103c),
        title: const Text('Submit Appeal', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Explain why you believe this ban was incorrect...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () async {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null) {
                await FirebaseFirestore.instance.collection('appeals').add({
                  'user_id': userId,
                  'ban_report_id': widget.banStatus['ban_report_id'],
                  'message': controller.text,
                  'status': 'pending',
                  'created_at': FieldValue.serverTimestamp(),
                });
              }
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appeal submitted successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

/// Screen shown when user is unbanned
class UnbannedScreen extends StatelessWidget {
  const UnbannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Icon(Icons.check_circle, size: 64, color: Colors.green),
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome Back!',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Your account has been unbanned. Please follow our community guidelines to avoid future bans.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue to App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// BAN GUARD - Check ban status before allowing app access
class BanGuard extends StatelessWidget {
  final Widget child;

  const BanGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return child;

    return FutureBuilder<Map<String, dynamic>?>(
      future: AIModerationService.checkBanStatus(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0F),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))),
          );
        }

        final banStatus = snapshot.data;
        if (banStatus != null && banStatus['is_banned'] == true) {
          return BannedScreen(banStatus: banStatus);
        }

        return child;
      },
    );
  }
}
