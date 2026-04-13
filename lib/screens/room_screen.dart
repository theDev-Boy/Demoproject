import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../services/ad_manager.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/floating_likes_widget.dart';

class RoomScreen extends StatefulWidget {
  final RoomModel room;
  const RoomScreen({super.key, required this.room});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final StreamController<void> _likeController = StreamController<void>.broadcast();
  final TextEditingController _chatController = TextEditingController();
  
  bool _isMuted = false;
  String? _activeGiftAnimation; // URL or Lottie asset

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null) {
        context.read<RoomProvider>().joinRoom(widget.room, user);
      }
    });
  }

  @override
  void dispose() {
    _likeController.close();
    _chatController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    _likeController.add(null);
    context.read<RoomProvider>().addLike();
  }

  void _sendGift(String lottieUrl) async {
    // Ad-lock for premium gifts
    await AdManager.showInterstitial(
      onComplete: () {
        setState(() => _activeGiftAnimation = lottieUrl);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _activeGiftAnimation = null);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().activeRoom ?? widget.room;
    final currentUser = context.watch<AuthProvider>().userModel;
    final isHost = currentUser?.uid == room.hostUid;

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND THEME
          _buildBackground(room.backgroundTheme),

          // 2. MAIN INTERFACE
          SafeArea(
            child: GestureDetector(
              onDoubleTap: _onDoubleTap,
              child: Column(
                children: [
                  _buildHeader(room),
                  const SizedBox(height: 20),
                  _buildSeatingArea(room, isHost, currentUser!),
                  const Spacer(),
                  _buildChatArea(room, currentUser),
                ],
              ),
            ),
          ),

          // 3. ANIMATION OVERLAYS
          FloatingLikesWidget(triggerStream: _likeController.stream),
          
          if (_activeGiftAnimation != null)
            Center(
              child: Lottie.network(
                _activeGiftAnimation!,
                width: 300,
                repeat: false,
                onLoaded: (comp) {},
              ),
            ),

          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () {
                if (currentUser != null) {
                  context.read<RoomProvider>().leaveRoom(currentUser.uid);
                }
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(
            theme == 'glass' 
                ? 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1000'
                : 'https://images.unsplash.com/photo-1475274047050-1d0c0975c63e?q=80&w=1000'
          ),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
    );
  }

  Widget _buildHeader(RoomModel room) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.title, style: AppTypography.headlineMedium.copyWith(color: Colors.white)),
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 16),
                    const SizedBox(width: 4),
                    Text('${room.likes} Likes', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatingArea(RoomModel room, bool isHost, UserModel currentUser) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 30,
        runSpacing: 20,
        children: List.generate(room.maxSeats, (index) {
          final occupantJson = room.seats[index.toString()];
          UserModel? occupant;
          if (occupantJson != null) {
            occupant = UserModel.fromJson(occupantJson, occupantJson['uid'] ?? '');
          }

          return Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (occupant == null) {
                    context.read<RoomProvider>().requestSeat(index, currentUser);
                  } else {
                    _showUserProfile(occupant);
                  }
                },
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  child: occupant != null 
                    ? AvatarWidget(user: occupant, radius: 35)
                    : const Icon(Icons.add_rounded, color: Colors.white54, size: 30),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                occupant?.name ?? 'Seat $index',
                style: TextStyle(color: occupant != null ? Colors.white : Colors.white38, fontSize: 11),
              ),
              if (occupant != null && occupant.uid == currentUser.uid)
                GestureDetector(
                   onTap: () => setState(() => _isMuted = !_isMuted),
                   child: Icon(
                    _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: _isMuted ? Colors.red : AppColors.success,
                    size: 16,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildChatArea(RoomModel room, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // GIFTS BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _GiftButton(label: 'Wow', icon: '😮', onTap: () => _sendGift('https://assets10.lottiefiles.com/packages/lf20_stL83L.json')),
              _GiftButton(label: 'Lion', icon: '🦁', onTap: () => _sendGift('https://assets3.lottiefiles.com/packages/lf20_ZpZfH7.json')),
              _GiftButton(label: 'Plane', icon: '✈️', onTap: () => _sendGift('https://assets2.lottiefiles.com/packages/lf20_T6vG3t.json')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () {
                    if (_chatController.text.isNotEmpty) {
                      // Send chat logic
                      _chatController.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserProfile(UserModel user) {
     showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(user: user, radius: 50),
            const SizedBox(height: 16),
            Text(user.name, style: AppTypography.headlineLarge),
            Text('${user.flagEmoji} ${user.country}', style: AppTypography.bodySmall),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Add Friend'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftButton extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;
  const _GiftButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
        ],
      ),
    );
  }
}
