import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/explore/screens/explore_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/models/user_model.dart';
import 'custom_bottom_nav.dart';

/// Root scaffold that holds the bottom navigation and switches between
/// Home, Explore, Settings, and Profile screens.
class MainWrapper extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final ValueChanged<UserModel>? onUserUpdated;

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

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.user!;

    final List<Widget> screens = [
      HomeScreen(user: user, onUserUpdated: widget.onUserUpdated),
      ExploreScreen(user: user, onUserUpdated: widget.onUserUpdated),
      SettingsScreen(user: user, onUserUpdated: widget.onUserUpdated),
      ProfileScreen(
        user: user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}
