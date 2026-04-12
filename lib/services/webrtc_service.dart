import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/ice_server_service.dart';
import '../utils/logger.dart';

/// Callback typedefs for WebRTC events.
typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnConnectionStateChange = void Function(RTCPeerConnectionState state);
typedef OnIceCandidate = void Function(RTCIceCandidate candidate);

/// Manages WebRTC peer connections for video/audio calls.
///
/// ICE servers are fetched dynamically from the Open Relay Project (TURN)
/// instead of a static list, enabling connectivity even behind strict
/// corporate/university firewalls (symmetric NAT).
class WebRTCService {
  final IceServerService _iceServerService = IceServerService();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  OnRemoteStream? onRemoteStream;
  OnConnectionStateChange? onConnectionStateChange;
  OnIceCandidate? onIceCandidate;

  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;

  bool get isMicMuted => _isMicMuted;
  bool get isCameraOff => _isCameraOff;
  bool get isFrontCamera => _isFrontCamera;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Media constraints for getUserMedia.
  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': {
      'mandatory': {
        'minWidth': '640',
        'minHeight': '480',
        'minFrameRate': '30',
      },
      'facingMode': 'user',
      'optional': [],
    },
  };

  // ---------------------------------------------------------------------------
  // DYNAMIC ICE CONFIGURATION
  // ---------------------------------------------------------------------------

  /// Build the RTCPeerConnection configuration with dynamically fetched
  /// STUN + TURN servers from Open Relay (equivalent to npm `freeice`).
  Future<Map<String, dynamic>> _buildConfiguration() async {
    final iceServers = await _iceServerService.getIceServers();
    logger.i('[WebRTC] Using ${iceServers.length} ICE servers');

    return {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
      // Relay-only mode: set to 'relay' if you want TURN-only (ultra strict networks).
      // Leave as default ('all') to prefer direct P2P with TURN as fallback.
      'iceTransportPolicy': 'all',
    };
  }

  // ---------------------------------------------------------------------------
  // LOCAL STREAM
  // ---------------------------------------------------------------------------

  /// Initialize local media stream (camera + microphone).
  Future<MediaStream> initLocalStream() async {
    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(_mediaConstraints);
      logger.i('[WebRTC] Local stream initialised');
      return _localStream!;
    } catch (e) {
      logger.e('[WebRTC] Failed to get local stream', error: e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // PEER CONNECTION
  // ---------------------------------------------------------------------------

  /// Create the RTCPeerConnection with dynamically fetched ICE servers.
  Future<void> initializePeerConnection() async {
    try {
      // Fetch STUN+TURN servers dynamically (Open Relay / cached)
      final configuration = await _buildConfiguration();

      _peerConnection = await createPeerConnection(configuration);

      // Add local tracks to peer connection.
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Listen for remote tracks.
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          onRemoteStream?.call(_remoteStream!);
          logger.i('[WebRTC] Remote stream received');
        }
      };

      // ICE candidate events → forward to the signaling layer (Firebase).
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          onIceCandidate?.call(candidate);
        }
      };

      // ICE gathering state — useful for debugging connectivity.
      _peerConnection!.onIceGatheringState =
          (RTCIceGatheringState state) {
        logger.i('[WebRTC] ICE gathering: $state');
      };

      // ICE connection state — detect failures early.
      _peerConnection!.onIceConnectionState =
          (RTCIceConnectionState state) {
        logger.i('[WebRTC] ICE connection: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          logger.w('[WebRTC] ICE failed — clearing cache for next attempt');
          _iceServerService.clearCache();
        }
      };

      // Overall peer connection state.
      _peerConnection!.onConnectionState =
          (RTCPeerConnectionState state) {
        logger.i('[WebRTC] Peer connection: $state');
        onConnectionStateChange?.call(state);
      };

      logger.i('[WebRTC] Peer connection created');
    } catch (e) {
      logger.e('[WebRTC] Failed to create peer connection', error: e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // SDP OFFER / ANSWER
  // ---------------------------------------------------------------------------

  /// Create an SDP offer (caller / initiator side).
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);
    logger.i('[WebRTC] Offer created');
    return offer;
  }

  /// Create an SDP answer (callee / receiver side).
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    logger.i('[WebRTC] Answer created');
    return answer;
  }

  /// Set the remote SDP description (offer or answer from partner).
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
    logger.i('[WebRTC] Remote description set (${description.type})');
  }

  /// Add an ICE candidate received from the remote peer via Firebase.
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      // Non-fatal: some candidates arrive before remote desc is set
      logger.w('[WebRTC] addIceCandidate error (may be harmless): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MEDIA CONTROLS
  // ---------------------------------------------------------------------------

  /// Toggle microphone on/off.
  void toggleMic() {
    if (_localStream == null) return;
    _isMicMuted = !_isMicMuted;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMicMuted;
    }
    logger.i('[WebRTC] Mic ${_isMicMuted ? "muted" : "unmuted"}');
  }

  /// Toggle camera on/off.
  void toggleCamera() {
    if (_localStream == null) return;
    _isCameraOff = !_isCameraOff;
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = !_isCameraOff;
    }
    logger.i('[WebRTC] Camera ${_isCameraOff ? "off" : "on"}');
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    if (_localStream == null) return;
    final videoTrack = _localStream!.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
      _isFrontCamera = !_isFrontCamera;
      logger.i('[WebRTC] Camera switched to ${_isFrontCamera ? "front" : "back"}');
    }
  }

  // ---------------------------------------------------------------------------
  // CLEANUP
  // ---------------------------------------------------------------------------

  /// Dispose of all WebRTC resources properly.
  Future<void> dispose() async {
    try {
      // Stop and dispose local tracks.
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      // Close peer connection.
      if (_peerConnection != null) {
        await _peerConnection!.close();
        _peerConnection = null;
      }

      _remoteStream = null;
      _isMicMuted = false;
      _isCameraOff = false;
      _isFrontCamera = true;

      logger.i('[WebRTC] Resources disposed');
    } catch (e) {
      logger.e('[WebRTC] Error during dispose', error: e);
    }
  }
}
