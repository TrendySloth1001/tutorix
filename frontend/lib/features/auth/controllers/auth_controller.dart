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
  Future<void> initialize() async {
    final authenticated = await _authService.isAuthenticated();
    if (authenticated) {
      try {
        final freshUser = await _userService.getMe();
        _user = freshUser ?? await _authService.getCachedUser();
      } catch (e, stack) {
        _logger.warn(
          'Failed to fetch fresh user, using cache',
          category: LogCategory.auth,
          error: e.toString(),
          stackTrace: stack.toString(),
        );
        _user = await _authService.getCachedUser();
      }
      await _checkPendingInvitations();
    }
    _isInitialized = true;
    notifyListeners();
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
