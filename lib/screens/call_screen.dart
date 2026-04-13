import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../services/database_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/searching_animation.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Offset _localVideoPosition = const Offset(16, 100);

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
    final screenW = MediaQuery.sizeOf(context).width;
    final screenH = MediaQuery.sizeOf(context).height;
    final pipW = screenW < 360 ? 100.0 : 120.0;
    final pipH = screenW < 360 ? 140.0 : 160.0;

    return Scaffold(
      backgroundColor: AppColors.callBackground,
      body: Stack(
        children: [
          // REMOTE VIDEO (full screen) or SEARCHING ANIMATION
          if (call.state == CallState.connected)
            Positioned.fill(
              child: RTCVideoView(
                call.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            const Positioned.fill(
              child: SearchingAnimation(),
            ),

          // LOCAL VIDEO — draggable PiP
          if (call.state != CallState.idle)
            Positioned(
              left: _localVideoPosition.dx.clamp(0, screenW - pipW),
              top: _localVideoPosition.dy.clamp(0, screenH - pipH - 100),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _localVideoPosition = Offset(
                      (_localVideoPosition.dx + details.delta.dx).clamp(0, screenW - pipW),
                      (_localVideoPosition.dy + details.delta.dy).clamp(0, screenH - pipH - 100),
                    );
                  });
                },
                child: Container(
                  width: pipW,
                  height: pipH,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusM - 2),
                    child: RTCVideoView(
                      call.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),

          // TOP OVERLAY — partner info (connected state only)
          if (call.state == CallState.connected)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                child: Row(
                  children: [
                    // Minimize button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 24),
                      tooltip: 'Minimize',
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      ),
                      child: Text(
                        call.callDurationFormatted,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Partner info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            call.partnerName ?? 'Partner',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (call.partnerCountry != null && call.partnerCountry!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.public, color: Colors.white60, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    call.partnerCountry!,
                                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Live dot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 8),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add Friend button
                    if (call.currentMatch != null)
                      IconButton(
                        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                        tooltip: 'Add Friend',
                        onPressed: () async {
                          final partnerUid = call.currentMatch!.user1 == auth.userModel!.uid
                              ? call.currentMatch!.user2
                              : call.currentMatch!.user1;
                          try {
                            await DatabaseService().sendFriendRequest(auth.userModel!.uid, partnerUid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Friend request sent to ${call.partnerName}!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to send request.'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    // Report button
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      onSelected: (value) async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('User reported for: $value'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
                          ),
                        );
                        await call.nextPartner(auth.userModel!);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'Inappropriate', child: Text('Report Inappropriate')),
                        PopupMenuItem(value: 'Harassment', child: Text('Report Harassment')),
                        PopupMenuItem(value: 'Spam', child: Text('Report Spam')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // BOTTOM — call controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cancel button (searching state only)
                if (call.state == CallState.searching || call.state == CallState.connecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton.icon(
                      onPressed: () async {
                        await call.stopCompletely(auth.firebaseUser!.uid);
                        if (context.mounted) context.go('/home');
                      },
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      label: const Text('Cancel Search', style: TextStyle(color: Colors.white54, fontSize: 15)),
                    ),
                  ),

                // Call controls bar
                CallControls(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
