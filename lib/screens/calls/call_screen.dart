import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.channelName,
    this.isVideoCall = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = widget.isVideoCall
        ? await CallService.createVideoClient(widget.channelName)
        : await CallService.createVoiceClient(widget.channelName);

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        setState(() => _localUserJoined = true);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (connection, remoteUid, reason) {
        setState(() => _remoteUid = null);
      },
    ));

    await _engine!.joinChannel(
      token: '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );

    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: !_initialized
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                ),
              )
            : Stack(
                children: [
                  // Remote video (full screen)
                  _remoteUid != null
                      ? AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUid),
                            connection: RtcConnection(channelId: widget.channelName),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Waiting for remote user...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                  // Local video (small floating window)
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 120,
                      height: 160,
                      child: _localUserJoined
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                              ),
                            ),
                    ),
                  ),
                  // End call button
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
