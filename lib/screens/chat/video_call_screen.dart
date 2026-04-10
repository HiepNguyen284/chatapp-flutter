import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/video_call_provider.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    this.isCaller = false,
  }) : super(key: key);

  final int roomId;
  final String roomName;
  final bool isCaller;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final ScrollController _infoScrollController = ScrollController();
  bool _showInfoPanel = false;
  final Stopwatch _callTimer = Stopwatch();
  Timer? _timerTick;
  String _elapsedLabel = '00:00';
  StreamSubscription<VideoCallRejectedEvent>? _rejectedSub;
  late VideoCallProvider _videoProvider;
  bool _hasRemoteUserJoined = false;
  bool _isEndingCall = false;

  void _onProviderChanged() {
    if (!mounted) return;
    
    if (_videoProvider.remoteUsers.isNotEmpty && !_hasRemoteUserJoined) {
      _hasRemoteUserJoined = true;
    }
    
    // If someone had joined but now the room is empty (only local user left)
    if (_hasRemoteUserJoined && _videoProvider.remoteUsers.isEmpty) {
      _endCallAndPop();
    }
  }

  String _formatLog(String log) {
    if (log.contains('Remote user joined:')) {
      return 'user joined: ${widget.roomName}';
    }
    if (log.contains('Remote user offline:')) {
      return 'user offline: ${widget.roomName}';
    }
    if (log.contains('Remote user') && log.contains('muted')) {
      return log.replaceAll(RegExp(r'Remote user \d+'), widget.roomName);
    }
    return log;
  }

  @override
  void initState() {
    super.initState();
    _callTimer.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final elapsed = _callTimer.elapsed;
      final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedLabel = '$m:$s');
    });

    _videoProvider = context.read<VideoCallProvider>();
    _videoProvider.addListener(_onProviderChanged);

    // Only the caller needs to hear about rejections
    if (widget.isCaller) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rejectedSub = context.read<RealtimeService>().videoCallRejectedStream.listen((event) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${event.rejectedByUsername} đã từ chối cuộc gọi của bạn'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
          _endCallAndPop(isRejected: true);
        });
      });
    }
  }

  @override
  void dispose() {
    _videoProvider.removeListener(_onProviderChanged);
    _rejectedSub?.cancel();
    _timerTick?.cancel();
    _callTimer.stop();
    _infoScrollController.dispose();
    super.dispose();
  }

  Future<void> _endCallAndPop({bool isRejected = false}) async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    final provider = context.read<VideoCallProvider>();
    final messageService = context.read<MessageService>();
    final elapsed = _callTimer.elapsed;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final durationLabel = '$m:$s';

    await provider.endCall();

    // Only the caller sends the end-call message
    if (widget.isCaller && widget.roomId != 0) {
      try {
        await messageService.sendMessage(
          roomId: widget.roomId,
          text: isRejected 
            ? '📞 Cuộc gọi đã bị từ chối' 
            : '📞 Cuộc gọi video đã kết thúc · $durationLabel',
        );
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop();
  }

  // Draggable offset for the remote (receiver) pip overlay
  Offset _pipOffset = const Offset(16, -180);

  Widget _buildAvatarPlaceholder(String name, {bool isLoading = false}) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blueGrey,
              child: const Icon(Icons.person, size: 40, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
              )
            else
              const Icon(Icons.mic_off, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalVideoView() {
    final provider = context.read<VideoCallProvider>();
    final rtcEngine = provider.agoraService.engine;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildAvatarPlaceholder("You", isLoading: provider.isCameraOff == false),
        if (!provider.isCameraOff)
          AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: rtcEngine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
      ],
    );
  }

  Widget _buildRemoteVideoView(int uid) {
    final provider = context.read<VideoCallProvider>();
    final rtcEngine = provider.agoraService.engine;
    final channelName = provider.channelName;
    final isActive = provider.isRemoteVideoActive(uid);

    final isGroup = provider.remoteUsers.length > 1;
    final nameToDisplay = (!isGroup && widget.roomName.isNotEmpty) ? widget.roomName : "User $uid";

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!isActive)
          _buildAvatarPlaceholder(nameToDisplay, isLoading: true),
        if (isActive)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: rtcEngine,
              canvas: VideoCanvas(uid: uid),
              connection: RtcConnection(channelId: channelName),
            ),
          ),
      ],
    );
  }

  /// Builds the Messenger-style video layout for 1-on-1 calls.
  /// - Remote video (receiver): fills the entire screen (when joined).
  /// - Local video (caller): small draggable PiP overlay.
  Widget _buildMessengerLayout() {
    return Consumer<VideoCallProvider>(
      builder: (context, provider, _) {
        final remoteUsers = provider.remoteUsers;

        return Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen video ──────────────────────────
            if (remoteUsers.isNotEmpty)
              _buildRemoteVideoView(remoteUsers.first)
            else
              _buildLocalVideoView(),

            // ── Local PiP overlay (only when someone joined) ───
            if (remoteUsers.isNotEmpty)
              Positioned(
                left: _pipOffset.dx < 0 ? 0 : null,
                right: _pipOffset.dx < 0 ? null : 0,
                bottom: () {
                  final raw = -_pipOffset.dy;
                  return raw < 16 ? 16.0 : raw;
                }(),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _pipOffset = Offset(
                        _pipOffset.dx + details.delta.dx,
                        _pipOffset.dy + details.delta.dy,
                      );
                    });
                  },
                  child: Container(
                    width: 120,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _buildLocalVideoView(),
                  ),
                ),
              ),

            // ── Waiting overlay when no remote user yet ───────────
            if (remoteUsers.isEmpty)
              Positioned(
                bottom: 160,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.isCaller ? 'Đang chờ người nhận...' : 'Đang kết nối...',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _videoGridCell(Widget view) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(2),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: view,
      ),
    );
  }

  Widget _gridRow(List<Widget> views) {
    return Expanded(
      child: Row(children: views.map(_videoGridCell).toList()),
    );
  }

  /// Builds a grid layout for group calls (more than 1 remote user)
  Widget _buildGridLayout() {
    return Consumer<VideoCallProvider>(
      builder: (context, provider, _) {
        final List<Widget> views = [_buildLocalVideoView()];
        for (final uid in provider.remoteUsers) {
          views.add(_buildRemoteVideoView(uid));
        }

        switch (views.length) {
          case 1:
            return Column(children: [_videoGridCell(views[0])]);
          case 2:
            return Column(children: [
              _gridRow([views[0]]),
              _gridRow([views[1]]),
            ]);
          case 3:
            return Column(children: [
              _gridRow(views.sublist(0, 2)),
              _gridRow(views.sublist(2, 3)),
            ]);
          case 4:
            return Column(children: [
              _gridRow(views.sublist(0, 2)),
              _gridRow(views.sublist(2, 4)),
            ]);
          default:
            // 5 or more participants
            return Column(children: [
              _gridRow(views.sublist(0, 2)),
              _gridRow(views.sublist(2, 4)),
              if (views.length > 4)
                _gridRow(views.sublist(4, views.length > 6 ? 6 : views.length)),
            ]);
        }
      },
    );
  }

  Widget _buildActiveLayout() {
    return Consumer<VideoCallProvider>(
      builder: (context, provider, _) {
        // Use Grid for Group Chat, otherwise Messenger Layout
        if (provider.remoteUsers.length > 1) {
          return _buildGridLayout();
        } else {
          return _buildMessengerLayout();
        }
      },
    );
  }

  Widget _infoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 100),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Call Info',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => setState(() => _showInfoPanel = false),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<VideoCallProvider>(
            builder: (context, provider, _) => SizedBox(
              height: 150,
              child: SingleChildScrollView(
                controller: _infoScrollController,
                child: Text(
                  provider.agoraService.infoStrings.isNotEmpty
                      ? provider.agoraService.infoStrings.map(_formatLog).join('\n')
                      : 'No events yet',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Consumer<VideoCallProvider>(
        builder: (context, provider, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute button
              _ControlButton(
                icon: provider.isMuted ? Icons.mic_off : Icons.mic,
                label: provider.isMuted ? 'Unmute' : 'Mute',
                active: provider.isMuted,
                onPressed: () => provider.toggleMute(),
              ),

              // Camera toggle
              _ControlButton(
                icon: provider.isCameraOff ? Icons.videocam_off : Icons.videocam,
                label: provider.isCameraOff ? 'Cam On' : 'Cam Off',
                active: provider.isCameraOff,
                onPressed: () => provider.toggleCamera(),
              ),

              // End call
              GestureDetector(
                onTap: _endCallAndPop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 6),
                    const Text('End', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),

              // Switch camera
              _ControlButton(
                icon: Icons.switch_camera,
                label: 'Flip',
                active: false,
                onPressed: () => provider.switchCamera(),
              ),

              // Info button
              _ControlButton(
                icon: Icons.info_outline,
                label: 'Info',
                active: _showInfoPanel,
                onPressed: () => setState(() => _showInfoPanel = !_showInfoPanel),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endCallAndPop();
        return false; // We navigate manually
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _endCallAndPop,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.roomName,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Consumer<VideoCallProvider>(
                    builder: (context, provider, _) => Text(
                      '${provider.remoteUsers.length + 1} người tham gia',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _elapsedLabel,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Dynamic layout: Grid for group, Messenger for 1-on-1 ──
            _buildActiveLayout(),

            // ── Info panel ───────────────────────────────────────────────
            if (_showInfoPanel)
              Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: _infoPanel(),
              ),

            // ── Toolbar ──────────────────────────────────────────────────
            _toolbar(),

            // ── Status toast ──────────────────────────────────────────────
            Consumer<VideoCallProvider>(
              builder: (context, provider, _) {
                if (provider.statusMessage.isEmpty) return const SizedBox.shrink();
                final isError = provider.statusMessage.toLowerCase().contains('error');
                return Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isError ? Colors.red.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      provider.statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? Colors.blueAccent : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.white : Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
