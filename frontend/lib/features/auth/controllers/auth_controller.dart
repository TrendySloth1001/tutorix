import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../services/auth_service.dart';
import '../../profile/services/user_service.dart';

/// Application-level auth state exposed as a [ChangeNotifier].
///
/// Lives at the top of the widget tree (in [AuthWrapper]) so every
/// descendant can react to login / logout.
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;

  /// Called once on app start to restore a previous session.
  Future<void> initialize() async {
    final authenticated = await _authService.isAuthenticated();
    if (authenticated) {
      try {
        final freshUser = await _userService.getMe();
        _user = freshUser ?? await _authService.getCachedUser();
      } catch (_) {
        _user = await _authService.getCachedUser();
      }
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> signIn() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) _user = user;
    } catch (e) {
      debugPrint('Sign in error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  void updateUser(UserModel updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    try {
      final freshUser = await _userService.getMe();
      if (freshUser != null) {
        _user = freshUser;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh user error: $e');
    }
  }
}
