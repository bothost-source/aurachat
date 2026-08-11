import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' show AuraAuthProvider;
import '../../services/call_service.dart';
import '../../services/call_signaling_service.dart';
import '../../services/call_notification_service.dart';

class CallScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserAvatar;
  final bool? isVideoCall;
  final CallSignal? incomingSignal;
  final String? channelName;
  final bool showOptions;

  const CallScreen.pick({super.key})
      : targetUserId = null,
        targetUserName = null,
        targetUserAvatar = null,
        isVideoCall = null,
        incomingSignal = null,
        channelName = null,
        showOptions = false;

  const CallScreen.options({super.key})
      : targetUserId = null,
        targetUserName = null,
        targetUserAvatar = null,
        isVideoCall = null,
        incomingSignal = null,
        channelName = null,
        showOptions = true;

  const CallScreen.outgoing({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    required this.isVideoCall,
  })  : incomingSignal = null,
        channelName = null,
        showOptions = false;

  const CallScreen.incoming({
    super.key,
    required this.incomingSignal,
  })  : targetUserId = null,
        targetUserName = null,
        targetUserAvatar = null,
        isVideoCall = null,
        channelName = null,
        showOptions = false;

  const CallScreen.active({
    super.key,
    required this.channelName,
    required this.isVideoCall,
    required this.targetUserId,
    required this.targetUserName,
  })  : targetUserAvatar = null,
        incomingSignal = null,
        showOptions = false;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  CallState _callState = CallState.list;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  String? _callId;
  String? _channelName;
  Timer? _timeoutTimer;

  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _initialized = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = false;

  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.showOptions) {
      _callState = CallState.options;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showCallOptions());
    } else if (widget.incomingSignal != null) {
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

  void _showCallOptions() {
    final callCode = CallService.generateChannelName();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a103c),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('Share this code to join',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                  const SizedBox(height: 8),
                  SelectableText(callCode,
                    style: const TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildOptionTile(
              icon: Icons.contacts,
              label: 'Call from Contacts',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const CallScreen.pick()),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.call,
              label: 'Start Voice Call',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _startGroupCall(callCode, false);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.videocam,
              label: 'Start Video Call',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.pop(context);
                _startGroupCall(callCode, true);
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.dialpad,
              label: 'Join by Code',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showJoinByCodeDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = const Color(0xFF8B5CF6),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  void _startGroupCall(String code, bool isVideo) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen.active(
          channelName: code,
          isVideoCall: isVideo,
          targetUserId: 'group_call',
          targetUserName: 'Group Call',
        ),
      ),
    );
  }

  void _showJoinByCodeDialog() {
    final codeController = TextEditingController();
    bool isVideo = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1a103c),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Join Call by Code',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'ENTER CODE',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), letterSpacing: 4),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isVideo = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isVideo ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: !isVideo ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(children: [
                            Icon(Icons.call, color: !isVideo ? const Color(0xFF8B5CF6) : Colors.white54),
                            const SizedBox(height: 4),
                            Text('Voice', style: TextStyle(color: !isVideo ? const Color(0xFF8B5CF6) : Colors.white54, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isVideo = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isVideo ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isVideo ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.1)),
                          ),
                          child: Column(children: [
                            Icon(Icons.videocam, color: isVideo ? const Color(0xFF8B5CF6) : Colors.white54),
                            const SizedBox(height: 4),
                            Text('Video', style: TextStyle(color: isVideo ? const Color(0xFF8B5CF6) : Colors.white54, fontSize: 12)),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ),
              ElevatedButton(
                onPressed: () {
                  final code = codeController.text.trim();
                  if (code.isEmpty) return;
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallScreen.active(
                        channelName: code,
                        isVideoCall: isVideo,
                        targetUserId: 'unknown',
                        targetUserName: 'Call Room',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Join', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _loadChatUsers() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final chatsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      final Set<String> chatUserIds = {};
      for (final chat in chatsSnapshot.docs) {
        final participants = List<String>.from(chat.data()['participants'] ?? []);
        for (final pid in participants) {
          if (pid != currentUserId) chatUserIds.add(pid);
        }
      }

      if (chatUserIds.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final List<Map<String, dynamic>> users = [];
      final ids = chatUserIds.toList();
      for (int i = 0; i < ids.length; i += 10) {
        final batch = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
        final profiles = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        users.addAll(profiles.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'username': data['username'] ?? data['display_name'] ?? data['displayName'] ?? data['name'] ?? 'Unknown',
            'avatar_url': data['avatar_url'] ?? data['avatar_base64'],
            'bio': data['bio'] ?? '',
            'status': data['status'] ?? 'offline',
            ...data,
          };
        }));
      }

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat users: $e');
      setState(() => _loading = false);
    }
  }

  void _startCall(Map<String, dynamic> user, bool isVideo) {
    final name = user['username'] ?? user['display_name'] ?? user['name'] ?? 'Unknown';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen.outgoing(
          targetUserId: user['id'],
          targetUserName: name,
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
    final name = user['username'] ?? user['display_name'] ?? user['name'] ?? 'Unknown';
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: user['avatar_url'] != null
                  ? DecorationImage(image: NetworkImage(user['avatar_url']), fit: BoxFit.cover)
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: user['avatar_url'] == null
                ? Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.white)))
                : null,
          ),
          const SizedBox(height: 16),
          Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(user['bio'] ?? 'No bio available',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProfileActionButton(
                icon: Icons.videocam,
                color: const Color(0xFF8B5CF6),
                label: 'Video',
                onTap: () { Navigator.pop(context); _startCall(user, true); },
              ),
              const SizedBox(width: 24),
              _buildProfileActionButton(
                icon: Icons.call,
                color: Colors.green,
                label: 'Voice',
                onTap: () { Navigator.pop(context); _startCall(user, false); },
              ),
              const SizedBox(width: 24),
              _buildProfileActionButton(
                icon: Icons.message,
                color: Colors.blue,
                label: 'Message',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/chat', arguments: {
                    'userId': user['id'],
                    'username': name,
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

  Widget _buildProfileActionButton({
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
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: color)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

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
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null || widget.targetUserId == null) return;

    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final data = profile.data();

      String callerName = data?['username']
          ?? data?['display_name']
          ?? data?['displayName']
          ?? data?['name']
          ?? authProvider.userName
          ?? authProvider.displayName
          ?? 'Unknown';

      debugPrint('CALLER NAME: $callerName');
      debugPrint('CALLER DATA: $data');

      await CallNotificationService.sendCallFCM(
        targetUserId: widget.targetUserId!,
        callId: _callId!,
        callerId: currentUserId,
        callerName: callerName,
        callerAvatar: data?['avatar_url'] ?? data?['avatar_base64'],
        channelName: _channelName!,
        isVideoCall: widget.isVideoCall!,
      );
    } catch (e) {
      debugPrint('Error sending call invitation: $e');
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
    if (widget.targetUserId != null && _callId != null) {
      await CallSignalingService.endCall(
        targetUserId: widget.targetUserId!,
        callId: _callId!,
      );
    }
  }

  void _goBackToList(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CallScreen.pick()));
    }
  }

  void _startIncomingCallTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _callState == CallState.incoming) _declineCall();
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
            targetUserName: signal.callerName ?? 'Unknown',
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

    await _saveMissedCallLog(signal);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _saveMissedCallLog(CallSignal signal) async {
    try {
      final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUserId;
      if (currentUserId == null) return;

      await FirebaseFirestore.instance.collection('call_logs').add({
        'caller_id': signal.callerId,
        'receiver_id': currentUserId,
        'call_type': signal.isVideoCall == true ? 'video' : 'voice',
        'duration_seconds': 0,
        'status': 'missed',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving missed call log: $e');
    }
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    String token = '';
    try {
      final response = await http.get(
        Uri.parse('https://aurachat-backend-5utu.onrender.com/api/moderation/agora-token?channelName=${widget.channelName}'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        token = data['token'] ?? '';
      }
    } catch (e) {
      debugPrint('Token fetch error: $e');
    }

    _engine = widget.isVideoCall!
        ? await CallService.createVideoClient(widget.channelName!)
        : await CallService.createVoiceClient(widget.channelName!);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _localUserJoined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() => _remoteUid = remoteUid);
        _startDurationTimer();
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() => _remoteUid = null);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _endCall();
        });
      },
    ));

    await _engine!.joinChannel(
      token: token,
      channelId: widget.channelName!,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    setState(() => _initialized = true);
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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

  void _toggleSpeaker() {
    _speakerOn = !_speakerOn;
    CallService.setSpeakerphone(_engine!, _speakerOn);
    setState(() {});
  }

  Future<void> _saveCallLog() async {
    final authProvider = Provider.of<AuraAuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null || widget.targetUserId == null) return;

    await FirebaseFirestore.instance.collection('call_logs').add({
      'caller_id': currentUserId,
      'receiver_id': widget.targetUserId,
      'call_type': widget.isVideoCall! ? 'video' : 'voice',
      'duration_seconds': _callDurationSeconds,
      'status': _callDurationSeconds > 0 ? 'connected' : 'missed',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    await _saveCallLog();

    if (widget.targetUserId != null && _callId != null) {
      await CallSignalingService.endCall(
        targetUserId: widget.targetUserId!,
        callId: _callId!,
      );
    }

    _engine?.leaveChannel();
    _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _durationTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: switch (_callState) {
        CallState.options => _buildCallOptionsPlaceholder(),
        CallState.list => _buildCallList(),
        CallState.outgoing => _buildOutgoingCall(),
        CallState.incoming => _buildIncomingCall(),
        CallState.active => _buildActiveCall(),
      },
    );
  }

  Widget _buildCallOptionsPlaceholder() {
    return const Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6))),
    );
  }

  Widget _buildCallList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6))),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('No contacts yet', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Start a chat first to call someone', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/contacts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  child: Text('New Call',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserTile(_users[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final bool isOnline = user['status'] == 'online';
    final name = user['username'] ?? user['display_name'] ?? user['name'] ?? 'Unknown';
    return InkWell(
      onTap: () => _viewProfile(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: user['avatar_url'] != null
                        ? DecorationImage(image: NetworkImage(user['avatar_url']), fit: BoxFit.cover)
                        : null,
                    color: const Color(0xFF8B5CF6),
                  ),
                  child: user['avatar_url'] == null
                      ? Center(child: Text(name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))
                      : null,
                ),
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.grey,
                      border: Border.all(color: const Color(0xFF0A0A0F), width: 2),
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
                  Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(isOnline ? 'Online' : 'Offline',
                    style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 13)),
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

  Widget _buildOutgoingCall() {
    final name = widget.targetUserName ?? 'Unknown';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: widget.targetUserAvatar != null
                  ? DecorationImage(image: NetworkImage(widget.targetUserAvatar!), fit: BoxFit.cover)
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: widget.targetUserAvatar == null
                ? Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 48, color: Colors.white)))
                : null,
          ),
          const SizedBox(height: 24),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text(widget.isVideoCall == true ? 'Video calling...' : 'Voice calling...',
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 48),
          TweenAnimationBuilder(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) => Container(
              width: 80 + (value * 40), height: 80 + (value * 40),
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.3 * (1 - value))),
            ),
          ),
          const SizedBox(height: 48),
          GestureDetector(
            onTap: () { _cancelCall(); _goBackToList('Call cancelled'); },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.call_end, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildIncomingCall() {
    final signal = widget.incomingSignal!;
    final name = signal.callerName ?? signal.callerId ?? 'Unknown';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: signal.callerAvatar != null
                  ? DecorationImage(image: NetworkImage(signal.callerAvatar!), fit: BoxFit.cover)
                  : null,
              color: const Color(0xFF8B5CF6),
            ),
            child: signal.callerAvatar == null
                ? Center(child: Text(name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 48, color: Colors.white)))
                : null,
          ),
          const SizedBox(height: 24),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Text(signal.isVideoCall == true ? 'Incoming video call...' : 'Incoming voice call...',
            style: const TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 48),
          TweenAnimationBuilder(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) => Container(
              width: 80 + (value * 40), height: 80 + (value * 40),
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withOpacity(0.3 * (1 - value))),
            ),
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
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      child: Icon(signal.isVideoCall == true ? Icons.videocam : Icons.call,
                        color: Colors.white, size: 32),
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

  Widget _buildActiveCall() {
    final name = widget.targetUserName ?? 'Unknown';
    return SafeArea(
      child: !_initialized
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6))))
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
                        : const Center(child: Text('Waiting for remote user...',
                            style: TextStyle(color: Colors.white))))
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120, height: 120,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF8B5CF6)),
                              child: Center(child: Text(name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 48, color: Colors.white))),
                            ),
                            const SizedBox(height: 16),
                            Text(name,
                              style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(_remoteUid != null
                                ? 'Connected • ${_formatDuration(_callDurationSeconds)}'
                                : 'Connecting...',
                              style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                if (widget.isVideoCall!)
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 120, height: 160,
                      child: _localUserJoined
                          ? (_cameraOff
                              ? Container(color: Colors.black,
                                  child: const Center(child: Icon(Icons.videocam_off, color: Colors.white54)))
                              : AgoraVideoView(
                                  controller: VideoViewController(rtcEngine: _engine!, canvas: const VideoCanvas(uid: 0)),
                                ))
                          : const Center(child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)))),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_callDurationSeconds > 0)
                          Text(_formatDuration(_callDurationSeconds),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildControlButton(
                              icon: _muted ? Icons.mic_off : Icons.mic,
                              color: _muted ? Colors.red : Colors.white24,
                              onTap: _toggleMute,
                            ),
                            const SizedBox(width: 16),
                            _buildControlButton(
                              icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                              color: _speakerOn ? const Color(0xFF8B5CF6) : Colors.white24,
                              onTap: _toggleSpeaker,
                            ),
                            const SizedBox(width: 16),
                            if (widget.isVideoCall!)
                              _buildControlButton(
                                icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                                color: _cameraOff ? Colors.red : Colors.white24,
                                onTap: _toggleCamera,
                              ),
                            if (widget.isVideoCall!) const SizedBox(width: 16),
                            GestureDetector(
                              onTap: _endCall,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

enum CallState { options, list, outgoing, incoming, active }
