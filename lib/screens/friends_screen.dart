import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import 'package:firebase_database/firebase_database.dart';
import '../utils/constants.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final DatabaseService _db = DatabaseService();

  void _showProfileInfo(UserModel friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(friend.initials, style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(friend.name, style: AppTypography.headlineMedium),
            Text(friend.email, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoCard('Age', friend.age.isEmpty ? 'N/A' : friend.age, Icons.cake),
                _infoCard('Gender', friend.gender.isEmpty ? 'N/A' : friend.gender, Icons.person),
                _infoCard('Location', friend.country.isEmpty ? 'N/A' : friend.country, Icons.location_on),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.videocam_rounded, color: Colors.white),
                    label: const Text('Direct Call', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.pop(context);
                      _startDirectCall(friend.uid);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
          ],
        ),
      ),
    );
  }

  void _startDirectCall(String partnerUid) async {
    final myUid = context.read<AuthProvider>().firebaseUser!.uid;
    try {
      await FirebaseDatabase.instance.ref('direct_calls').child(partnerUid).set({
        'callerId': myUid,
        'callerName': context.read<AuthProvider>().userModel!.name,
        'timestamp': ServerValue.timestamp,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling... waiting for answer.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to place call.'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Widget _infoCard(String title, String val, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().firebaseUser;
    if (authUser == null) return const SizedBox.shrink();

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref(AppConstants.usersPath).child(authUser.uid).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final user = UserModel.fromJson(userData, authUser.uid);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: [
                    Tab(text: 'Friends (${user.friends.length})'),
                    Tab(text: 'Requests (${user.friendRequests.length})'),
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
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showGlobalDiscovery(user),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            label: const Text('Add Friends', style: TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }

  void _showGlobalDiscovery(UserModel currentUser) async {
    final allUsers = await _db.getAllUsers();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // Filter out me, already friends, and pending requests
        final discoveryList = allUsers.where((u) => 
          u.uid != currentUser.uid && 
          !currentUser.friends.contains(u.uid)
        ).toList();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Discover People', style: AppTypography.headlineMedium),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Connect with global users of Zuumeet', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: discoveryList.isEmpty 
                      ? const Center(child: Text('No new users to discover right now.'))
                      : ListView.separated(
                          itemCount: discoveryList.length, 
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final user = discoveryList[index];
                            final isPending = user.friendRequests.contains(currentUser.uid);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(user.initials, style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user.country.isNotEmpty ? user.country : 'Unknown Location'),
                              trailing: isPending 
                                ? const Text('Requested', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))
                                : ElevatedButton(
                                    onPressed: () async {
                                      await _db.sendFriendRequest(currentUser.uid, user.uid);
                                      setModalState(() {}); // Refresh local UI
                                    },
                                    style: ElevatedButton.styleFrom(
                                       backgroundColor: AppColors.primary,
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                       padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: const Text('Add', style: TextStyle(color: Colors.white)),
                                  ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          }
        );
      },
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
        // Stream each friend's online status instantly
        return StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref(AppConstants.usersPath).child(friendUid).onValue,
          builder: (context, snapshot) {
             if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
               return const SizedBox.shrink();
             }
             final friendData = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
             final friend = UserModel.fromJson(friendData, friendUid);

            return ListTile(
              onTap: () => _showProfileInfo(friend),
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(friend.initials, style: const TextStyle(color: Colors.white)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: friend.isOnline ? AppColors.success : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                      ),
                    ),
                  )
                ],
              ),
              title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(friend.isOnline ? 'Online' : 'Offline', 
                style: TextStyle(color: friend.isOnline ? AppColors.success : AppColors.textSecondary, fontSize: 13)
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'remove') {
                    _db.removeFriend(user.uid, friend.uid);
                  } else if (val == 'block') {
                    _db.blockUser(user.uid, friend.uid);
                    _db.removeFriend(user.uid, friend.uid);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: AppColors.error))),
                  PopupMenuItem(value: 'block', child: Text('Block User')),
                ],
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
              onTap: () => _showProfileInfo(reqUser),
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
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                    onPressed: () => _db.acceptFriendRequest(user.uid, reqUser.uid),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 28),
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
