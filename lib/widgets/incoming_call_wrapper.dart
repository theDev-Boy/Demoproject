import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../services/database_service.dart';
import '../config/app_colors.dart';
import '../config/app_typography.dart';

class IncomingCallWrapper extends StatefulWidget {
  final Widget child;
  const IncomingCallWrapper({super.key, required this.child});

  @override
  State<IncomingCallWrapper> createState() => _IncomingCallWrapperState();
}

class _IncomingCallWrapperState extends State<IncomingCallWrapper> {
  StreamSubscription? _callSub;
  Map<dynamic, dynamic>? _incomingCall;
  final _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    final auth = context.read<AuthProvider>();
    // Need to listen whenever user auth state changes, but for simplicity we rely on current user
    if (auth.firebaseUser != null) {
      _setupListener(auth.firebaseUser!.uid);
    }
    
    // Also listen to auth changes
    auth.addListener(() {
      if (mounted && auth.firebaseUser != null && _callSub == null) {
        _setupListener(auth.firebaseUser!.uid);
      } else if (mounted && auth.firebaseUser == null) {
        _callSub?.cancel();
        _callSub = null;
        setState(() => _incomingCall = null);
      }
    });
  }

  void _setupListener(String uid) {
    _callSub?.cancel();
    _callSub = FirebaseDatabase.instance
        .ref('direct_calls')
        .child(uid)
        .onValue
        .listen((event) {
      if (!mounted) return;
      if (event.snapshot.value != null) {
        setState(() {
           _incomingCall = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
           _incomingCall = null;
        });
      }
    });
  }

  void _acceptCall() async {
    if (_incomingCall == null) return;
    final callData = _incomingCall!;
    final callerId = callData['callerId'] as String;
    final callerName = callData['callerName'] as String;
    
    final auth = context.read<AuthProvider>();
    final myUid = auth.firebaseUser!.uid;

    try {
      // 1. Create a Match record officially
      await _dbService.createMatch(
         user1: callerId, 
         user2: myUid, 
         user1Name: callerName, 
         user2Name: auth.userModel?.name ?? 'User'
      );
      
      // 2. Clear the incoming call node to dismiss the screen for both
      await FirebaseDatabase.instance.ref('direct_calls').child(myUid).remove();

      // 3. Initiate the call on their end by setting matched state
      // Actually, createMatch does this by setting both users to status: 'matched' with MatchID.
      // 4. Send them to call screen!
      if (mounted) context.go('/call');

    } catch (e) {
       // Hide error
       await FirebaseDatabase.instance.ref('direct_calls').child(myUid).remove();
    }
  }

  void _rejectCall() async {
    final auth = context.read<AuthProvider>();
    if (auth.firebaseUser != null) {
      await FirebaseDatabase.instance.ref('direct_calls').child(auth.firebaseUser!.uid).remove();
    }
    setState(() => _incomingCall = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Full Screen Call Overlay overlay
        if (_incomingCall != null)
           Positioned.fill(
             child: Material(
               color: Colors.black.withValues(alpha: 0.95),
               child: SafeArea(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     Column(
                       children: [
                         Image.asset('logo.png', width: 80, height: 80),
                         const SizedBox(height: 24),
                         Text('INCOMING CALL', style: AppTypography.headlineMedium.copyWith(color: Colors.white70, letterSpacing: 2)),
                         const SizedBox(height: 16),
                         Text(
                           _incomingCall!['callerName'] ?? 'Someone', 
                           style: AppTypography.displayMedium.copyWith(color: Colors.white, fontSize: 36)
                         ),
                       ],
                     ),
                     
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                       children: [
                         // Reject Button
                         Column(
                           children: [
                             GestureDetector(
                               onTap: _rejectCall,
                               child: Container(
                                 width: 70, height: 70,
                                 decoration: const BoxDecoration(
                                   color: AppColors.error,
                                   shape: BoxShape.circle,
                                 ),
                                 child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                               ),
                             ),
                             const SizedBox(height: 12),
                             const Text('Decline', style: TextStyle(color: Colors.white70, fontSize: 16)),
                           ],
                         ),
                         
                         // Accept Button
                         Column(
                           children: [
                             GestureDetector(
                               onTap: _acceptCall,
                               child: Container(
                                 width: 70, height: 70,
                                 decoration: const BoxDecoration(
                                   color: AppColors.success,
                                   shape: BoxShape.circle,
                                   boxShadow: [
                                      BoxShadow(color: AppColors.success, blurRadius: 20, spreadRadius: 5)
                                   ]
                                 ),
                                 child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 36),
                               ),
                             ),
                             const SizedBox(height: 12),
                             const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ],
                     )
                   ],
                 ),
               ),
             ),
           )
      ],
    );
  }
}
