import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_dimensions.dart';

class VideoCard extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool mirror;
  final bool isLocal;
  final double width;
  final double height;
  final double borderRadius;

  const VideoCard({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.isLocal = false,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = AppDimensions.radiusM,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(borderRadius),
        border: isLocal ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - (isLocal ? 2 : 0)),
        child: RTCVideoView(
          renderer,
          mirror: mirror,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      ),
    );
  }
}
