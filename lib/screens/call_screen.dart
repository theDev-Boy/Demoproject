import 'package:flutter/material.dart';
import 'package:agora_uikit/agora_uikit.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../services/database_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/searching_animation.dart';
import '../services/call_notification_service.dart';
import '../widgets/avatar_widget.dart';
import '../config/app_typography.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
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
          if (call.state == CallState.connected && call.agoraClient != null)
            Positioned.fill(
              child: AgoraVideoViewer(
                client: call.agoraClient!,
                layoutType: Layout.floating,
                enableHostControls: false,
                showAVState: true,
              ),
            )
          else
            Positioned.fill(
              child: SearchingAnimation(isConnecting: call.state == CallState.connecting),
            ),

          if (call.state == CallState.connected || call.state == CallState.connecting)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32),
                      tooltip: 'Minimize',
                      onPressed: () {
                        if (call.state == CallState.connected) {
                          CallNotificationService().showOngoingCallNotification(call.partnerName ?? 'Partner');
                        }
                        context.pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    if (call.state == CallState.connected) ...[
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
                    ],
                    Expanded(
                      child: InkWell(
                        onTap: () => _showPartnerProfile(context, call),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              call.state == CallState.connecting
                                  ? call.connectionStatus
                                  : (call.partnerName ?? 'Partner'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              call.weakNetwork
                                  ? 'Weak network'
                                  : call.connectionStatus,
                              style: TextStyle(
                                color: call.weakNetwork
                                    ? Colors.orangeAccent
                                    : Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
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
                    ),
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
                    if (call.autoAudioFallback)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                          ),
                          child: const Text(
                            'Audio Mode',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (call.currentMatch != null && !(auth.userModel?.friends.contains(call.currentMatch!.getPartnerUid(auth.userModel!.uid)) ?? false))
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

          if (call.state == CallState.connected && call.agoraClient != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 100,
              left: 16,
              right: 16,
              child: AgoraVideoButtons(
                client: call.agoraClient!,
                autoHideButtonTime: 8,
                verticalButtonPadding: 12,
                enabledButtons: const [
                  BuiltInButtons.toggleMic,
                  BuiltInButtons.switchCamera,
                  BuiltInButtons.toggleCamera,
                  BuiltInButtons.callEnd,
                ],
              ),
            ),

          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
  void _showPartnerProfile(BuildContext context, CallProvider call) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvatarWidget(
                name: call.partnerName ?? 'P',
                radius: 50,
              ),
              const SizedBox(height: 16),
              Text(
                call.partnerName ?? 'Partner',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: 8),
              if (call.partnerCountry != null)
                Text(
                  call.partnerCountry!,
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAction(Icons.person_add_rounded, 'Add Friend', () {}),
                  _buildAction(Icons.report_rounded, 'Report', () {}),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon),
          iconSize: 28,
          padding: const EdgeInsets.all(12),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
