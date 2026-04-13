import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_colors.dart';
import 'config/app_dimensions.dart';
import 'config/app_typography.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'widgets/offline_wrapper.dart';
import 'widgets/incoming_call_wrapper.dart';

class ZuumeetApp extends StatelessWidget {
  const ZuumeetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final router = AppRouter.router(authProvider);
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'Zuumeet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          titleTextStyle: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.backgroundSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          titleTextStyle: AppTypography.headlineMedium.copyWith(
            color: Colors.white,
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      themeMode: themeProvider.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return OfflineWrapper(child: IncomingCallWrapper(child: child!));
      },
    );
  }
}
