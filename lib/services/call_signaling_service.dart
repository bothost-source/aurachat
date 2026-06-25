import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallSignalingService {
  static DatabaseReference? _userSignalRef;
  static StreamSubscription<DatabaseEvent>? _signalSubscription;
  static final _callStreamController = StreamController<CallSignal>.broadcast();
  static Stream<CallSignal> get onCallSignal => _callStreamController.stream;

  static void startListening(String userId) {
    _userSignalRef = FirebaseDatabase.instance.ref('call_signals/$userId');

    _signalSubscription = _userSignalRef!.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final signalType = data['type'] as String?;

      switch (signalType) {
        case 'incoming_call':
          _callStreamController.add(CallSignal(
            type: CallSignalType.incoming,
            callId: data['call_id'],
            callerId: data['caller_id'],
            callerName: data['caller_name'],
            callerAvatar: data['caller_avatar'],
            channelName: data['channel_name'],
            isVideoCall: data['is_video_call'],
            timestamp: DateTime.parse(data['timestamp']),
          ));
          break;
        case 'call_answered':
          _callStreamController.add(CallSignal(
            type: CallSignalType.answered,
            callId: data['call_id'],
            accepted: data['accepted'],
            channelName: data['channel_name'],
          ));
          break;
        case 'call_ended':
          _callStreamController.add(CallSignal(
            type: CallSignalType.ended,
            callId: data['call_id'],
          ));
          break;
      }

      // Delete the signal after processing so it doesn't replay
      event.snapshot.ref.remove();
    });
  }

  static Future<void> sendCallInvitation({
    required String targetUserId,
    required String callId,
    required String callerId,
    required String callerName,
    String? callerAvatar,
    required String channelName,
    required bool isVideoCall,
  }) async {
    final ref = FirebaseDatabase.instance.ref('call_signals/$targetUserId').push();
    await ref.set({
      'type': 'incoming_call',
      'call_id': callId,
      'caller_id': callerId,
      'caller_name': callerName,
      'caller_avatar': callerAvatar,
      'channel_name': channelName,
      'is_video_call': isVideoCall,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> answerCall({
    required String callerId,
    required String callId,
    required bool accepted,
    required String channelName,
  }) async {
    final ref = FirebaseDatabase.instance.ref('call_signals/$callerId').push();
    await ref.set({
      'type': 'call_answered',
      'call_id': callId,
      'accepted': accepted,
      'channel_name': channelName,
    });
  }

  static Future<void> endCall({
    required String targetUserId,
    required String callId,
  }) async {
    final ref = FirebaseDatabase.instance.ref('call_signals/$targetUserId').push();
    await ref.set({
      'type': 'call_ended',
      'call_id': callId,
    });
  }

  static void dispose() {
    _signalSubscription?.cancel();
    _callStreamController.close();
  }
}

enum CallSignalType { incoming, answered, ended }

class CallSignal {
  final CallSignalType type;
  final String? callId;
  final String? callerId;
  final String? callerName;
  final String? callerAvatar;
  final String? channelName;
  final bool? isVideoCall;
  final bool? accepted;
  final DateTime? timestamp;

  CallSignal({
    required this.type,
    this.callId,
    this.callerId,
    this.callerName,
    this.callerAvatar,
    this.channelName,
    this.isVideoCall,
    this.accepted,
    this.timestamp,
  });
}
