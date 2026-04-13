import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';
import '../models/room_model.dart';
import '../providers/auth_provider.dart';
import 'room_screen.dart';

class RoomDiscoveryScreen extends StatefulWidget {
  const RoomDiscoveryScreen({super.key});

  @override
  State<RoomDiscoveryScreen> createState() => _RoomDiscoveryScreenState();
}

class _RoomDiscoveryScreenState extends State<RoomDiscoveryScreen> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Rooms'),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'Explore'),
              Tab(text: 'Friends'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
              onPressed: () => _showCreateRoomSheet(context),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildGlobalRooms(),
            _buildFriendRooms(),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalRooms() {
    return StreamBuilder(
      stream: _rtdb.ref('rooms').orderByChild('isEnded').equalTo(false).onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('No active rooms found. Be the first to start one!'));
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final rooms = data.entries
            .map((e) => RoomModel.fromJson(e.value, e.key))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) => _RoomCard(room: rooms[index]),
        );
      },
    );
  }

  Widget _buildFriendRooms() {
    final currentUser = context.read<AuthProvider>().userModel;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder(
      stream: _rtdb.ref('rooms').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: Text('Nothing here yet.'));
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final rooms = data.entries
            .map((e) => RoomModel.fromJson(e.value, e.key))
            .where((r) => currentUser.friends.contains(r.hostUid))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (rooms.isEmpty) {
          return const Center(child: Text('Your friends are not in any rooms right now.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) => _RoomCard(room: rooms[index]),
        );
      },
    );
  }

  void _showCreateRoomSheet(BuildContext context) {
    final titleController = TextEditingController();
    int selectedSeats = 6;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 30, 
          left: 24, 
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start a New Room', style: AppTypography.headlineLarge),
            const SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'What are we talking about?',
                labelText: 'Room Title',
              ),
            ),
            const SizedBox(height: 20),
            Text('Number of Seats', style: AppTypography.bodySmall),
            const SizedBox(height: 10),
            StatefulBuilder(builder: (context, setModalState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [2, 4, 6].map((count) {
                  final isSelected = selectedSeats == count;
                  return InkWell(
                    onTap: () => setModalState(() => selectedSeats = count),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$count Seats',
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final user = context.read<AuthProvider>().userModel;
                if (user != null) {
                  final roomRef = _rtdb.ref('rooms').push();
                  final newRoom = RoomModel(
                    id: roomRef.key!,
                    title: titleController.text.isNotEmpty ? titleController.text : '${user.name}\'s Room',
                    hostUid: user.uid,
                    hostName: user.name,
                    hostAvatar: user.avatarUrl,
                    maxSeats: selectedSeats,
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await roomRef.set(newRoom.toJson());
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RoomScreen(room: newRoom)),
                    );
                  }
                }
              },
              child: const Text('GO LIVE NOW'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (room.isEnded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                  child: const Text('ENDED', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                   child: const Text('LIVE', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              const Icon(Icons.favorite_rounded, color: Colors.pink, size: 14),
              const SizedBox(width: 4),
              Text('${room.likes}', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 10),
          Text(room.title, style: AppTypography.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundImage: room.hostAvatar.isNotEmpty ? NetworkImage(room.hostAvatar) : null,
                backgroundColor: AppColors.primary,
                child: room.hostAvatar.isEmpty ? Text(room.hostName[0], style: const TextStyle(fontSize: 10, color: Colors.white)) : null,
              ),
              const SizedBox(width: 8),
              Text(room.hostName, style: AppTypography.bodySmall),
              const Spacer(),
              Text('${room.seats.length}/${room.maxSeats} on seats', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RoomScreen(room: room)),
                );
              },
              child: const Text('JOIN AS SPECTATOR'),
            ),
          ),
        ],
      ),
    );
  }
}
