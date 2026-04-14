import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/avatar_widget.dart';
import '../services/avatar_generator.dart';
import '../providers/auth_provider.dart';
import '../config/app_colors.dart';
import '../widgets/custom_button.dart';

class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _currentAvatar = '';
  bool _isGirl = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _currentAvatar = AvatarGenerator.getRandomAnime(true);
  }

  void _randomize() {
    setState(() {
      _currentAvatar = AvatarGenerator.getRandomAnime(_isGirl);
    });
  }

  void _onSave() async {
    final auth = context.read<AuthProvider>();
    await auth.updateProfile(avatarUrl: _currentAvatar);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Avatar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 32),
          
          // PREVIEW
          AvatarWidget(
            name: 'User',
            avatarCode: _currentAvatar,
            radius: 80,
          ),
          
          const SizedBox(height: 24),
          
          TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Anime Character'),
              Tab(text: 'Fun Emoji'),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildAnimeTab(),
                _buildEmojiTab(),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: CustomButton(
              text: 'Save Avatar',
              onPressed: _onSave,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeTab() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _genderChoice('Girl', true),
              const SizedBox(width: 20),
              _genderChoice('Boy', false),
            ],
          ),
          const SizedBox(height: 48),
          OutlinedButton.icon(
            onPressed: _randomize,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Randomize Character'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Keep tapping to find the perfect look!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _genderChoice(String label, bool isGirl) {
    final active = _isGirl == isGirl;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isGirl = isGirl;
          _currentAvatar = AvatarGenerator.getRandomAnime(isGirl);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmojiTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: AvatarGenerator.emojis.length,
      itemBuilder: (context, index) {
        final emoji = AvatarGenerator.emojis[index];
        final isSelected = _currentAvatar == 'emoji:$emoji';
        
        return GestureDetector(
          onTap: () => setState(() => _currentAvatar = 'emoji:$emoji'),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        );
      },
    );
  }
}
