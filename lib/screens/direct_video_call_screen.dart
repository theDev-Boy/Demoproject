import 'dart:async';

import 'package:agora_uikit/agora_uikit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../services/agora_token_service.dart';
import '../services/call_notification_service.dart';
import '../services/chat_service.dart';
import '../services/database_service.dart';
import '../widgets/avatar_widget.dart';

class DirectVideoCallScreen extends StatefulWidget {
  const DirectVideoCallScreen({
    super.key,
    required this.callId,
    required this.matchId,
    required this.channelName,
    required this.partnerUid,
    required this.partnerName,
    this.partnerAvatar = '',
    this.isOutgoing = true,
  });

  final String callId;
  final String matchId;
  final String channelName;
  final String partnerUid;
  final String partnerName;
  final String partnerAvatar;
  final bool isOutgoing;

  @override
  State<DirectVideoCallScreen> createState() => _DirectVideoCallScreenState();
}

class _DirectVideoCallScreenState extends State<DirectVideoCallScreen> {
  final AgoraTokenService _tokenService = AgoraTokenService();
  final DatabaseService _db = DatabaseService();

  AgoraClient? _agoraClient;
  StreamSubscription? _statusSub;
  Timer? _callTimer;
  Timer? _ringTimeout;

  bool _isConnected = false;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  int _callSeconds = 0;
  String _statusText = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _statusText = widget.isOutgoing ? 'Calling...' : 'Connecting...';
    _listenForStatusChanges();
    _initAgoraVideo();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();
    _agoraClient?.engine.leaveChannel();
    super.dispose();
  }

  void _listenForStatusChanges() {
    _statusSub = _db.listenForMatchStatus(widget.matchId).listen((event) {
      if (!mounted || !event.snapshot.exists) return;
      final status = event.snapshot.value as String?;
      if (status == null) return;

      if (status == 'connected' && !_isConnected) {
        setState(() => _statusText = 'Connecting...');
        return;
      }

      if (status == 'declined' ||
          status == 'ended' ||
          status == 'missed' ||
          status == 'no_answer') {
        _leaveCall(popHome: true);
      }
    });
  }

  Future<void> _initAgoraVideo() async {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser!.uid;
    final token = await _tokenService.fetchRtcToken(
      channelName: widget.channelName,
      uid: myUid,
      videoEnabled: true,
    );

    final agoraClient = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: 'e7f6e9aeecf14b2ba10e3f40be9f56e7',
        channelName: widget.channelName,
        tempToken: token,
      ),
      enabledPermission: [Permission.camera, Permission.microphone],
      agoraEventHandlers: AgoraRtcEventHandlers(
        onUserJoined: (connection, remoteUid, elapsed) async {
          if (!mounted || _isConnected) return;
          setState(() {
            _isConnected = true;
            _statusText = _formatDuration(_callSeconds);
          });
          _startTimer();
          await CallNotificationService().setCallConnected(widget.callId);
        },
        onUserOffline: (connection, remoteUid, reason) async {
          if (!mounted) return;
          await _leaveCall(popHome: true);
        },
      ),
    );

    setState(() => _agoraClient = agoraClient);
    await agoraClient.initialize();

    if (widget.isOutgoing) {
      _ringTimeout = Timer(const Duration(seconds: 45), () async {
        if (!_isConnected && mounted) {
          await _db.rejectDirectCall(
            myUid: widget.partnerUid,
            matchId: widget.matchId,
            status: 'no_answer',
          );
          await _leaveCall(popHome: true);
        }
      });
    }
  }

  void _startTimer() {
    _callTimer?.cancel();
    _callSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _callSeconds++;
        _statusText = _formatDuration(_callSeconds);
      });
    });
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _leaveCall({required bool popHome, bool notifyPeer = false}) async {
    _callTimer?.cancel();
    _ringTimeout?.cancel();
    _statusSub?.cancel();
    if (notifyPeer) {
      await _db.endDirectCall(widget.matchId);
    }
    await CallNotificationService().endCallkit(widget.callId);
    await _agoraClient?.engine.leaveChannel();
    _agoraClient = null;
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _toggleMic() async {
    final next = !_isMicMuted;
    await _agoraClient?.engine.muteLocalAudioStream(next);
    if (mounted) setState(() => _isMicMuted = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_isCameraOff;
    await _agoraClient?.engine.muteLocalVideoStream(next);
    if (mounted) setState(() => _isCameraOff = next);
  }

  Future<void> _switchCamera() async {
    await _agoraClient?.engine.switchCamera();
  }

  void _openChat() {
    final myUid = context.read<AuthProvider>().firebaseUser?.uid;
    if (myUid == null) return;
    final chatId = ChatService().getChatId(myUid, widget.partnerUid);
    context.push('/chat/$chatId');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isConnected && _agoraClient != null)
            Positioned.fill(
              child: AgoraVideoViewer(
                client: _agoraClient!,
                layoutType: Layout.floating,
                enableHostControls: false,
                showAVState: true,
              ),
            )
          else
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF111827), Color(0xFF020617)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarWidget(
                        name: widget.partnerName,
                        avatarCode: widget.partnerAvatar,
                        radius: 64,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.partnerName,
                        style: AppTypography.headlineMedium.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusText,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.partnerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                if (_isConnected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatDuration(_callSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.75)
                      : Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CallActionButton(
                      icon: _isMicMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      onTap: () {
                        _toggleMic();
                      },
                    ),
                    const SizedBox(width: 12),
                    _CallActionButton(
                      icon: _isCameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      onTap: () {
                        _toggleCamera();
                      },
                    ),
                    const SizedBox(width: 12),
                    _CallActionButton(
                      icon: Icons.flip_camera_ios_rounded,
                      onTap: () {
                        _switchCamera();
                      },
                    ),
                    const SizedBox(width: 12),
                    _CallActionButton(
                      icon: Icons.message_rounded,
                      onTap: _openChat,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    _CallActionButton(
                      icon: Icons.call_end_rounded,
                      onTap: () {
                        _leaveCall(popHome: true, notifyPeer: true);
                      },
                      color: AppColors.error,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
