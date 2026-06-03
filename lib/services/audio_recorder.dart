import 'dart:async';

abstract class AudioRecorderInterface {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> dispose();
}
