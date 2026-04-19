import 'dart:async';
import 'dart:math';
import 'package:agora_uikit/agora_uikit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/agora_token_service.dart';
import '../services/call_notification_service.dart';
import '../services/chat_service.dart';
import '../services/database_service.dart';
import '../widgets/avatar_widget.dart';

class AudioCallScreen extends StatefulWidget {
  final String partnerUid;
  final String partnerName;
  final String partnerAvatar;
  final String callId;
  final String matchId;
  final String channelName;
  final bool isOutgoing;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.matchId,
    required this.channelName,
    required this.partnerUid,
    required this.partnerName,
    this.partnerAvatar = '',
    this.isOutgoing = true,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with TickerProviderStateMixin {
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _ringTimer;
  AgoraClient? _agoraClient;
  final _tokenService = AgoraTokenService();
  final _db = DatabaseService();
  StreamSubscription? _statusSub;
  String _statusText = 'Connecting...';

  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _statusText = widget.isOutgoing ? 'Calling...' : 'Connecting...';
    _listenForStatusChanges();
    _initAgoraAudio();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _statusSub?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _agoraClient?.engine.leaveChannel();
    super.dispose();
  }

  void _listenForStatusChanges() {
    _statusSub = _db.listenForMatchStatus(widget.matchId).listen((event) {
      if (!mounted || !event.snapshot.exists) return;
      final status = event.snapshot.value as String?;
      if (status == null) return;
      if (status == 'declined' ||
          status == 'ended' ||
          status == 'missed' ||
          status == 'no_answer') {
        _endCall();
      }
    });
  }

  Future<void> _initAgoraAudio() async {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser!.uid;
    final token = await _tokenService.fetchRtcToken(
      channelName: widget.channelName,
      uid: myUid,
      videoEnabled: false,
    );

    _agoraClient = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: "e7f6e9aeecf14b2ba10e3f40be9f56e7",
        channelName: widget.channelName,
        tempToken: token,
      ),
      enabledPermission: [Permission.microphone],
      agoraEventHandlers: AgoraRtcEventHandlers(
        onUserJoined: (connection, remoteUid, elapsed) async {
          if (!mounted || _isConnected) return;
          setState(() {
            _isConnected = true;
            _statusText = _formatDuration(_callSeconds);
          });
          _onCallConnected();
          await CallNotificationService().setCallConnected(widget.callId);
        },
        onUserOffline: (connection, remoteUid, reason) async {
          if (!mounted) return;
          await _endCall();
        },
      ),
    );
    await _agoraClient!.initialize();
    await _agoraClient!.engine.muteLocalVideoStream(true);

    _ringTimer = Timer(const Duration(minutes: 1), () {
      if (!_isConnected && mounted) {
        _db.rejectDirectCall(
          myUid: widget.partnerUid,
          matchId: widget.matchId,
          status: 'no_answer',
        );
        _endCall();
      }
    });
  }

  void _onCallConnected() {
    if (!mounted) return;
    _ringTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callSeconds++;
          _statusText = _formatDuration(_callSeconds);
        });
      }
    });
  }

  Future<void> _endCall({bool notifyPeer = false}) async {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _statusSub?.cancel();
    if (notifyPeer) {
      await _db.endDirectCall(widget.matchId);
    }
    await CallNotificationService().endCallkit(widget.callId);
    await _agoraClient?.engine.leaveChannel();
    _agoraClient = null;

    if (mounted) context.go('/home');
  }

  String _formatDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // App branding
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset('new_logo.png', width: 20, height: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'ZuuMeet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Pulse rings behind avatar
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated rings
                  if (!_isConnected) ...[
                    _buildPulseRing(0.0),
                    _buildPulseRing(0.33),
                    _buildPulseRing(0.66),
                  ],
                  // Avatar
                  AvatarWidget(
                    name: widget.partnerName,
                    avatarCode: widget.partnerAvatar,
                    radius: 60,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Partner name
            Text(
              widget.partnerName,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            // Status
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 16,
                color: _isConnected
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontWeight: _isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            // Sound wave animation when connected
            if (_isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildSoundWave(),
              ),

            const Spacer(flex: 2),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _isConnected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute
                        _buildControlBtn(
                          icon: _isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          active: _isMuted,
                          onTap: () async {
                            final next = !_isMuted;
                            await _agoraClient?.engine.muteLocalAudioStream(next);
                            if (mounted) setState(() => _isMuted = next);
                          },
                        ),

                        _buildCallBtn(
                          icon: Icons.call_end_rounded,
                          color: AppColors.error,
                          onTap: () => _endCall(notifyPeer: true),
                          shake: false,
                        ),

                        _buildControlBtn(
                          icon: _isSpeaker
                              ? Icons.volume_up_rounded
                              : Icons.volume_down_rounded,
                          label: 'Speaker',
                          active: _isSpeaker,
                          onTap: () async {
                            final next = !_isSpeaker;
                            await _agoraClient?.engine.setEnableSpeakerphone(next);
                            if (mounted) setState(() => _isSpeaker = next);
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCallBtn(
                          icon: Icons.close_rounded,
                          color: Colors.grey[700]!,
                          onTap: () => _endCall(notifyPeer: true),
                          shake: false,
                        ),

                        const SizedBox(width: 40),

                        _buildControlBtn(
                          icon: Icons.message_rounded,
                          label: 'Message',
                          active: true,
                          onTap: () {
                            final myUid =
                                context.read<AuthProvider>().firebaseUser?.uid;
                            if (myUid == null) return;
                            final chatId =
                                ChatService().getChatId(myUid, widget.partnerUid);
                            context.push('/chat/$chatId');
                          },
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(double delay) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final t = ((_pulseController.value + delay) % 1.0);
        return Container(
          width: 140 + (80 * t),
          height: 140 + (80 * t),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3 * (1 - t)),
              width: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundWave() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(7, (i) {
            final phase = (i * 0.15 + _waveController.value) % 1.0;
            final h = 8 + (16 * (0.5 + 0.5 * (2 * (phase - 0.5)).abs()));
            return Container(
              width: 4,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCallBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool shake = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        double offset = 0;
        if (shake && !_isConnected) {
          offset = sin(_pulseController.value * 10 * pi) * 4;
        }
        return Transform.translate(
          offset: Offset(0, offset),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
