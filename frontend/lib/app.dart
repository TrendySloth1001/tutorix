import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/profile/screens/pending_invitations_screen.dart';
import 'shared/widgets/main_wrapper.dart';

/// Top-level material app — theme, auth guard, and root navigation.
class TutorixApp extends StatelessWidget {
  const TutorixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tutorix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

/// Listens to [AuthController] and swaps between the login, invitations,
/// and main UI.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    if (!authController.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authController.isAuthenticated) {
      final user = authController.user!;

      // Show pending invitations first (after signup/login)
      if (authController.hasPendingInvitations) {
        return const PendingInvitationsScreen();
      }

      return MainWrapper(
        user: user,
        onLogout: authController.signOut,
        onUserUpdated: authController.updateUser,
      );
    }

    return LoginScreen(
      onLogin: authController.signIn,
      isLoading: authController.isLoading,
    );
  }
}
