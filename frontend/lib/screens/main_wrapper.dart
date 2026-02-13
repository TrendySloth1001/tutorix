import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import '../controllers/auth_controller.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainWrapper extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final Function(UserModel)? onUserUpdated;

  const MainWrapper({
    super.key,
    required this.user,
    required this.onLogout,
    this.onUserUpdated,
  });

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user!;

    final List<Widget> screens = [
      HomeScreen(user: user, onUserUpdated: widget.onUserUpdated),
      ProfileScreen(
        user: user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
      ),
    );
  }
}
