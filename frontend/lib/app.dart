import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/observers/app_lifecycle_observer.dart';
import 'core/observers/logging_navigator_observer.dart';
import 'core/services/error_logger_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/academic/screens/academic_onboarding_screen.dart';
import 'features/academic/services/academic_service.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/profile/screens/pending_invitations_screen.dart';
import 'shared/widgets/main_wrapper.dart';

/// Top-level material app — theme, auth guard, and root navigation.
class TutorixApp extends StatefulWidget {
  const TutorixApp({super.key});

  @override
  State<TutorixApp> createState() => _TutorixAppState();
}

class _TutorixAppState extends State<TutorixApp> {
  final _lifecycleObserver = AppLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().mode;
    return MaterialApp(
      title: 'Tutorix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      navigatorObservers: [LoggingNavigatorObserver()],
      home: const AuthWrapper(),
    );
  }
}

/// Listens to [AuthController] and swaps between the login, invitations,
/// academic onboarding, and main UI.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _academicService = AcademicService();
  bool _checkingOnboarding = true;
  bool _needsAcademicOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkAcademicOnboarding();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authController = context.read<AuthController>();
    // Re-check onboarding when auth state changes
    if (authController.isAuthenticated &&
        !authController.hasPendingInvitations) {
      _checkAcademicOnboarding();
    }
  }

  Future<void> _checkAcademicOnboarding() async {
    final authController = context.read<AuthController>();
    if (!authController.isAuthenticated) {
      setState(() {
        _checkingOnboarding = false;
        _needsAcademicOnboarding = false;
      });
      return;
    }

    try {
      final status = await _academicService.getOnboardingStatus();
      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
          _needsAcademicOnboarding = status.needsOnboarding;
        });
      }
    } catch (e, stack) {
      ErrorLoggerService.instance.warn(
        'Academic onboarding check failed — skipping',
        category: LogCategory.auth,
        error: e.toString(),
        stackTrace: stack.toString(),
      );
      if (mounted) {
        setState(() {
          _checkingOnboarding = false;
          _needsAcademicOnboarding = false;
        });
      }
    }
  }

  void _onOnboardingComplete() {
    setState(() => _needsAcademicOnboarding = false);
  }

  void _onRemindLater() {
    setState(() => _needsAcademicOnboarding = false);
  }

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

      // Show academic onboarding if needed
      if (_checkingOnboarding) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (_needsAcademicOnboarding) {
        return AcademicOnboardingScreen(
          onComplete: _onOnboardingComplete,
          onRemindLater: _onRemindLater,
        );
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
