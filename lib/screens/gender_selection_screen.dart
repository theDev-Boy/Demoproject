import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../widgets/avatar_widget.dart';
import '../services/avatar_generator.dart';
import '../services/ad_manager.dart';
import 'package:go_router/go_router.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/custom_button.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  String _selectedGender = 'Male';
  final _ageCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // Added
  String _country = 'Unknown';
  String _countryCode = '';
  String _avatarCode = AvatarGenerator.getRandomAnime(false);

  @override
  void initState() {
    super.initState();
    _detectLocation();
    // Pre-fill name if available
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _nameCtrl.text = user.name;
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    final location = await LocationService().getCountry();
    setState(() {
      _country = location['country'] ?? 'Unknown';
      _countryCode = location['countryCode'] ?? '';
    });
  }

  void _onContinue() async {
    if (_nameCtrl.text.trim().isEmpty) {
       _showError('Please enter your name');
       return;
    }
    if (_ageCtrl.text.trim().isEmpty) {
      _showError('Please enter your age');
      return;
    }

    await context.read<AuthProvider>().updateProfile(
      name: _nameCtrl.text.trim(),
      gender: _selectedGender,
      age: _ageCtrl.text.trim(),
      country: _country,
      countryCode: _countryCode,
      avatarUrl: _avatarCode,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  
                  // AVATAR SECTION
                  Center(
                    child: Stack(
                      children: [
                        AvatarWidget(
                          name: 'User',
                          avatarCode: _avatarCode,
                          radius: 60,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              AdManager.showRewardedAd(
                                onComplete: () async {
                                  await context.push('/avatar-selection');
                                  if (!mounted) return;
                                  final updatedUser = context.read<AuthProvider>().userModel;
                                  if (updatedUser != null && updatedUser.avatarUrl.isNotEmpty) {
                                    setState(() => _avatarCode = updatedUser.avatarUrl);
                                  }
                                },
                                onFailed: (e) async {
                                  await context.push('/avatar-selection');
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Text('Tell us about yourself', style: AppTypography.displayMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us connect you with the right people',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  Text('I am', style: AppTypography.headlineSmall),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildGenderCard('Male', Icons.male),
                      const SizedBox(width: 12),
                      _buildGenderCard('Female', Icons.female),
                      const SizedBox(width: 12),
                      _buildGenderCard('Other', Icons.person_outline),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // NAME FIELD
                  Text('Your Name', style: AppTypography.headlineSmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  Text('Age', style: AppTypography.headlineSmall),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter your age',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 64),
                  CustomButton(
                    text: 'Continue',
                    height: 56,
                    onPressed: _onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isLoading) const LoadingOverlay(),
      ],
    );
  }

  Widget _buildGenderCard(String gender, IconData icon) {
    final isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
             _selectedGender = gender;
             // Update default avatar style based on gender
             _avatarCode = AvatarGenerator.getRandomAnime(gender == 'Female');
          });
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.textSecondary, size: 32),
              const SizedBox(height: 8),
              Text(
                gender,
                style: AppTypography.button.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
