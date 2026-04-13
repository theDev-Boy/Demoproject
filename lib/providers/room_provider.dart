import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class RoomProvider extends ChangeNotifier {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  
  RoomModel? _activeRoom;
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  
  StreamSubscription? _roomSub;
  StreamSubscription? _chatSub;
  
  RoomModel? get activeRoom => _activeRoom;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;

  /// Join a room as a spectator or participant.
  Future<void> joinRoom(RoomModel room, UserModel currentUser) async {
    _activeRoom = room;
    notifyListeners();

    // 1. Setup Listeners for Room Changes (Seats, Likes, etc.)
    _roomSub = _rtdb.ref('rooms/${room.id}').onValue.listen((event) {
      if (event.snapshot.exists) {
        _activeRoom = RoomModel.fromJson(event.snapshot.value as Map, room.id);
        notifyListeners();
      }
    });

    // 2. Setup Signaling Listeners for multi-party audio
    _listenForSignaling(room.id, currentUser.uid);
  }

  void _listenForSignaling(String roomId, String myUid) {
    // We will use a mesh-based signaling approach
    // Listen for offers/answers/candidates from other users in the room
  }

  /// Request to take a seat (Triggered by clicking an empty seat)
  Future<void> requestSeat(int index, UserModel user) async {
    if (_activeRoom == null) return;
    
    // In a production app, this would push to a 'requests' node for Admin to approve.
    // For now, we'll implement direct assignment or host-controlled logic.
    await _rtdb.ref('rooms/${_activeRoom!.id}/seats/$index').set(user.toJson());
  }

  /// Leave the room
  Future<void> leaveRoom(String myUid) async {
    await _roomSub?.cancel();
    await _chatSub?.cancel();
    
    // Remove from seats if occupied
    if (_activeRoom != null) {
      _activeRoom!.seats.forEach((key, value) async {
        if (value['uid'] == myUid) {
          await _rtdb.ref('rooms/${_activeRoom!.id}/seats/$key').remove();
        }
      });
    }

    // Dispose WebRTC
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    
    _activeRoom = null;
    notifyListeners();
  }

  /// Increase room likes (Double-tap interaction)
  Future<void> addLike() async {
    if (_activeRoom == null) return;
    await _rtdb.ref('rooms/${_activeRoom!.id}/likes').set(ServerValue.increment(1));
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }
}
