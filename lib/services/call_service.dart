import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  static String? _appId;

  static void initialize(String appId) {
    _appId = appId;
  }

  static String generateChannelName() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static Future<RtcEngine> createVideoClient(String channelName) async {
    if (_appId == null) throw Exception('CallService not initialized');
    await [Permission.microphone, Permission.camera].request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await engine.enableAudio();
    await engine.enableVideo();
    await engine.startPreview();

    await engine.setAudioProfile(
      profile: AudioProfileType.audioProfileDefault,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );

    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 0,
      ),
    );

    return engine;
  }

  static Future<RtcEngine> createVoiceClient(String channelName) async {
    if (_appId == null) throw Exception('CallService not initialized');
    await Permission.microphone.request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await engine.enableAudio();
    await engine.disableVideo();

    await engine.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );

    return engine;
  }

  static Future<void> setSpeakerphone(RtcEngine engine, bool enabled) async {
    await engine.setEnableSpeakerphone(enabled);
  }

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

  static Future<void> leaveChannel(RtcEngine engine) async {
    await engine.leaveChannel();
    await engine.release();
  }
}
