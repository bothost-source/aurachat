import 'package:flutter/material.dart';
import 'package:agora_uikit/agora_uikit.dart';
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
  late AgoraClient _client;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _client = widget.isVideoCall
        ? CallService.createVideoClient(widget.channelName)
        : CallService.createVoiceClient(widget.channelName);

    await _client.initialize();
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _client.engine.leaveChannel();
    _client.engine.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: _initialized
            ? Stack(
                children: [
                  // Remote video (full screen)
                  AgoraVideoViewer(
                    client: _client,
                    layoutType: Layout.floating,
                    enableHostControls: true,
                  ),
                  
                  // Local video (small floating window)
                  AgoraVideoButtons(
                    client: _client,
                    addScreenSharing: false,
                    disconnectButtonChild: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                ),
              ),
      ),
    );
  }
}
