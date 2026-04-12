import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: AppConstants.splashDurationMs));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      if (auth.hasCompletedProfile) {
        context.go('/home');
      } else {
        context.go('/gender-selection');
      }
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Placeholder - Using a simple Icon since asset is not available
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Zuumeet',
              style: AppTypography.displayLarge.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with people around the world',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Powered by Firebase',
          textAlign: TextAlign.center,
          style: AppTypography.caption,
        ),
      ),
    );
  }
}
