import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';

/// Bottom control bar for the video call screen.
class CallControls extends StatelessWidget {
  final bool isMicMuted;
  final bool isCameraOff;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onNext;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onNext,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingM,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCircle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: isMicMuted ? Icons.mic_off : Icons.mic,
            isActive: !isMicMuted,
            onTap: onToggleMic,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
            isActive: !isCameraOff,
            onTap: onToggleCamera,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.cameraswitch,
            isActive: true,
            onTap: onSwitchCamera,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.skip_next,
            isActive: true,
            onTap: onNext,
            color: AppColors.primary,
          ),
          const SizedBox(width: 16),
          _ControlButton(
            icon: Icons.call_end,
            isActive: false,
            onTap: onEndCall,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? (isActive ? Colors.transparent : AppColors.error);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
