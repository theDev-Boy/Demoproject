import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../widgets/custom_button.dart';

class OfflineWrapper extends StatefulWidget {
  final Widget child;

  const OfflineWrapper({super.key, required this.child});

  @override
  State<OfflineWrapper> createState() => _OfflineWrapperState();
}

class _OfflineWrapperState extends State<OfflineWrapper> {
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOffline = results.every((result) => result == ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = results.every((result) => result == ConnectivityResult.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_isOffline)
            Positioned.fill(
              child: Material(
                color: isDark ? const Color(0xFF121212) : Colors.white,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 100,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'You are offline',
                          style: AppTypography.displayMedium.copyWith(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 200,
                          child: CustomButton(
                            text: 'Try Again',
                            onPressed: _checkConnectivity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
