import 'dart:async';
import 'audio_recorder.dart';

class AudioRecorderWeb implements AudioRecorderInterface {
  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> start(String path) async {}

  @override
  Future<String?> stop() async => null;

  @override
  Future<void> dispose() async {}
}

AudioRecorderInterface createAudioRecorder() => AudioRecorderWeb();
