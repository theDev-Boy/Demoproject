import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/loading_overlay.dart';

class GenderSelectionScreen extends StatefulWidget {
  const GenderSelectionScreen({super.key});

  @override
  State<GenderSelectionScreen> createState() => _GenderSelectionScreenState();
}

class _GenderSelectionScreenState extends State<GenderSelectionScreen> {
  String _selectedGender = 'Male';
  final List<String> _interestedIn = ['Women'];
  String _country = 'Unknown';
  String _countryCode = '';

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    final location = await LocationService().getCountry();
    setState(() {
      _country = location['country'] ?? 'Unknown';
      _countryCode = location['countryCode'] ?? '';
    });
  }

  void _onToggleInterest(String interest) {
    setState(() {
      if (_interestedIn.contains(interest)) {
        if (_interestedIn.length > 1) {
          _interestedIn.remove(interest);
        }
      } else {
        _interestedIn.add(interest);
      }
    });
  }

  void _onContinue() async {
    await context.read<AuthProvider>().updateGenderAndInterests(
      gender: _selectedGender,
      interestedIn: _interestedIn,
      country: _country,
      countryCode: _countryCode,
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Text('Tell us about yourself', style: AppTypography.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us connect you with the right people',
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
                  Text('Show me', style: AppTypography.headlineSmall),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildInterestChip('Men'),
                      _buildInterestChip('Women'),
                      _buildInterestChip('Everyone'),
                    ],
                  ),
                  const Spacer(),
                  CustomButton(
                    text: 'Continue',
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
        onTap: () => setState(() => _selectedGender = gender),
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

  Widget _buildInterestChip(String interest) {
    final isSelected = _interestedIn.contains(interest);
    return ChoiceChip(
      label: Text(interest),
      selected: isSelected,
      onSelected: (_) => _onToggleInterest(interest),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      labelStyle: AppTypography.button.copyWith(
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        side: BorderSide.none,
      ),
    );
  }
}
