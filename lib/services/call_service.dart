import 'dart:math';
import 'package:agora_uikit/agora_uikit.dart';
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

  // Create Agora client for video call
  static AgoraClient createVideoClient(String channelName) {
    if (_appId == null) {
      throw Exception('CallService not initialized. Call initialize() first.');
    }

    return AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: _appId!,
        channelName: channelName,
      ),
    );
  }

  // Create Agora client for voice call (no video)
  static AgoraClient createVoiceClient(String channelName) {
    if (_appId == null) {
      throw Exception('CallService not initialized. Call initialize() first.');
    }

    return AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: _appId!,
        channelName: channelName,
      ),
      enabledPermission: [
        Permission.camera,
        Permission.microphone,
      ],
    );
  }
}
