import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static String? _appId;

  // Initialize with your Agora App ID
  static void initialize(String appId) {
    _appId = appId;
  }

  // Generate a random channel name for the call
  static String generateChannelName() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Create RtcEngine for video call
  static Future<RtcEngine> createVideoClient(String channelName) async {
    if (_appId == null) {
      throw Exception('CallService not initialized. Call initialize() first.');
    }

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await engine.enableVideo();
    await engine.startPreview();
    
    // Set video encoder configuration
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: VideoFrameRate.fps15,
        bitrate: 0,
      ),
    );

    return engine;
  }

  // Create RtcEngine for voice call (no video)
  static Future<RtcEngine> createVoiceClient(String channelName) async {
    if (_appId == null) {
      throw Exception('CallService not initialized. Call initialize() first.');
    }

    // Request microphone permission only
    await Permission.microphone.request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await engine.enableAudio();
    // Disable video for voice calls
    await engine.disableVideo();

    return engine;
  }

  // Join channel with token (for production, use token server)
  static Future<void> joinChannel({
    required RtcEngine engine,
    required String channelName,
    required String token,
    required int uid,
    required bool isVideoCall,
  }) async {
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: isVideoCall,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: isVideoCall,
      ),
    );
  }

  // Leave channel and clean up
  static Future<void> leaveChannel(RtcEngine engine) async {
    await engine.leaveChannel();
    await engine.release();
  }
}
