import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/ice_server_service.dart';
import '../utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';

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
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    },
    'video': {
      'mandatory': {
        'minWidth': 640,
        'minHeight': 480,
        'minFrameRate': 30,
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
      final statuses = await [Permission.camera, Permission.microphone].request();
      if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
        throw Exception('Camera or microphone permissions denied.');
      }

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
      
      // Ensure audio is routed to speaker by default
      await Helper.setSpeakerphoneOn(true);

      // Add local tracks using transceivers (Unified Plan best practice)
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          final transceiverInit = RTCRtpTransceiverInit(
            direction: TransceiverDirection.SendRecv,
            streams: [_localStream!],
          );
          await _peerConnection!.addTransceiver(
            track: track,
            init: transceiverInit,
          );
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
    
    // Mangle SDP: Prefer VP8 and set bitrate
    String sdp = offer.sdp!;
    sdp = _preferVP8(sdp);
    sdp = _setVideoBitrate(sdp, 1500);
    
    final mangledOffer = RTCSessionDescription(sdp, offer.type);
    await _peerConnection!.setLocalDescription(mangledOffer);
    logger.i('[WebRTC] Offer created with VP8 preference & bitrate mangling');
    return mangledOffer;
  }

  /// Create an SDP answer (callee / receiver side).
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    
    // Mangle SDP: Prefer VP8 and set bitrate
    String sdp = answer.sdp!;
    sdp = _preferVP8(sdp);
    sdp = _setVideoBitrate(sdp, 1500);
    
    final mangledAnswer = RTCSessionDescription(sdp, answer.type);
    await _peerConnection!.setLocalDescription(mangledAnswer);
    logger.i('[WebRTC] Answer created with VP8 preference & bitrate mangling');
    return mangledAnswer;
  }

  /// Force VP8 to be the preferred codec (avoids buggy H.264 hardware encoders).
  String _preferVP8(String sdp) {
    final lines = sdp.split('\r\n');
    int? mVideoIndex;
    
    for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('m=video')) {
            mVideoIndex = i;
            break;
        }
    }
    if (mVideoIndex == null) return sdp;

    // Find VP8 payload type
    String? vp8Payload;
    for (final line in lines) {
        if (line.contains('VP8/90000')) {
            final regExp = RegExp(r'a=rtpmap:(\d+) VP8/90000');
            final match = regExp.firstMatch(line);
            if (match != null) {
                vp8Payload = match.group(1);
                break;
            }
        }
    }

    if (vp8Payload == null) return sdp;

    // Reorder the m=video line to put vp8Payload first
    final mLine = lines[mVideoIndex];
    final parts = mLine.split(' ');
    final protocol = parts[2]; // e.g., UDP/TLS/RTP/SAVPF
    final payloads = parts.sublist(3);
    
    payloads.remove(vp8Payload);
    payloads.insert(0, vp8Payload);
    
    lines[mVideoIndex] = '${parts[0]} ${parts[1]} $protocol ${payloads.join(' ')}';
    return lines.join('\r\n');
  }

  /// Force a specific video bitrate in the SDP.
  String _setVideoBitrate(String sdp, int bitrate) {
    // Check if bitrate line already exists
    if (sdp.contains('b=AS:')) {
      return sdp.replaceAll(RegExp(r'b=AS:\d+'), 'b=AS:$bitrate');
    }
    
    // Regex to find the video media definition and its attributes
    final regExp = RegExp(r'(m=video.*\r?\n(a=.*\r?\n)*)', multiLine: true);
    return sdp.replaceAllMapped(regExp, (match) {
      return '${match.group(1)}b=AS:$bitrate\r\n';
    });
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

  /// Close ONLY the peer connection, keep local camera alive.
  Future<void> stopPeerConnection() async {
    try {
      if (_peerConnection != null) {
        // Remove all listeners first
        _peerConnection!.onIceCandidate = null;
        _peerConnection!.onTrack = null;
        _peerConnection!.onIceConnectionState = null;
        _peerConnection!.onConnectionState = null;
        _peerConnection!.onIceGatheringState = null;
        
        await _peerConnection!.close();
        _peerConnection = null;
      }
      _remoteStream = null;
      logger.i('[WebRTC] PeerConnection closed (Local stream preserved)');
    } catch (e) {
      logger.e('[WebRTC] Error closing peer connection', error: e);
    }
  }

  /// Dispose of all WebRTC resources properly (full stop).
  Future<void> dispose() async {
    try {
      await stopPeerConnection();

      // Stop and dispose local tracks.
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }

      _isMicMuted = false;
      _isCameraOff = false;
      _isFrontCamera = true;

      logger.i('[WebRTC] All resources disposed');
    } catch (e) {
      logger.e('[WebRTC] Error during full dispose', error: e);
    }
  }
}
