import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    if (user == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Friends'),
              Tab(text: 'Requests'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFriendsList(user, isDark),
                _buildRequestsList(user, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(UserModel user, bool isDark) {
    if (user.friends.isEmpty) {
      return const Center(child: Text('No friends yet. Add friends during an active call!'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: user.friends.length,
      itemBuilder: (context, index) {
        final friendUid = user.friends[index];
        return FutureBuilder<UserModel?>(
          future: _db.getUser(friendUid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final friend = snapshot.data!;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(friend.initials, style: const TextStyle(color: Colors.white)),
              ),
              title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(friend.isOnline ? 'Online' : 'Offline', 
                style: TextStyle(color: friend.isOnline ? AppColors.success : AppColors.textSecondary)
              ),
              trailing: IconButton(
                icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
                tooltip: 'Direct Call (Coming soon)',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Direct calling requires push notifications to be configured next!')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList(UserModel user, bool isDark) {
    if (user.friendRequests.isEmpty) {
      return const Center(child: Text('No pending requests.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: user.friendRequests.length,
      itemBuilder: (context, index) {
        final reqUid = user.friendRequests[index];
        return FutureBuilder<UserModel?>(
          future: _db.getUser(reqUid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final reqUser = snapshot.data!;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(reqUser.initials, style: const TextStyle(color: Colors.white)),
              ),
              title: Text(reqUser.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Sent you a friend request'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    onPressed: () => _db.acceptFriendRequest(user.uid, reqUser.uid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: AppColors.error),
                    onPressed: () => _db.rejectFriendRequest(user.uid, reqUser.uid),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
