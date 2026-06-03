import 'dart:async';
import 'audio_recorder.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderMobile implements AudioRecorderInterface {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  @override
  Future<bool> hasPermission() async {
    var status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  @override
  Future<void> start(String path) async {
    if (!_recorder.isRecording) {
      await _recorder.openRecorder();
    }
    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
  }

  @override
  Future<String?> stop() async {
    return await _recorder.stopRecorder();
  }

  @override
  Future<void> dispose() async {
    await _recorder.closeRecorder();
  }
}

AudioRecorderInterface createAudioRecorder() => AudioRecorderMobile();
