import 'dart:async';
import 'package:agora_uikit/agora_uikit.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../services/agora_token_service.dart';
import '../services/call_notification_service.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

/// States of a video call.
enum CallState { idle, searching, connecting, connected, ended, error }

/// Manages the entire video call lifecycle.
class CallProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final AgoraTokenService _tokenService = AgoraTokenService();

  CallState _state = CallState.idle;
  MatchModel? _currentMatch;
  String? _partnerName;
  String? _partnerCountry;
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  String? _error;

  AgoraClient? _agoraClient;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  bool _videoEnabled = true;

  StreamSubscription? _matchStatusSub;
  StreamSubscription? _searchSub;
  bool _isMinimized = false;

  bool get isMinimized => _isMinimized;
  void toggleMinimize() {
    _isMinimized = !_isMinimized;
    notifyListeners();
  }

  // Getters
  CallState get state => _state;
  MatchModel? get currentMatch => _currentMatch;
  String? get partnerName => _partnerName;
  String? get partnerCountry => _partnerCountry;
  int get callDurationSeconds => _callDurationSeconds;
  String? get error => _error;
  bool get isMicMuted => _isMicMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isVideoCall => _videoEnabled;
  AgoraClient? get agoraClient => _agoraClient;

  String get callDurationFormatted {
    final m = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> initRenderers() async {}

  Future<void> startSearching(UserModel currentUser, {bool videoEnabled = true}) async {
    if (_state != CallState.idle && _state != CallState.ended) return;
    _videoEnabled = videoEnabled;

    _state = CallState.searching;
    _error = null;
    _callDurationSeconds = 0;
    notifyListeners();

    try {
      // 1. Join search queue
      await _db.joinSearchQueue(currentUser);

      // 2. LISTEN FOR OTHER SEARCHING USERS
      _searchSub = FirebaseDatabase.instance
          .ref(AppConstants.activeUsersPath)
          .onValue
          .listen((event) async {
            if (_state != CallState.searching || !event.snapshot.exists) return;

            final data = event.snapshot.value as Map<dynamic, dynamic>;
            for (final entry in data.entries) {
              final partnerUid = entry.key as String;
              if (partnerUid == currentUser.uid) continue;

              final partnerData = entry.value as Map<dynamic, dynamic>;
              final partnerStatus = partnerData['status'] as String? ?? '';

              // ATOMIC CONFLICT RESOLUTION:
              // If both users see each other, the one with the smallest UID string becomes the initiator.
              if (partnerStatus == 'searching') {
                final isInitiator = currentUser.uid.compareTo(partnerUid) < 0;

                if (isInitiator) {
                  // I am the initiator: Create and push match ID
                  final matchId = await _db.createMatch(
                    user1: currentUser.uid,
                    user2: partnerUid,
                    user1Name: currentUser.name,
                    user2Name: partnerData['name'] as String? ?? 'Anonymous',
                  );

                  _partnerName = partnerData['name'] as String? ?? 'Anonymous';
                  _partnerCountry = partnerData['country'] as String? ?? '';
                  _currentMatch = await _db.getMatch(matchId);

                  await _startCallAsInitiatorAgora(
                    matchId,
                    currentUser.uid,
                    partnerUid,
                  );
                  break;
                }
              }
            }
          });

      // 3. LISTEN FOR BEING MATCHED BY SOMEONE ELSE
      _db.listenForMatch(currentUser.uid).listen((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'matched' && (_state == CallState.searching || _state == CallState.ended)) {
          final matchId = data['matchId'] as String?;
          if (matchId != null) {
            _onMatchedByPartner(matchId, currentUser);
          }
        }
      });
    } catch (e) {
      _error = 'Connecting failed. Please check camera permission.';
      _state = CallState.idle;
      notifyListeners();
    }
  }

  /// Called when another user matched us.
  Future<void> _onMatchedByPartner(
    String matchId,
    UserModel currentUser,
  ) async {
    // Avoid double matching
    if (_state != CallState.searching && _state != CallState.ended) return;

    try {
      _currentMatch = await _db.getMatch(matchId);
      if (_currentMatch == null) return;

      _partnerName =
          _currentMatch!.getPartnerName(currentUser.uid) ?? 'Partner';

      // Stop the main search listener once matched
      _searchSub?.cancel();

      await _startCallAsReceiverAgora(
        matchId,
        currentUser.uid,
        _currentMatch!.getPartnerUid(currentUser.uid),
      );
    } catch (e) {
      _error = 'Failed to accept matched call.';
      _state = CallState.error;
      notifyListeners();
    }
  }

  Future<void> _startCallAsInitiatorAgora(
    String matchId,
    String myUid,
    String partnerUid,
  ) async {
    _state = CallState.connecting;
    notifyListeners();

    try {
      await _joinAgora(matchId, myUid, videoEnabled: true);

      _matchStatusSub = _db.listenForMatchStatus(matchId).listen((event) {
        if (!event.snapshot.exists) return;
        final status = event.snapshot.value as String?;
        if ((status == 'ended' || status == 'declined' || status == 'busy') &&
            _state == CallState.connected) {
          _onPartnerEndedCall();
        }
      });
    } catch (e) {
      _error = 'Connection failed. Please try again.';
      _state = CallState.error;
      notifyListeners();
    }
  }

  Future<void> _startCallAsReceiverAgora(
    String matchId,
    String myUid,
    String partnerUid,
  ) async {
    _state = CallState.connecting;
    notifyListeners();

    try {
      await _joinAgora(matchId, myUid, videoEnabled: _videoEnabled);

      _matchStatusSub = _db.listenForMatchStatus(matchId).listen((event) {
        if (!event.snapshot.exists) return;
        final status = event.snapshot.value as String?;
        if ((status == 'ended' || status == 'declined' || status == 'busy') &&
            _state == CallState.connected) {
          _onPartnerEndedCall();
        }
      });
    } catch (e) {
      _error = 'Connection failed. Please try again.';
      _state = CallState.error;
      notifyListeners();
    }
  }

  Future<void> _joinAgora(
    String channelName,
    String uid, {
    required bool videoEnabled,
  }) async {
    final token = await _tokenService.fetchRtcToken(
      channelName: channelName,
      uid: uid,
      videoEnabled: videoEnabled,
    );

    _agoraClient = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: "e7f6e9aeecf14b2ba10e3f40be9f56e7",
        channelName: channelName,
        tempToken: token,
      ),
      enabledPermission: [Permission.camera, Permission.microphone],
    );
    await _agoraClient!.initialize();
    _state = CallState.connected;
    _startCallTimer();
    notifyListeners();
  }

  void _onPartnerEndedCall() async {
    _stopCallTimer();
    _cancelSubscriptions();
    
    // Dismiss notification
    CallNotificationService().dismissCallNotification();
    
    await _agoraClient?.engine.leaveChannel();
    _agoraClient = null;

    _currentMatch = null;
    _partnerName = null;
    _partnerCountry = null;
    _callDurationSeconds = 0;
    
    _state = CallState.ended;
    notifyListeners();
    
    // Auto-return to idle after 2 seconds so user can search again
    Timer(const Duration(seconds: 2), () {
      if (_state == CallState.ended) {
        _state = CallState.idle;
        notifyListeners();
      }
    });
  }

  // ---------------------------------------------------------------------------
  // CALL CONTROLS
  // ---------------------------------------------------------------------------

  void toggleMic() {
    _isMicMuted = !_isMicMuted;
    _agoraClient?.engine.muteLocalAudioStream(_isMicMuted);
    notifyListeners();
  }

  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _agoraClient?.engine.muteLocalVideoStream(_isCameraOff);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    _isFrontCamera = !_isFrontCamera;
    await _agoraClient?.engine.switchCamera();
    notifyListeners();
  }

  /// End the current call and clean up.
  Future<void> endCall(String myUid) async {
    _stopCallTimer();
    _cancelSubscriptions();

    if (_currentMatch != null) {
      await _db.endMatch(_currentMatch!.matchId);
    }
    await _db.leaveSearchQueue(myUid);
    await _agoraClient?.engine.leaveChannel();
    _agoraClient = null;
    
    CallNotificationService().dismissCallNotification();

    _currentMatch = null;
    _partnerName = null;
    _partnerCountry = null;
    _state = CallState.idle;
    _callDurationSeconds = 0;
    notifyListeners();
  }

  /// "Next" button - end current call and immediately search again.
  Future<void> nextPartner(UserModel currentUser) async {
    _stopCallTimer();
    _cancelSubscriptions();

    if (_currentMatch != null) {
      await _db.endMatch(_currentMatch!.matchId);
    }
    await _agoraClient?.engine.leaveChannel();
    _agoraClient = null;
    
    CallNotificationService().dismissCallNotification();
    _currentMatch = null;
    _partnerName = null;
    _partnerCountry = null;
    _callDurationSeconds = 0;

    _state = CallState.idle;
    notifyListeners();

    await startSearching(currentUser);
  }

  /// Stop (completely leave) - end call and go back to home.
  Future<void> stopCompletely(String myUid) async {
    await endCall(myUid);
  }

  // ---------------------------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------------------------

  void _startCallTimer() {
    _callTimer?.cancel();
    _callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  void _cancelSubscriptions() {
    _matchStatusSub?.cancel();
    _searchSub?.cancel();
  }

  /// Dispose all resources when the provider is removed.
  @override
  void dispose() {
    _stopCallTimer();
    _cancelSubscriptions();
    _agoraClient?.engine.leaveChannel();
    super.dispose();
  }
}
