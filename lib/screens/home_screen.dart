import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../services/permission_service.dart';
import '../widgets/custom_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _onStartChatting(BuildContext context) async {
    final permissionService = PermissionService();
    final hasPermissions = await permissionService.requestCameraAndMic();

    if (hasPermissions) {
      if (context.mounted) {
        final currentUser = context.read<AuthProvider>().userModel;
        if (currentUser != null) {
          context.read<CallProvider>().startSearching(currentUser);
          context.go('/call');
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera and Microphone permissions are required')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Zuumeet', style: AppTypography.headlineMedium.copyWith(color: AppColors.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.textSecondary),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text(user.initials, style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: AppTypography.headlineSmall),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(user.flagEmoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(user.country, style: AppTypography.caption),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              const Center(
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 160,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Ready to meet new people?',
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Tap Start to begin video chat',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 240,
                  child: CustomButton(
                    text: 'START CHATTING',
                    onPressed: () => _onStartChatting(context),
                    icon: Icons.videocam,
                    height: 64,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
