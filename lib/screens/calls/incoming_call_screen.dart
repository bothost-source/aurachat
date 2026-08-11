import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/call_signaling_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallSignal signal;

  const IncomingCallScreen({
    super.key,
    required this.signal,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeoutTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startRinging();
    _startTimeout();
    
    // Keep screen on during incoming call
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startRinging() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      debugPrint('Ringtone error: $e');
    }
  }

  void _startTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _declineCall();
    });
  }

  Future<void> _acceptCall() async {
    _stopRinging();
    _timeoutTimer?.cancel();

    await CallSignalingService.answerCall(
      callerId: widget.signal.callerId!,
      callId: widget.signal.callId!,
      accepted: true,
      channelName: widget.signal.channelName!,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen.active(
            channelName: widget.signal.channelName!,
            isVideoCall: widget.signal.isVideoCall!,
            targetUserId: widget.signal.callerId!,
            targetUserName: widget.signal.callerName!,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    _stopRinging();
    _timeoutTimer?.cancel();

    await CallSignalingService.answerCall(
      callerId: widget.signal.callerId!,
      callId: widget.signal.callId!,
      accepted: false,
      channelName: widget.signal.channelName!,
    );

    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.pop(context);
    }
  }

  void _stopRinging() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  @override
  void dispose() {
    _stopRinging();
    _timeoutTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            
            // Caller avatar
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: widget.signal.callerAvatar != null
                    ? DecorationImage(
                        image: NetworkImage(widget.signal.callerAvatar!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: const Color(0xFF8B5CF6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: widget.signal.callerAvatar == null
                  ? Center(
                      child: Text(
                        (widget.signal.callerName ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 56,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
            
            const SizedBox(height: 32),
            
            // Caller name
            Text(
              widget.signal.callerName ?? 'Unknown',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Call type
            Text(
              widget.signal.isVideoCall == true
                  ? 'Incoming video call...'
                  : 'Incoming voice call...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            
            const Spacer(flex: 3),
            
            // Pulsing animation
            TweenAnimationBuilder(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) => Container(
                width: 100 + (value * 50),
                height: 100 + (value * 50),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.2 * (1 - value)),
                ),
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Accept / Decline buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decline
                Column(
                  children: [
                    GestureDetector(
                      onTap: _declineCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 64),
                
                // Accept
                Column(
                  children: [
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: widget.signal.isVideoCall == true
                              ? const Color(0xFF8B5CF6)
                              : Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.signal.isVideoCall == true
                                  ? const Color(0xFF8B5CF6)
                                  : Colors.green,
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.signal.isVideoCall == true
                              ? Icons.videocam
                              : Icons.call,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
