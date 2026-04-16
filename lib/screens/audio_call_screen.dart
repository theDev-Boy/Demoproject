import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart' as msg_model;
import '../services/webrtc_service.dart';

class AudioCallScreen extends StatefulWidget {
  final String partnerUid;
  final String partnerName;
  final String partnerAvatar;
  final bool isOutgoing;

  const AudioCallScreen({
    super.key,
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
  StreamSubscription? _callSub;

  late AnimationController _pulseController;
  late AnimationController _waveController;

  // WebRTC service for handling peer connections
  final _webrtc = WebRTCService();
  bool _remoteDescSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

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

    if (widget.isOutgoing) {
      _placeCall();
    } else {
      _setupSignaling();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _callSub?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _webrtc.dispose();
    super.dispose();
  }

  Future<void> _setupSignaling() async {
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;

    _webrtc.onRemoteStream = (stream) {
      if (mounted) setState(() => _isConnected = true);
      _onCallConnected();
    };

    _webrtc.onIceCandidate = (candidate) {
      FirebaseDatabase.instance
          .ref('audio_calls_ice')
          .child(widget.partnerUid)
          .child(myUid)
          .push()
          .set({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
    };

    await _webrtc.initLocalStream();
    // Disable camera for audio call
    _webrtc.toggleCamera();

    await _webrtc.initializePeerConnection();

    // Listen for ICE candidates
    FirebaseDatabase.instance
        .ref('audio_calls_ice')
        .child(myUid)
        .child(widget.partnerUid)
        .onChildAdded
        .listen((event) {
          if (event.snapshot.value != null) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            final candidate = RTCIceCandidate(
              data['candidate'] as String?,
              data['sdpMid'] as String?,
              data['sdpMLineIndex'] as int?,
            );
            if (_remoteDescSet) {
              _webrtc.addIceCandidate(candidate);
            } else {
              _pendingCandidates.add(candidate);
            }
          }
        });
  }

  void _placeCall() async {
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser!.uid;
    final myName = auth.userModel?.name ?? 'User';

    await _setupSignaling();
    // Send direct call signal to the partner's device (widget.partnerUid)
    // Ensure we are not sending the signal to our own UID which caused the glitch.
    // Send direct call signal to the partner's device (widget.partnerUid)
    // Include caller information for the incoming call UI.
    await FirebaseDatabase.instance
        .ref('direct_calls')
        .child(widget.partnerUid)
        .set({
          'callerId': myUid,
          'callerName': myName,
          'callerAvatar': auth.userModel?.avatarUrl ?? '',
          'type': 'audio',
          'timestamp': ServerValue.timestamp,
        });

    // Create offer
    final offer = await _webrtc.createOffer();
    await FirebaseDatabase.instance
        .ref('audio_calls')
        .child(widget.partnerUid)
        .set({
          'callerId': myUid,
          'sdp': offer.sdp,
          'type': offer.type,
          'timestamp': ServerValue.timestamp,
        });

    // Listen for answer
    _callSub = FirebaseDatabase.instance
        .ref('audio_calls_active')
        .child(myUid)
        .child(widget.partnerUid)
        .onValue
        .listen((event) async {
          if (event.snapshot.value != null) {
            final data = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            if (data['sdp'] != null && !_remoteDescSet) {
              final answer = RTCSessionDescription(data['sdp'], data['type']);
              await _webrtc.setRemoteDescription(answer);
              _remoteDescSet = true;
              for (var c in _pendingCandidates) {
                _webrtc.addIceCandidate(c);
              }
              _pendingCandidates.clear();
            }
          }
        });

    _ringTimer = Timer(const Duration(minutes: 1), () {
      if (!_isConnected && mounted) _endCall(missed: true);
    });
  }

  void _acceptCall() async {
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;

    await _setupSignaling();

    // Fetch offer
    final snap = await FirebaseDatabase.instance
        .ref('audio_calls')
        .child(myUid)
        .get();
    if (snap.exists) {
      final data = Map<dynamic, dynamic>.from(snap.value as Map);
      final offer = RTCSessionDescription(data['sdp'], data['type']);
      await _webrtc.setRemoteDescription(offer);
      _remoteDescSet = true;
      for (var c in _pendingCandidates) {
        _webrtc.addIceCandidate(c);
      }
      _pendingCandidates.clear();

      // Create answer
      final answer = await _webrtc.createAnswer();
      await FirebaseDatabase.instance
          .ref('audio_calls_active')
          .child(data['callerId'])
          .child(myUid)
          .set({
            'sdp': answer.sdp,
            'type': answer.type,
            'timestamp': ServerValue.timestamp,
          });
    }
  }

  void _onCallConnected() {
    if (!mounted) return;
    _ringTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callSeconds++);
    });
  }

  void _endCall({bool missed = false}) async {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _callSub?.cancel();

    final myUid = context.read<AuthProvider>().firebaseUser!.uid;

    // Clean up Firebase
    await FirebaseDatabase.instance
        .ref('audio_calls')
        .child(widget.partnerUid)
        .remove();
    await FirebaseDatabase.instance.ref('audio_calls').child(myUid).remove();
    await FirebaseDatabase.instance
        .ref('audio_calls_active')
        .child('${myUid}_${widget.partnerUid}')
        .remove();
    await FirebaseDatabase.instance
        .ref('audio_calls_active')
        .child('${widget.partnerUid}_$myUid')
        .remove();

    // Save call event in chat
    final chatService = ChatService();
    final chatId = chatService.getChatId(myUid, widget.partnerUid);
    final duration = _formatDuration(_callSeconds);
    final callMsg = msg_model.MessageModel(
      id: '',
      senderId: myUid,
      text: missed ? '📞 Missed audio call' : '📞 Audio call · $duration',
      type: msg_model.MessageType.callEvent,
      timestamp: DateTime.now(),
    );
    await chatService.sendMessage(chatId, callMsg);

    if (mounted) context.pop();
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
              _isConnected
                  ? _formatDuration(_callSeconds)
                  : (widget.isOutgoing ? 'Calling...' : 'Incoming audio call'),
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
                          onTap: () => setState(() => _isMuted = !_isMuted),
                        ),

                        // End call
                        _buildCallBtn(
                          icon: Icons.call_end_rounded,
                          color: AppColors.error,
                          onTap: () => _endCall(),
                          shake: false,
                        ),

                        // Speaker
                        _buildControlBtn(
                          icon: _isSpeaker
                              ? Icons.volume_up_rounded
                              : Icons.volume_down_rounded,
                          label: 'Speaker',
                          active: _isSpeaker,
                          onTap: () => setState(() => _isSpeaker = !_isSpeaker),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Reject
                        _buildCallBtn(
                          icon: Icons.close_rounded,
                          color: Colors.grey[700]!,
                          onTap: () => _endCall(),
                          shake: false,
                        ),

                        const SizedBox(width: 40),

                        // Accept (Shake animation)
                        _buildCallBtn(
                          icon: Icons.call_rounded,
                          color: AppColors.success,
                          onTap: () => _acceptCall(),
                          shake: true,
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
