import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import '../models/report_model.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

/// Handles all Firebase Realtime Database operations.
/// Firebase serves as the complete backend – no separate server needed.
class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ---------------------------------------------------------------------------
  // USER OPERATIONS
  // ---------------------------------------------------------------------------

  /// Create or update a user profile.
  Future<void> saveUser(UserModel user) async {
    try {
      await _db
          .ref(AppConstants.usersPath)
          .child(user.uid)
          .set(user.toJson());
    } catch (e) {
      logger.e('Failed to save user', error: e);
      rethrow;
    }
  }

  /// Update specific user fields.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.ref(AppConstants.usersPath).child(uid).update(data);
    } catch (e) {
      logger.e('Failed to update user', error: e);
      rethrow;
    }
  }

  /// Fetch a user by UID.
  Future<UserModel?> getUser(String uid) async {
    try {
      final snapshot =
          await _db.ref(AppConstants.usersPath).child(uid).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return UserModel.fromJson(
        snapshot.value as Map<dynamic, dynamic>,
        uid,
      );
    } catch (e) {
      logger.e('Failed to get user', error: e);
      return null;
    }
  }

  /// Set user online/offline status and update lastActive.
  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    await updateUser(uid, {
      'isOnline': isOnline,
      'lastActive': ServerValue.timestamp,
    });
  }

  /// Set up on-disconnect to auto-remove from active_users and set offline.
  void setupPresence(String uid) {
    final userStatusRef =
        _db.ref(AppConstants.usersPath).child(uid);
    final activeRef =
        _db.ref(AppConstants.activeUsersPath).child(uid);

    // When the client disconnects, clean up.
    userStatusRef.onDisconnect().update({
      'isOnline': false,
      'isSearching': false,
      'lastActive': ServerValue.timestamp,
    });
    activeRef.onDisconnect().remove();
  }

  // ---------------------------------------------------------------------------
  // ACTIVE USERS / MATCHMAKING QUEUE
  // ---------------------------------------------------------------------------

  /// Add current user to the searching queue.
  Future<void> joinSearchQueue(UserModel user) async {
    try {
      await _db
          .ref(AppConstants.activeUsersPath)
          .child(user.uid)
          .set({
        'status': 'searching',
        'gender': user.gender,
        'interestedIn': user.interestedIn,
        'country': user.countryCode,
        'name': user.name,
        'joinedAt': ServerValue.timestamp,
      });
      await updateUser(user.uid, {'isSearching': true});
    } catch (e) {
      logger.e('Failed to join search queue', error: e);
      rethrow;
    }
  }

  /// Remove current user from the searching queue.
  Future<void> leaveSearchQueue(String uid) async {
    try {
      await _db
          .ref(AppConstants.activeUsersPath)
          .child(uid)
          .remove();
      await updateUser(uid, {'isSearching': false});
    } catch (e) {
      logger.e('Failed to leave search queue', error: e);
    }
  }

  /// Find a compatible partner from the active users queue.
  /// Gender preference matching: if user wants "Women" only match "Female", etc.
  Future<Map<String, dynamic>?> findPartner(UserModel currentUser) async {
    try {
      final snapshot =
          await _db.ref(AppConstants.activeUsersPath).get();
      if (!snapshot.exists || snapshot.value == null) return null;

      final activeUsers = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in activeUsers.entries) {
        final partnerUid = entry.key as String;
        if (partnerUid == currentUser.uid) continue;

        final partnerData = entry.value as Map<dynamic, dynamic>;
        final partnerStatus = partnerData['status'] as String? ?? '';
        if (partnerStatus != 'searching') continue;

        // Check if they are blocked
        if (currentUser.blockedUsers.contains(partnerUid)) continue;

        // Gender preference matching
        final partnerGender = partnerData['gender'] as String? ?? '';
        final partnerInterestedIn =
            (partnerData['interestedIn'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

        // Check if current user's interests match partner's gender
        if (!_isGenderMatch(
            currentUser.interestedIn, partnerGender)) {
          continue;
        }

        // Check if partner's interests match current user's gender
        if (!_isGenderMatch(partnerInterestedIn, currentUser.gender)) {
          continue;
        }

        return {
          'uid': partnerUid,
          'name': partnerData['name'] as String? ?? 'Anonymous',
          'gender': partnerGender,
          'country': partnerData['country'] as String? ?? '',
        };
      }
      return null;
    } catch (e) {
      logger.e('Failed to find partner', error: e);
      return null;
    }
  }

  bool _isGenderMatch(List<String> interests, String gender) {
    if (interests.contains('Everyone')) return true;
    if (interests.isEmpty) return true;
    if (gender == 'Male' && interests.contains('Men')) return true;
    if (gender == 'Female' && interests.contains('Women')) return true;
    if (gender == 'Other') return true; // Everyone can match Other
    return false;
  }

  // ---------------------------------------------------------------------------
  // MATCHES
  // ---------------------------------------------------------------------------

  /// Create a new match and return the match ID.
  Future<String> createMatch({
    required String user1,
    required String user2,
    required String user1Name,
    required String user2Name,
  }) async {
    try {
      final matchRef = _db.ref(AppConstants.matchesPath).push();
      final matchId = matchRef.key!;
      final match = MatchModel(
        matchId: matchId,
        user1: user1,
        user2: user2,
        startedAt: DateTime.now().millisecondsSinceEpoch,
        status: 'active',
        initiator: user1,
        user1Name: user1Name,
        user2Name: user2Name,
      );
      await matchRef.set(match.toJson());

      // Mark both users as matched (not searching)
      await _db
          .ref(AppConstants.activeUsersPath)
          .child(user1)
          .update({'status': 'matched', 'matchId': matchId});
      await _db
          .ref(AppConstants.activeUsersPath)
          .child(user2)
          .update({'status': 'matched', 'matchId': matchId});

      return matchId;
    } catch (e) {
      logger.e('Failed to create match', error: e);
      rethrow;
    }
  }

  /// End a match.
  Future<void> endMatch(String matchId) async {
    try {
      await _db.ref(AppConstants.matchesPath).child(matchId).update({
        'status': 'ended',
        'endedAt': ServerValue.timestamp,
      });
      // Clean up signaling sub-nodes from the match
      await _db.ref(AppConstants.matchesPath).child(matchId).child('offer').remove();
      await _db.ref(AppConstants.matchesPath).child(matchId).child('answer').remove();
      await _db.ref(AppConstants.matchesPath).child(matchId).child('candidates').remove();
    } catch (e) {
      logger.e('Failed to end match', error: e);
    }
  }

  /// Listen for when current user gets matched by someone else.
  Stream<DatabaseEvent> listenForMatch(String uid) {
    return _db
        .ref(AppConstants.activeUsersPath)
        .child(uid)
        .onValue;
  }

  /// Get match data.
  Future<MatchModel?> getMatch(String matchId) async {
    try {
      final snapshot =
          await _db.ref(AppConstants.matchesPath).child(matchId).get();
      if (!snapshot.exists || snapshot.value == null) return null;
      return MatchModel.fromJson(
        snapshot.value as Map<dynamic, dynamic>,
        matchId,
      );
    } catch (e) {
      logger.e('Failed to get match', error: e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // WEBRTC SIGNALING VIA FIREBASE
  // ---------------------------------------------------------------------------

  /// Send WebRTC offer (SDP).
  Future<void> sendOffer(String matchId, Map<String, dynamic> offer) async {
    await _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('offer')
        .set(offer);
  }

  /// Send WebRTC answer (SDP).
  Future<void> sendAnswer(String matchId, Map<String, dynamic> answer) async {
    await _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('answer')
        .set(answer);
  }

  /// Send ICE candidate.
  Future<void> sendIceCandidate(
      String matchId, String senderUid, Map<String, dynamic> candidate) async {
    await _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('candidates')
        .child(senderUid)
        .push()
        .set(candidate);
  }

  /// Listen for WebRTC offer.
  Stream<DatabaseEvent> listenForOffer(String matchId) {
    return _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('offer')
        .onValue;
  }

  /// Listen for WebRTC answer.
  Stream<DatabaseEvent> listenForAnswer(String matchId) {
    return _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('answer')
        .onValue;
  }

  /// Listen for ICE candidates from remote peer.
  Stream<DatabaseEvent> listenForCandidates(
      String matchId, String remoteUid) {
    return _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('candidates')
        .child(remoteUid)
        .onChildAdded;
  }

  /// Listen for match status changes (e.g., partner ended call).
  Stream<DatabaseEvent> listenForMatchStatus(String matchId) {
    return _db
        .ref(AppConstants.matchesPath)
        .child(matchId)
        .child('status')
        .onValue;
  }

  // ---------------------------------------------------------------------------
  // REPORTS & BLOCKING
  // ---------------------------------------------------------------------------

  /// Submit a report.
  Future<void> submitReport(ReportModel report) async {
    try {
      await _db
          .ref(AppConstants.reportsPath)
          .child(report.reportId)
          .set(report.toJson());
    } catch (e) {
      logger.e('Failed to submit report', error: e);
      rethrow;
    }
  }

  /// Block a user.
  Future<void> blockUser(String myUid, String blockedUid) async {
    try {
      // Add to blocked list in user's profile
      final userRef =
          _db.ref(AppConstants.usersPath).child(myUid).child('blockedUsers');
      final snapshot = await userRef.get();
      List<String> blocked = [];
      if (snapshot.exists && snapshot.value != null) {
        blocked = (snapshot.value as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      }
      if (!blocked.contains(blockedUid)) {
        blocked.add(blockedUid);
        await userRef.set(blocked);
      }
    } catch (e) {
      logger.e('Failed to block user', error: e);
      rethrow;
    }
  }

  /// Check if user is banned.
  Future<bool> isUserBanned(String uid) async {
    try {
      final snapshot =
          await _db.ref(AppConstants.bannedUsersPath).child(uid).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // CALL HISTORY
  // ---------------------------------------------------------------------------

  /// Get call history for a user.
  Future<List<MatchModel>> getCallHistory(String uid) async {
    try {
      final snapshot = await _db
          .ref(AppConstants.matchesPath)
          .orderByChild('status')
          .equalTo('ended')
          .get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final matches = snapshot.value as Map<dynamic, dynamic>;
      final history = <MatchModel>[];

      for (final entry in matches.entries) {
        final data = entry.value as Map<dynamic, dynamic>;
        if (data['user1'] == uid || data['user2'] == uid) {
          history.add(MatchModel.fromJson(data, entry.key as String));
        }
      }

      // Sort by startedAt descending
      history.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return history;
    } catch (e) {
      logger.e('Failed to get call history', error: e);
      return [];
    }
  }
}
