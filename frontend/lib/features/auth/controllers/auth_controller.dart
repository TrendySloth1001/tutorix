import 'package:flutter/material.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/invitation_service.dart';
import '../services/auth_service.dart';
import '../../profile/services/user_service.dart';

/// Application-level auth state exposed as a [ChangeNotifier].
///
/// Lives at the top of the widget tree (in [AuthWrapper]) so every
/// descendant can react to login / logout.
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final InvitationService _invitationService = InvitationService();
  final ErrorLoggerService _logger = ErrorLoggerService.instance;

  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _invitationsChecked = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  List<Map<String, dynamic>> get pendingInvitations => _pendingInvitations;
  bool get hasPendingInvitations =>
      _invitationsChecked && _pendingInvitations.isNotEmpty;

  /// Called once on app start to restore a previous session.
  ///
  /// If a cached user exists the controller becomes `isInitialized`
  /// immediately so the UI can render without a loading spinner.
  /// A background network refresh keeps the profile up-to-date.
  Future<void> initialize() async {
    final authenticated = await _authService.isAuthenticated();
    if (authenticated) {
      // 1. Show cached user immediately — no loading screen.
      final cachedUser = await _authService.getCachedUser();
      if (cachedUser != null) {
        _user = cachedUser;
        _isInitialized = true;
        notifyListeners();

        // 2. Refresh in background — failures are silent.
        _refreshSessionInBackground();
        return;
      }

      // No cached user — must wait for network.
      try {
        final freshUser = await _userService.getMe();
        _user = freshUser;
      } catch (e, stack) {
        _logger.warn(
          'No cached user and network failed',
          category: LogCategory.auth,
          error: e.toString(),
          stackTrace: stack.toString(),
        );
      }
      if (_user != null) await _checkPendingInvitations();
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Silently refresh user profile & invitations in the background.
  void _refreshSessionInBackground() {
    Future<void>(() async {
      try {
        final freshUser = await _userService.getMe();
        if (freshUser != null) {
          _user = freshUser;
          notifyListeners();
        }
      } catch (e) {
        _logger.debug(
          'Background user refresh failed: $e',
          category: LogCategory.auth,
        );
      }
      await _checkPendingInvitations();
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        await _checkPendingInvitations();
      }
    } catch (e) {
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
      _logger.debug('refreshUser failed: $e', category: LogCategory.auth);
    }
  }

  Future<void> _checkPendingInvitations() async {
    try {
      _pendingInvitations = await _invitationService.getMyInvitations();
      _invitationsChecked = true;
    } catch (e) {
      _logger.warn(
        'Failed to check pending invitations: $e',
        category: LogCategory.auth,
      );
      _pendingInvitations = [];
      _invitationsChecked = true;
    }
  }

  void dismissInvitations() {
    _pendingInvitations = [];
    notifyListeners();
  }

  Future<void> refreshInvitations() async {
    await _checkPendingInvitations();
    notifyListeners();
  }
}
