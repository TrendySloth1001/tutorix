import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_wrapper.dart';
import 'controllers/auth_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthController _authController = AuthController();

  @override
  void initState() {
    super.initState();
    _authController.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _authController,
      builder: (context, _) {
        if (!_authController.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_authController.isAuthenticated) {
          return MainWrapper(
            user: _authController.user!,
            onLogout: _authController.signOut,
            onUserUpdated: _authController.updateUser,
          );
        }

        return LoginScreen(
          onLogin: _authController.signIn,
          isLoading: _authController.isLoading,
        );
      },
    );
  }
}
