import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/trtc_service.dart';

class AudioCallScreen extends StatefulWidget {
  final String callId;
  final String matchId;
  final String channelName;
  final String partnerUid;
  final String partnerName;
  final String partnerAvatar;
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

class _AudioCallScreenState extends State<AudioCallScreen> {
  @override
  void initState() {
    super.initState();
    // TUICallKit auto-launches its own fullscreen call UI on top
    if (widget.isOutgoing) {
      TRTCService.startAudioCall(widget.partnerUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    // TRTC handles the call UI natively — this screen just acts as a launcher
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(
              widget.isOutgoing
                  ? 'Calling ${widget.partnerName}...'
                  : 'Incoming call from ${widget.partnerName}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () {
                if (context.mounted) context.go('/home');
              },
              icon: const Icon(Icons.call_end, color: Colors.red),
              label: const Text('Back to Home', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
