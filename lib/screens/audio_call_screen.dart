import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar_widget.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';

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

class _AudioCallScreenState extends State<AudioCallScreen> with TickerProviderStateMixin {
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  int _callSeconds = 0;
  Timer? _callTimer;
  Timer? _ringTimer;
  StreamSubscription? _callSub;

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

    if (widget.isOutgoing) {
      _placeCall();
    } else {
      _acceptCall();
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringTimer?.cancel();
    _callSub?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _placeCall() {
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;
    final myName = context.read<AuthProvider>().userModel?.name ?? 'User';

    // Place call in Firebase
    FirebaseDatabase.instance.ref('audio_calls').child(widget.partnerUid).set({
      'callerId': myUid,
      'callerName': myName,
      'type': 'audio',
      'timestamp': ServerValue.timestamp,
    });

    // Listen for answer
    _callSub = FirebaseDatabase.instance
        .ref('audio_calls_active')
        .child('${myUid}_${widget.partnerUid}')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null) {
        _onCallConnected();
      }
    });

    // Auto-end after 1 minute if no answer
    _ringTimer = Timer(const Duration(minutes: 1), () {
      if (!_isConnected && mounted) _endCall(missed: true);
    });
  }

  void _acceptCall() {
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;
    // Mark call as accepted
    FirebaseDatabase.instance
        .ref('audio_calls_active')
        .child('${widget.partnerUid}_$myUid')
        .set({'accepted': true, 'timestamp': ServerValue.timestamp});
    _onCallConnected();
  }

  void _onCallConnected() {
    if (!mounted) return;
    setState(() => _isConnected = true);
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
    await FirebaseDatabase.instance.ref('audio_calls').child(widget.partnerUid).remove();
    await FirebaseDatabase.instance.ref('audio_calls').child(myUid).remove();
    await FirebaseDatabase.instance.ref('audio_calls_active').child('${myUid}_${widget.partnerUid}').remove();
    await FirebaseDatabase.instance.ref('audio_calls_active').child('${widget.partnerUid}_$myUid').remove();

    // Save call event in chat
    final chatService = ChatService();
    final chatId = chatService.getChatId(myUid, widget.partnerUid);
    final duration = _formatDuration(_callSeconds);
    final callMsg = MessageModel(
      id: '',
      senderId: myUid,
      text: missed ? '📞 Missed audio call' : '📞 Audio call · $duration',
      type: MessageType.callEvent,
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
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
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
                  child: Image.asset('logo1.png', width: 20, height: 20),
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
                color: _isConnected ? AppColors.success : AppColors.textSecondary,
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
                        icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
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
                        icon: _isSpeaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
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
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2),
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
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? Colors.black : Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
