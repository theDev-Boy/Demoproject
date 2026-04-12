import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/custom_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of Zuumeet?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              context.read<AuthProvider>().signOut();
              context.go('/auth'); // redirect to auth
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    final themeProv = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card
            if (user != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary,
                      child: Text(user.initials, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Text(user.name, style: AppTypography.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      auth.firebaseUser?.email ?? 'Google Linked Account',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(user.flagEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(user.country, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            Text('App Preferences', style: AppTypography.headlineSmall),
            const SizedBox(height: 16),
            
            // Dark Mode Toggle
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
              ),
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Switch(
                value: themeProv.isDarkMode,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => themeProv.toggleTheme(val),
              ),
            ),
            const Divider(height: 32),
            
            // About
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Colors.blue),
              ),
              title: const Text('About Zuumeet', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Version 1.0.0'),
            ),
            
            const SizedBox(height: 48),
            
            // Logout Button
            CustomButton(
              text: 'Log Out',
              icon: Icons.logout,
              backgroundColor: AppColors.backgroundSecondary,
              textColor: AppColors.error,
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}
