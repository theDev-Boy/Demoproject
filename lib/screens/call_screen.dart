import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../services/trtc_service.dart';
import '../widgets/searching_animation.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _callStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeStartCall();
  }

  Future<void> _maybeStartCall() async {
    final call = context.read<CallProvider>();
    final auth = context.read<AuthProvider>();

    if (call.state == CallState.connected &&
        call.currentMatch != null &&
        !_callStarted &&
        auth.userModel != null) {
      _callStarted = true;
      final partnerId = call.currentMatch!.getPartnerUid(auth.userModel!.uid);
      // TUICallKit auto-launches its own fullscreen call UI
      await TRTCService.startVideoCall(partnerId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallProvider>();
    final auth = context.read<AuthProvider>();

    // Reset flag when call ends so next match can start
    if (call.state == CallState.idle || call.state == CallState.searching) {
      _callStarted = false;
    }

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Stack(
        children: [
          // Searching / connecting animation
          Positioned.fill(
            child: SearchingAnimation(
              isConnecting: call.state == CallState.connecting ||
                  call.state == CallState.connected,
            ),
          ),

          // Cancel button during search
          if (call.state == CallState.searching ||
              call.state == CallState.connecting)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await call.stopCompletely(auth.firebaseUser!.uid);
                    if (context.mounted) context.go('/home');
                  },
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  label: const Text(
                    'Cancel Search',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
              ),
            ),

          // Next button while connected (TRTC UI is on top)
          if (call.state == CallState.connected)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    _callStarted = false;
                    await call.nextPartner(auth.userModel!);
                  },
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
