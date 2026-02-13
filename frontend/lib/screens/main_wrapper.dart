import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class MainWrapper extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const MainWrapper({super.key, required this.user, required this.onLogout});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(user: widget.user),
      ProfileScreen(user: widget.user, onLogout: widget.onLogout),
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
