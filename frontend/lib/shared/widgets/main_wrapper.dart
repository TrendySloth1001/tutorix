import 'package:flutter/material.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../shared/models/user_model.dart';
import 'custom_bottom_nav.dart';

/// Root scaffold that holds the bottom navigation and switches between
/// [HomeScreen] and [ProfileScreen].
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
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _buildScreens();
  }

  @override
  void didUpdateWidget(MainWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) _buildScreens();
  }

  void _buildScreens() {
    _screens = [
      HomeScreen(user: widget.user, onUserUpdated: widget.onUserUpdated),
      ProfileScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}
