import 'package:flutter/material.dart';
import 'auth/screens/login_screen.dart';
import 'auth/services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tutorix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
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
  final AuthService _authService = AuthService();
  bool? _isAuthenticated;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authenticated = await _authService.isAuthenticated();
    setState(() {
      _isAuthenticated = authenticated;
    });
  }

  void _onLoginSuccess(Map<String, dynamic> user) {
    setState(() {
      _isAuthenticated = true;
      _user = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isAuthenticated!) {
      return MyHomePage(title: 'Tutorix Home', user: _user);
    }

    return LoginScreen(onLoginSuccess: _onLoginSuccess);
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title, this.user});

  final String title;
  final Map<String, dynamic>? user;

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // In a real app, use a navigator or state management to go back to login
              // For now, a simple restart/rebuild is needed
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (user != null && user!['picture'] != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!['picture']),
                radius: 40,
              ),
            const SizedBox(height: 20),
            Text(
              'Welcome, ${user?['name'] ?? 'User'}!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text('Email: ${user?['email'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }
}
