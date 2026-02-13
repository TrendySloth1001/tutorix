import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/invitation_service.dart';
import '../services/user_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final InvitationService _invitationService = InvitationService();

  UserModel? _user;
  WardModel? _activeWard;
  bool _isProfileSelected = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  List<Map<String, dynamic>> _pendingInvitations = [];
  bool _invitationsChecked = false;

  UserModel? get user => _user;
  WardModel? get activeWard => _activeWard;
  bool get isProfileSelected => _isProfileSelected;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isInitialized => _isInitialized;
  List<Map<String, dynamic>> get pendingInvitations => _pendingInvitations;
  bool get hasPendingInvitations =>
      _invitationsChecked && _pendingInvitations.isNotEmpty;

  void selectWard(WardModel? ward) {
    _activeWard = ward;
    _isProfileSelected = true;
    notifyListeners();
  }

  Future<void> initialize() async {
    final authenticated = await _authService.isAuthenticated();
    if (authenticated) {
      try {
        final freshUser = await _userService.getMe();
        if (freshUser != null) {
          _user = freshUser;
        } else {
          _user = await _authService.getUserProfile();
        }
      } catch (e) {
        _user = await _authService.getUserProfile();
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

  Future<void> _checkPendingInvitations() async {
    try {
      _pendingInvitations = await _invitationService.getMyInvitations();
      _invitationsChecked = true;
    } catch (e) {
      debugPrint('Check invitations error: $e');
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
