import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
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

/// Listens to [AuthController] and swaps between the login and main UI.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthController _auth = AuthController();

  @override
  void initState() {
    super.initState();
    _auth.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        if (!_auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_auth.isAuthenticated) {
          return MainWrapper(
            user: _auth.user!,
            onLogout: _auth.signOut,
            onUserUpdated: _auth.updateUser,
          );
        }

        return LoginScreen(
          onLogin: _auth.signIn,
          isLoading: _auth.isLoading,
        );
      },
    );
  }
}
