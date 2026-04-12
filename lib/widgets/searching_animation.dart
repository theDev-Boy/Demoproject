import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';

/// A beautiful pulsing animation shown while waiting to match with someone.
/// Mimics a radar/sonar scan effect with rippling circles.
class SearchingAnimation extends StatefulWidget {
  const SearchingAnimation({super.key});

  @override
  State<SearchingAnimation> createState() => _SearchingAnimationState();
}

class _SearchingAnimationState extends State<SearchingAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rotateCtrl;
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pulsing Circles
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ripple rings
              ...List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final delay = i * 0.3;
                    final t = ((_pulseCtrl.value + delay) % 1.0);
                    return Container(
                      width: 80 + (140 * t),
                      height: 80 + (140 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: (1 - t) * 0.4),
                          width: 2,
                        ),
                      ),
                    );
                  },
                );
              }),

              // Center icon with rotation
              AnimatedBuilder(
                animation: _rotateCtrl,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotateCtrl.value * 2 * pi,
                    child: child,
                  );
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // "Finding someone..." with animated dots
        AnimatedBuilder(
          animation: _dotCtrl,
          builder: (context, _) {
            final dotCount = (_dotCtrl.value * 4).floor() % 4;
            final dots = '.' * dotCount;
            return Text(
              'Finding someone$dots',
              style: AppTypography.headlineSmall.copyWith(
                color: Colors.white,
                fontSize: 20,
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        Text(
          'Please wait while we connect you\nwith someone amazing',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white60,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
