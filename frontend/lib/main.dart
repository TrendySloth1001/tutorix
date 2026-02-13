import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'screens/pending_invitations_screen.dart';
import 'screens/ward_selection_screen.dart';
import 'controllers/auth_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController()..initialize(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

      // Force ward selection if user is a hybrid (Parent + Ward) or has wards
      if ((user.isParent || user.isWard) && !authController.isProfileSelected) {
        return const WardSelectionScreen();
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
