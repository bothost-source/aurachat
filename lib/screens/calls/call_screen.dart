import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/call_service.dart';
import '../../services/call_signaling_service.dart';

// ============================================================
// CALL SCREEN — Only shows users you've chatted with
// ============================================================

class CallScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserAvatar;
  final bool? isVideoCall;
  final CallSignal? incomingSignal;
  final String? channelName;

  const CallScreen.pick({
    super.key,
  })  : targetUserId = null,
        targetUserName = null,
        targetUserAvatar = null,
        isVideoCall = null,
        incomingSignal = null,
        channelName = null;

  const CallScreen.outgoing({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    required this.isVideoCall,
  })  : incomingSignal = null,
        channelName = null;

  const CallScreen.incoming({
    super.key,
    required this.incomingSignal,
  })  : targetUserId = null,
        targetUserName = null,
        targetUserAvatar = null,
        isVideoCall = null,
        channelName = null;

  const CallScreen.active({
    super.key,
    required this.channelName,
    required this.isVideoCall,
    required this.targetUserId,
    required this.targetUserName,
  })  : targetUserAvatar = null,
        incomingSignal = null;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  // ─── State ───
  CallState _callState = CallState.list;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  // Outgoing/Incoming
  String? _callId;
  String? _channelName;
  Timer? _timeoutTimer;

  // Active call (Agora)
  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _initialized = false;
  bool _muted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.incomingSignal != null) {
      _callState = CallState.incoming;
      _startIncomingCallTimer();
    } else if (widget.targetUserId != null && widget.channelName == null) {
      _callState = CallState.outgoing;
      _startOutgoingCall();
    } else if (widget.channelName != null) {
      _callState = CallState.active;
      _initAgora();
    } else {
      _loadChatUsers();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ONLY LOAD USERS YOU'VE CHATTED WITH
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadChatUsers() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Get all messages where you are sender OR receiver
      final messages = await Supabase.instance.client
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .order('created_at', ascending: false);

      // Extract unique user IDs you've chatted with
      final Set<String> chatUserIds = {};
      for (final msg in messages) {
        final senderId = msg['sender_id'] as String;
        final receiverId = msg['receiver_id'] as String;

        if (senderId != currentUser.id) chatUserIds.add(senderId);
        if (receiverId != currentUser.id) chatUserIds.add(receiverId);
      }

      if (chatUserIds.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Fetch their profiles
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, username, avatar_url, status, bio, phone')
          .inFilter('id', chatUserIds.toList());

      setState(() {
        _users = List<Map<String, dynamic>>.from(profiles);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat users: $e');
      setState(() => _loading = false);
    }
  }

  void _startCall(Map<String, dynamic> user, bool isVideo) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen.outgoing(
          targetUserId: user['id'],
          targetUserName: user['username'] ?? 'Unknown',
          targetUserAvatar: user['avatar_url'],
          isVideoCall: isVideo,
        ),
      ),
    );
  }

  void _viewProfile(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildProfileSheet(user),
    );
  }

  Widget _buildProfileSheet(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: user['avatar_url'] != null
                  ? DecorationImage(
                      image: NetworkImage(user['avatar_url']),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: user['avatar_url'] == null
                ? Center(
                    child: Text(
                      (user['username'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user['username'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user['bio'] ?? 'No bio available',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (user['phone'] != null)
            Text(
              user['phone'],
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.videocam,
                color: const Color(0xFF8B5CF6),
                label: 'Video',
                onTap: () {
                  Navigator.pop(context);
                  _startCall(user, true);
                },
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.call,
                color: Colors.green,
                label: 'Voice',
                onTap: () {
                  Navigator.pop(context);
                  _startCall(user, false);
                },
              ),
              const SizedBox(width: 24),
              _buildActionButton(
                icon: Icons.message,
                color: Colors.blue,
                label: 'Message',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/chat', arguments: {
                    'userId': user['id'],
                    'username': user['username'],
                    'avatar': user['avatar_url'],
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OUTGOING CALL
  // ═══════════════════════════════════════════════════════════

  Future<void> _startOutgoingCall() async {
    _callId = '${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
    _channelName = 'call_$_callId';

    await _sendCallInvitation();
    _listenForAnswer();

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _callState == CallState.outgoing) {
        _cancelCall();
        _goBackToList('No answer');
      }
    });
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (i) => chars[(rand + i) % chars.length]).join();
  }

  Future<void> _sendCallInvitation() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', currentUser.id)
          .single();

      await CallSignalingService.sendCallInvitation(
        targetUserId: widget.targetUserId!,
        callId: _callId!,
        callerId: currentUser.id,
        callerName: profile['username'] ?? 'Unknown',
        callerAvatar: profile['avatar_url'],
        channelName: _channelName!,
        isVideoCall: widget.isVideoCall!,
      );
    } catch (e) {
      debugPrint('Error sending invitation: $e');
    }
  }

  void _listenForAnswer() {
    CallSignalingService.onCallSignal.listen((signal) {
      if (signal.type == CallSignalType.answered && signal.callId == _callId) {
        _timeoutTimer?.cancel();

        if (signal.accepted == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen.active(
                channelName: _channelName!,
                isVideoCall: widget.isVideoCall!,
                targetUserId: widget.targetUserId!,
                targetUserName: widget.targetUserName!,
              ),
            ),
          );
        } else if (mounted) {
          _goBackToList('Call declined');
        }
      }
    });
  }

  Future<void> _cancelCall() async {
    _timeoutTimer?.cancel();
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null && _callId != null) {
      await CallSignalingService.endCall(
        targetUserId: widget.targetUserId!,
        callId: _callId!,
      );
    }
  }

  void _goBackToList(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CallScreen.pick()),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // INCOMING CALL
  // ═══════════════════════════════════════════════════════════

  void _startIncomingCallTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _callState == CallState.incoming) {
        _declineCall();
      }
    });
  }

  Future<void> _acceptCall() async {
    _timeoutTimer?.cancel();
    final signal = widget.incomingSignal!;
    
    await CallSignalingService.answerCall(
      callerId: signal.callerId!,
      callId: signal.callId!,
      accepted: true,
      channelName: signal.channelName!,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen.active(
            channelName: signal.channelName!,
            isVideoCall: signal.isVideoCall!,
            targetUserId: signal.callerId!,
            targetUserName: signal.callerName!,
          ),
        ),
      );
    }
  }

  Future<void> _declineCall() async {
    _timeoutTimer?.cancel();
    final signal = widget.incomingSignal!;
    
    await CallSignalingService.answerCall(
      callerId: signal.callerId!,
      callId: signal.callId!,
      accepted: false,
      channelName: signal.channelName!,
    );

    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVE CALL (AGORA)
  // ═══════════════════════════════════════════════════════════

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = widget.isVideoCall!
        ? await CallService.createVideoClient(widget.channelName!)
        : await CallService.createVoiceClient(widget.channelName!);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _localUserJoined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() => _remoteUid = null);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _endCall();
        });
      },
    ));

    await _engine!.joinChannel(
      token: '',
      channelId: widget.channelName!,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    setState(() => _initialized = true);
  }

  void _toggleMute() {
    _muted = !_muted;
    _engine?.muteLocalAudioStream(_muted);
    setState(() {});
  }

  void _toggleCamera() {
    _cameraOff = !_cameraOff;
    _engine?.muteLocalVideoStream(_cameraOff);
    setState(() {});
  }

  Future<void> _endCall() async {
    await CallSignalingService.endCall(
      targetUserId: widget.targetUserId!,
      callId: widget.channelName!,
    );
    _engine?.leaveChannel();
    _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _callState == CallState.active) {
      _engine?.muteLocalVideoStream(true);
    } else if (state == AppLifecycleState.resumed && _callState == CallState.active) {
      if (!_cameraOff) _engine?.muteLocalVideoStream(false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: switch (_callState) {
        CallState.list => _buildCallList(),
        CallState.outgoing => _buildOutgoingCall(),
        CallState.incoming => _buildIncomingCall(),
        CallState.active => _buildActiveCall(),
      },
    );
  }

  // ─── Call List UI ───
  Widget _buildCallList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'No contacts yet',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a chat first to call someone',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('Find People to Chat'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'New Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                return _buildUserTile(_users[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final bool isOnline = user['status'] == 'online';

    return InkWell(
      onTap: () => _viewProfile(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: user['avatar_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(user['avatar_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: const Color(0xFF8B5CF6),
                  ),
                  child: user['avatar_url'] == null
                      ? Center(
                          child: Text(
                            (user['username'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                      border: Border.all(
                        color: const Color(0xFF0A0A0F),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.videocam, color: Color(0xFF8B5CF6)),
                  onPressed: () => _startCall(user, true),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _startCall(user, false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Outgoing Call UI ───
  Widget _buildOutgoingCall() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: widget.targetUserAvatar != null
                  ? DecorationImage(
                      image: NetworkImage(widget.targetUserAvatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: widget.targetUserAvatar == null
                ? Center(
                    child: Text(
                      (widget.targetUserName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            widget.targetUserName ?? 'Unknown',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isVideoCall == true ? 'Video calling...' : 'Voice calling...',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 48),
          TweenAnimationBuilder(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Container(
                width: 80 + (value * 40),
                height: 80 + (value * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.3 * (1 - value)),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: () {
              _cancelCall();
              _goBackToList('Call cancelled');
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  // ─── Incoming Call UI ───
  Widget _buildIncomingCall() {
    final signal = widget.incomingSignal!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: signal.callerAvatar != null
                  ? DecorationImage(
                      image: NetworkImage(signal.callerAvatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: signal.callerAvatar == null
                ? Center(
                    child: Text(
                      (signal.callerName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 24),
          Text(
            signal.callerName ?? 'Unknown',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            signal.isVideoCall == true
                ? 'Incoming video call...'
                : 'Incoming voice call...',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 48),
          TweenAnimationBuilder(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Container(
                width: 80 + (value * 40),
                height: 80 + (value * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(0.3 * (1 - value)),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  GestureDetector(
                    onTap: _declineCall,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Decline', style: TextStyle(color: Colors.white54)),
                ],
              ),
              const SizedBox(width: 48),
              Column(
                children: [
                  GestureDetector(
                    onTap: _acceptCall,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        signal.isVideoCall == true ? Icons.videocam : Icons.call,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Accept', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Active Call UI ───
  Widget _buildActiveCall() {
    return SafeArea(
      child: !_initialized
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
              ),
            )
          : Stack(
              children: [
                widget.isVideoCall!
                    ? (_remoteUid != null
                        ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _engine!,
                              canvas: VideoCanvas(uid: _remoteUid),
                              connection: RtcConnection(channelId: widget.channelName!),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Waiting for remote user...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ))
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF8B5CF6),
                              ),
                              child: Center(
                                child: Text(
                                  (widget.targetUserName ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 48, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.targetUserName ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _remoteUid != null ? 'Connected' : 'Connecting...',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                if (widget.isVideoCall!)
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 120,
                      height: 160,
                      child: _localUserJoined
                          ? (_cameraOff
                              ? Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(Icons.videocam_off, color: Colors.white54),
                                  ),
                                )
                              : AgoraVideoView(
                                  controller: VideoViewController(
                                    rtcEngine: _engine!,
                                    canvas: const VideoCanvas(uid: 0),
                                  ),
                                ))
                          : const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                              ),
                            ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlButton(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          color: _muted ? Colors.red : Colors.white24,
                          onTap: _toggleMute,
                        ),
                        const SizedBox(width: 20),
                        if (widget.isVideoCall!)
                          _buildControlButton(
                            icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                            color: _cameraOff ? Colors.red : Colors.white24,
                            onTap: _toggleCamera,
                          ),
                        if (widget.isVideoCall!) const SizedBox(width: 20),
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

enum CallState { list, outgoing, incoming, active }
