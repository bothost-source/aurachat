import 'dart:math';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

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

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    await engine.enableVideo();
    await engine.startPreview();
    return engine;
  }

  // Create RtcEngine for voice call (no video)
  static Future<RtcEngine> createVoiceClient(String channelName) async {
    if (_appId == null) {
      throw Exception('CallService not initialized. Call initialize() first.');
    }

    await [Permission.microphone, Permission.camera].request();

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: _appId!,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
    await engine.enableAudio();
    return engine;
  }
}
