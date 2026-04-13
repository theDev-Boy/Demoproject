import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart';
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../services/avatar_service.dart';

class AvatarWidget extends StatelessWidget {
  final UserModel user;
  final double radius;
  final bool showFrame;

  const AvatarWidget({
    super.key,
    required this.user,
    this.radius = 30,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final frame = AvatarService.getFrames().firstWhere(
      (f) => f.id == user.frameId,
      orElse: () => AvatarService.getFrames().first,
    );

    return SizedBox(
      width: radius * 2.2,
      height: radius * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // THE ACTUAL AVATAR (Image or Initial)
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
            clipBehavior: Clip.antiAlias,
            child: user.avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: Text(user.initials, style: TextStyle(fontSize: radius * 0.8, color: AppColors.primary)),
                    ),
                  )
                : Center(
                    child: Text(user.initials, style: TextStyle(fontSize: radius * 0.8, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
          ),

          // THE FRAME (If any)
          if (showFrame && frame.id != 'free_border')
            Positioned.fill(
              child: IgnorePointer(
                child: frame.isAnimated && frame.assetPath.isNotEmpty
                    ? Lottie.asset(
                        frame.assetPath,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getFrameColor(frame.id),
                            width: 3,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getFrameColor(String id) {
    switch (id) {
      case 'ice_sparkle': return Colors.cyanAccent;
      case 'golden_sparkle': return Colors.amber;
      case 'fire_border': return Colors.deepOrange;
      case 'neon_glow': return Colors.purpleAccent;
      default: return AppColors.primary;
    }
  }
}
