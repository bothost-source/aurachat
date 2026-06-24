import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallSignalingService {
  static final _supabase = Supabase.instance.client;
  static RealtimeChannel? _channel;
  static final _callStreamController = StreamController<CallSignal>.broadcast();
  static Stream<CallSignal> get onCallSignal => _callStreamController.stream;

  static void startListening(String userId) {
    _channel = _supabase.channel('call_signals:$userId');

    _channel!.onBroadcast(
      event: 'incoming_call',
      callback: (payload) {
        _callStreamController.add(CallSignal(
          type: CallSignalType.incoming,
          callId: payload['call_id'],
          callerId: payload['caller_id'],
          callerName: payload['caller_name'],
          callerAvatar: payload['caller_avatar'],
          channelName: payload['channel_name'],
          isVideoCall: payload['is_video_call'],
          timestamp: DateTime.parse(payload['timestamp']),
        ));
      },
    );

    _channel!.onBroadcast(
      event: 'call_answered',
      callback: (payload) {
        _callStreamController.add(CallSignal(
          type: CallSignalType.answered,
          callId: payload['call_id'],
          accepted: payload['accepted'],
          channelName: payload['channel_name'],
        ));
      },
    );

    _channel!.onBroadcast(
      event: 'call_ended',
      callback: (payload) {
        _callStreamController.add(CallSignal(
          type: CallSignalType.ended,
          callId: payload['call_id'],
        ));
      },
    );

    _channel!.subscribe();
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
    await _supabase.channel('call_signals:$targetUserId').sendBroadcastMessage(
      event: 'incoming_call',
      payload: {
        'call_id': callId,
        'caller_id': callerId,
        'caller_name': callerName,
        'caller_avatar': callerAvatar,
        'channel_name': channelName,
        'is_video_call': isVideoCall,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<void> answerCall({
    required String callerId,
    required String callId,
    required bool accepted,
    required String channelName,
  }) async {
    await _supabase.channel('call_signals:$callerId').sendBroadcastMessage(
      event: 'call_answered',
      payload: {
        'call_id': callId,
        'accepted': accepted,
        'channel_name': channelName,
      },
    );
  }

  static Future<void> endCall({
    required String targetUserId,
    required String callId,
  }) async {
    await _supabase.channel('call_signals:$targetUserId').sendBroadcastMessage(
      event: 'call_ended',
      payload: {
        'call_id': callId,
      },
    );
  }

  static void dispose() {
    _channel?.unsubscribe();
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
