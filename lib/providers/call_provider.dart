import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/webrtc_service.dart';
import '../utils/logger.dart';

/// States of a video call.
enum CallState {
  idle,
  searching,
  connecting,
  connected,
  ended,
}

/// Manages the entire video call lifecycle.
class CallProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final WebRTCService _webrtc = WebRTCService();

  CallState _state = CallState.idle;
  MatchModel? _currentMatch;
  String? _partnerName;
  String? _partnerCountry;
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  String? _error;

  // WebRTC renderers
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // Subscriptions
  StreamSubscription? _matchStatusSub;
  StreamSubscription? _answerSub;
  StreamSubscription? _offerSub;
  StreamSubscription? _candidateSub;
  StreamSubscription? _searchSub;

  // Getters
  CallState get state => _state;
  MatchModel? get currentMatch => _currentMatch;
  String? get partnerName => _partnerName;
  String? get partnerCountry => _partnerCountry;
  int get callDurationSeconds => _callDurationSeconds;
  String? get error => _error;
  bool get isMicMuted => _webrtc.isMicMuted;
  bool get isCameraOff => _webrtc.isCameraOff;

  String get callDurationFormatted {
    final m = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Initialize video renderers.
  Future<void> initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  /// Start searching for a partner.
  Future<void> startSearching(UserModel currentUser) async {
    if (_state != CallState.idle && _state != CallState.ended) return;

    _state = CallState.searching;
    _error = null;
    _callDurationSeconds = 0;
    notifyListeners();

    try {
      // Initialize local stream
      final localStream = await _webrtc.initLocalStream();
      localRenderer.srcObject = localStream;
      notifyListeners();

      // Join search queue
      await _db.joinSearchQueue(currentUser);

      // Attempt to find a partner
      _attemptMatch(currentUser);

      // Also listen for being matched by someone else
      _searchSub = _db.listenForMatch(currentUser.uid).listen((event) {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status == 'matched' && _state == CallState.searching) {
          final matchId = data['matchId'] as String?;
          if (matchId != null) {
            _onMatchedByPartner(matchId, currentUser);
          }
        }
      });
    } catch (e) {
      logger.e('Failed to start searching', error: e);
      _error = 'Failed to start. Please check camera permissions.';
      _state = CallState.idle;
      notifyListeners();
    }
  }

  /// Periodically try to find a partner (every 2 seconds).
  void _attemptMatch(UserModel currentUser) {
    Future<void> tryOnce() async {
      if (_state != CallState.searching) return;

      final partner = await _db.findPartner(currentUser);
      if (partner != null && _state == CallState.searching) {
        // Found a match! Create it.
        final matchId = await _db.createMatch(
          user1: currentUser.uid,
          user2: partner['uid'] as String,
          user1Name: currentUser.name,
          user2Name: partner['name'] as String,
        );

        _partnerName = partner['name'] as String?;
        _partnerCountry = partner['country'] as String?;
        _currentMatch = await _db.getMatch(matchId);

        // I am the initiator → create offer
        await _startCallAsInitiator(matchId, currentUser.uid,
            partner['uid'] as String);
      } else if (_state == CallState.searching) {
        // Try again in 500 milliseconds (Ultra-fast searching)
        await Future.delayed(const Duration(milliseconds: 500));
        tryOnce();
      }
    }

    tryOnce();
  }

  /// Called when another user matched us.
  Future<void> _onMatchedByPartner(
      String matchId, UserModel currentUser) async {
    try {
      _currentMatch = await _db.getMatch(matchId);
      if (_currentMatch == null) return;

      _partnerName =
          _currentMatch!.getPartnerName(currentUser.uid) ?? 'Anonymous';

      // I am NOT the initiator → wait for offer, then send answer
      await _startCallAsReceiver(
          matchId, currentUser.uid, _currentMatch!.getPartnerUid(currentUser.uid));
    } catch (e) {
      logger.e('Error handling match', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // WEBRTC SIGNALING
  // ---------------------------------------------------------------------------

  Future<void> _startCallAsInitiator(
      String matchId, String myUid, String partnerUid) async {
    _state = CallState.connecting;
    notifyListeners();

    try {
      // Set up WebRTC callbacks
      _webrtc.onRemoteStream = (stream) {
        remoteRenderer.srcObject = stream;
        _state = CallState.connected;
        _startCallTimer();
        notifyListeners();
      };

      _webrtc.onIceCandidate = (candidate) {
        _db.sendIceCandidate(matchId, myUid, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      _webrtc.onConnectionStateChange = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          endCall(myUid);
        }
      };

      await _webrtc.initializePeerConnection();

      // Create and send offer
      final offer = await _webrtc.createOffer();
      await _db.sendOffer(matchId, {
        'type': offer.type,
        'sdp': offer.sdp,
      });

      // Listen for answer
      _answerSub = _db.listenForAnswer(matchId).listen((event) async {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final answer = RTCSessionDescription(
          data['sdp'] as String?,
          data['type'] as String?,
        );
        await _webrtc.setRemoteDescription(answer);
      });

      // Listen for ICE candidates from partner
      _candidateSub =
          _db.listenForCandidates(matchId, partnerUid).listen((event) async {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        await _webrtc.addIceCandidate(candidate);
      });

      // Listen for partner ending the call
      _matchStatusSub =
          _db.listenForMatchStatus(matchId).listen((event) {
        if (!event.snapshot.exists) return;
        final status = event.snapshot.value as String?;
        if (status == 'ended' && _state == CallState.connected) {
          _onPartnerEndedCall();
        }
      });
    } catch (e) {
      logger.e('Failed to start call as initiator', error: e);
      _error = 'Connection failed. Please try again.';
      _state = CallState.idle;
      notifyListeners();
    }
  }

  Future<void> _startCallAsReceiver(
      String matchId, String myUid, String partnerUid) async {
    _state = CallState.connecting;
    notifyListeners();

    try {
      _webrtc.onRemoteStream = (stream) {
        remoteRenderer.srcObject = stream;
        _state = CallState.connected;
        _startCallTimer();
        notifyListeners();
      };

      _webrtc.onIceCandidate = (candidate) {
        _db.sendIceCandidate(matchId, myUid, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      _webrtc.onConnectionStateChange = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          endCall(myUid);
        }
      };

      await _webrtc.initializePeerConnection();

      // Listen for offer
      _offerSub = _db.listenForOffer(matchId).listen((event) async {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final offer = RTCSessionDescription(
          data['sdp'] as String?,
          data['type'] as String?,
        );
        await _webrtc.setRemoteDescription(offer);

        // Create and send answer
        final answer = await _webrtc.createAnswer();
        await _db.sendAnswer(matchId, {
          'type': answer.type,
          'sdp': answer.sdp,
        });
      });

      // Listen for ICE candidates from partner
      _candidateSub =
          _db.listenForCandidates(matchId, partnerUid).listen((event) async {
        if (!event.snapshot.exists || event.snapshot.value == null) return;
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final candidate = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          data['sdpMLineIndex'] as int?,
        );
        await _webrtc.addIceCandidate(candidate);
      });

      // Listen for partner ending the call
      _matchStatusSub =
          _db.listenForMatchStatus(matchId).listen((event) {
        if (!event.snapshot.exists) return;
        final status = event.snapshot.value as String?;
        if (status == 'ended' && _state == CallState.connected) {
          _onPartnerEndedCall();
        }
      });
    } catch (e) {
      logger.e('Failed to start call as receiver', error: e);
      _error = 'Connection failed. Please try again.';
      _state = CallState.idle;
      notifyListeners();
    }
  }

  void _onPartnerEndedCall() {
    _stopCallTimer();
    _state = CallState.ended;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // CALL CONTROLS
  // ---------------------------------------------------------------------------

  void toggleMic() {
    _webrtc.toggleMic();
    notifyListeners();
  }

  void toggleCamera() {
    _webrtc.toggleCamera();
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
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
    await _webrtc.dispose();

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

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
    await _webrtc.dispose();

    remoteRenderer.srcObject = null;
    _currentMatch = null;
    _partnerName = null;
    _partnerCountry = null;
    _callDurationSeconds = 0;

    _state = CallState.searching;
    notifyListeners();

    // Re-join search queue and find a new partner
    await _db.joinSearchQueue(currentUser);
    final localStream = await _webrtc.initLocalStream();
    localRenderer.srcObject = localStream;
    notifyListeners();

    _attemptMatch(currentUser);

    _searchSub = _db.listenForMatch(currentUser.uid).listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'matched' && _state == CallState.searching) {
        final matchId = data['matchId'] as String?;
        if (matchId != null) {
          _onMatchedByPartner(matchId, currentUser);
        }
      }
    });
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
    _answerSub?.cancel();
    _offerSub?.cancel();
    _candidateSub?.cancel();
    _searchSub?.cancel();
  }

  /// Dispose all resources when the provider is removed.
  @override
  void dispose() {
    _stopCallTimer();
    _cancelSubscriptions();
    _webrtc.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
