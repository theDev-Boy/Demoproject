import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../widgets/call_controls.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Offset _localVideoPosition = const Offset(20, 100);

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    await context.read<CallProvider>().initRenderers();
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          if (call.state == CallState.connected)
            RTCVideoView(
              call.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    'Finding someone...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),

          // Local Video (PiP)
          if (call.state != CallState.idle)
            Positioned(
              left: _localVideoPosition.dx,
              top: _localVideoPosition.dy,
              child: Draggable(
                feedback: _buildLocalVideo(call),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  setState(() {
                    _localVideoPosition = details.offset;
                  });
                },
                child: _buildLocalVideo(call),
              ),
            ),

          // Top Overlay
          if (call.state == CallState.connected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      call.callDurationFormatted,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            call.partnerName ?? 'Partner',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            call.partnerCountry ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.circle, color: Colors.green, size: 12),
                  ],
                ),
              ),
            ),

          // Bottom Bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CallControls(
                isMicMuted: call.isMicMuted,
                isCameraOff: call.isCameraOff,
                onToggleMic: call.toggleMic,
                onToggleCamera: call.toggleCamera,
                onSwitchCamera: call.switchCamera,
                onNext: () => call.nextPartner(auth.userModel!),
                onEndCall: () async {
                  await call.stopCompletely(auth.firebaseUser!.uid);
                  if (context.mounted) context.go('/home');
                },
              ),
            ),
          ),

          // Cancel Search Button
          if (call.state == CallState.searching)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton(
                  onPressed: () async {
                    await call.stopCompletely(auth.firebaseUser!.uid);
                    if (context.mounted) context.go('/home');
                  },
                  child: const Text('Cancel Search', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ),

          // Report Menu (connected state)
          if (call.state == CallState.connected)
            Positioned(
              top: 60,
              right: 20,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  // Handle report
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('User reported for: $value')),
                  );
                  await call.nextPartner(auth.userModel!);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Inappropriate', child: Text('Report Inappropriate')),
                  const PopupMenuItem(value: 'Harassment', child: Text('Report Harassment')),
                  const PopupMenuItem(value: 'Spam', child: Text('Report Spam')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocalVideo(CallProvider call) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM - 2),
        child: RTCVideoView(
          call.localRenderer,
          mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}
