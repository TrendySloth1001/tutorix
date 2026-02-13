import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
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

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _initScreens();
  }

  @override
  void didUpdateWidget(MainWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _initScreens();
    }
  }

  void _initScreens() {
    _screens = [
      HomeScreen(user: widget.user, onUserUpdated: widget.onUserUpdated),
      ProfileScreen(
        user: widget.user,
        onLogout: widget.onLogout,
        onUserUpdated: widget.onUserUpdated,
      ),
    ];
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
      ),
    );
  }
}
