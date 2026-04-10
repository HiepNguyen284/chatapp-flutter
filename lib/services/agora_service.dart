import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  late RtcEngine _agoraRtcEngine;

  final remoteUsers = <int>[];
  final infoStrings = <String>[];
  bool _isMuted = false;
  bool _isCameraOff = false;

  // Callbacks
  VoidCallback? onUserJoined;
  VoidCallback? onUserOffline;
  VoidCallback? onLocalUserJoined;
  Function(int)? onRemoteVideoFrame;
  Function(int)? onFirstRemoteVideoFrame;
  Function(int, bool)? onUserMuteVideo;
  Function(String)? onError;
  Function(String)? onInfo;

  bool get isMuted => _isMuted;
  bool get isCameraOff => _isCameraOff;
  RtcEngine get engine => _agoraRtcEngine;

  /// Initialize Agora RTC Engine
  Future<void> initAgora({
    required String appId,
    required String channelName,
    String? token,
    int uid = 0,
  }) async {
    try {
      // Request permissions before doing anything
      if (!kIsWeb) {
        await [Permission.camera, Permission.microphone].request();
      }

      _agoraRtcEngine = createAgoraRtcEngine();

      // Initialize engine
      await _agoraRtcEngine.initialize(RtcEngineContext(appId: appId));

      // Enable video
      await _agoraRtcEngine.enableVideo();

      // Enable audio
      await _agoraRtcEngine.enableAudio();

      // Enable web SDK interoperability (native side must call this to
      // communicate with Flutter Web / Agora Web SDK users)
      if (!kIsWeb) {
        await _agoraRtcEngine.enableWebSdkInteroperability(true);
      }

      // Set video configuration
      await _agoraRtcEngine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 480),
          frameRate: 15,
          bitrate: 800,
        ),
      );

      // Register event handlers
      _registerEventHandlers();

      // Start camera preview
      await _agoraRtcEngine.startPreview();

      // Join channel with explicit publish flags
      await _agoraRtcEngine.joinChannel(
        token: token ?? '',
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      _logInfo('Initializing Agora for channel: $channelName');
    } catch (e) {
      _logError('Agora initialization error: $e');
      rethrow;
    }
  }

  /// Register event handlers for Agora events
  void _registerEventHandlers() {
    _agoraRtcEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          _logInfo(
            'Joined channel: ${connection.channelId}, UID: ${connection.localUid}',
          );
          onLocalUserJoined?.call();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _logInfo('Remote user joined: $remoteUid');
          remoteUsers.add(remoteUid);
          onUserJoined?.call();
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          _logInfo('Remote user offline: $remoteUid');
          remoteUsers.remove(remoteUid);
          onUserOffline?.call();
        },
        onError: (ErrorCodeType err, String msg) {
          _logError('Error: ${err.name} - $msg');
          onError?.call('${err.name}: $msg');
        },
        onFirstRemoteVideoFrame: (RtcConnection connection, int remoteUid,
            int width, int height, int elapsed) {
          _logInfo(
            'First remote video frame from UID: $remoteUid ($width x $height)',
          );
          onFirstRemoteVideoFrame?.call(remoteUid);
          onRemoteVideoFrame?.call(remoteUid); // Keep for compatibility if needed
        },
        onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
          _logInfo('Remote user $remoteUid muted video: $muted');
          onUserMuteVideo?.call(remoteUid, muted);
        },
      ),
    );
  }

  /// Leave the channel
  Future<void> leaveChannel() async {
    try {
      await _agoraRtcEngine.leaveChannel();
      remoteUsers.clear();
      infoStrings.clear();
      _logInfo('Left channel');
    } catch (e) {
      _logError('Error leaving channel: $e');
    }
  }

  /// Toggle audio mute
  Future<void> toggleMute() async {
    try {
      _isMuted = !_isMuted;
      await _agoraRtcEngine.muteLocalAudioStream(_isMuted);
      _logInfo('Audio ${_isMuted ? 'muted' : 'unmuted'}');
    } catch (e) {
      _logError('Error toggling mute: $e');
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    try {
      _isCameraOff = !_isCameraOff;
      await _agoraRtcEngine.muteLocalVideoStream(_isCameraOff);
      _logInfo('Video camera ${_isCameraOff ? 'off' : 'on'}');
    } catch (e) {
      _logError('Error toggling video: $e');
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    try {
      await _agoraRtcEngine.switchCamera();
      _logInfo('Camera switched');
    } catch (e) {
      _logError('Error switching camera: $e');
    }
  }

  /// Dispose the Agora engine
  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _agoraRtcEngine.release();
      remoteUsers.clear();
      infoStrings.clear();
      _logInfo('Agora engine disposed');
    } catch (e) {
      _logError('Error disposing Agora: $e');
    }
  }

  /// Log info message
  void _logInfo(String message) {
    infoStrings.add(message);
    onInfo?.call(message);
    debugPrint('[Agora Info] $message');
  }

  /// Log error message
  void _logError(String message) {
    final errorMsg = '[ERROR] $message';
    infoStrings.add(errorMsg);
    onError?.call(message);
    debugPrint('[Agora Error] $message');
  }
}
