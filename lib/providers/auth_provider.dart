import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/logger.dart';

/// Manages authentication state across the app.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;
  bool _isNewUser = false;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _firebaseUser != null;
  bool get isNewUser => _isNewUser;
  bool get hasCompletedProfile =>
      _userModel != null && _userModel!.gender.isNotEmpty;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        await _loadUserModel(user.uid);
        _databaseService.setupPresence(user.uid);
        await _databaseService.setOnlineStatus(user.uid, true);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserModel(String uid) async {
    _userModel = await _databaseService.getUser(uid);
  }

  /// Reload the user model from Firebase.
  Future<void> refreshUser() async {
    if (_firebaseUser != null) {
      await _loadUserModel(_firebaseUser!.uid);
      notifyListeners();
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // SIGN UP
  // ---------------------------------------------------------------------------

  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      if (user != null) {
        await _authService.updateDisplayName(name);

        final now = DateTime.now().millisecondsSinceEpoch;
        final newUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          createdAt: now,
          lastActive: now,
        );
        await _databaseService.saveUser(newUser);
        _userModel = newUser;
        _firebaseUser = user;
        _isNewUser = true;
        _setLoading(false);
        return true;
      }
      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      _error = AuthService.getErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      logger.e('Sign up error', error: e);
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // SIGN IN
  // ---------------------------------------------------------------------------

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (user != null) {
        await _loadUserModel(user.uid);
        _firebaseUser = user;
        _isNewUser = false;
        _setLoading(false);
        return true;
      }
      _setLoading(false);
      return false;
    } on FirebaseAuthException catch (e) {
      _error = AuthService.getErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred.';
      logger.e('Sign in error', error: e);
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // GOOGLE SIGN IN
  // ---------------------------------------------------------------------------

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _error = null;
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _firebaseUser = user;
        // Check if user exists in database
        final existing = await _databaseService.getUser(user.uid);
        if (existing == null) {
          // New Google user
          final now = DateTime.now().millisecondsSinceEpoch;
          final newUser = UserModel(
            uid: user.uid,
            name: user.displayName ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL,
            createdAt: now,
            lastActive: now,
          );
          await _databaseService.saveUser(newUser);
          _userModel = newUser;
          _isNewUser = true;
        } else {
          _userModel = existing;
          _isNewUser = false;
        }
        _setLoading(false);
        return true;
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Google sign-in failed. Please try again.';
      logger.e('Google sign-in error', error: e);
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------------------------

  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _error = null;
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = AuthService.getErrorMessage(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to send reset email.';
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PROFILE UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateProfile({
    required String gender,
    required String age,
    required String country,
    required String countryCode,
  }) async {
    if (_firebaseUser == null || _userModel == null) return;
    _setLoading(true);
    try {
      await _databaseService.updateUser(_firebaseUser!.uid, {
        'gender': gender,
        'age': age,
        'country': country,
        'countryCode': countryCode,
      });
      _userModel = _userModel!.copyWith(
        gender: gender,
        age: age,
        country: country,
        countryCode: countryCode,
      );
      _isNewUser = false;
    } catch (e) {
      logger.e('Failed to update profile', error: e);
    }
    _setLoading(false);
  }

  // ---------------------------------------------------------------------------
  // SIGN OUT
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    if (_firebaseUser != null) {
      await _databaseService.setOnlineStatus(_firebaseUser!.uid, false);
      await _databaseService.leaveSearchQueue(_firebaseUser!.uid);
    }
    await _authService.signOut();
    _firebaseUser = null;
    _userModel = null;
    _isNewUser = false;
    notifyListeners();
  }
}
