import 'audio_recorder.dart';

export 'audio_recorder_mobile.dart'
    if (dart.library.html) 'audio_recorder_web.dart';
