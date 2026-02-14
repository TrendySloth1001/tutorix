import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../widgets/coaching_bottom_nav.dart';
import 'coaching_dashboard_screen.dart';
import 'coaching_members_screen.dart';
import 'coaching_profile_screen.dart';

/// Root shell for a coaching — holds the [CoachingBottomNav] and swaps
/// between Dashboard, Members, and Profile screens via an [IndexedStack].
class CoachingShell extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const CoachingShell({
    super.key,
    required this.coaching,
    required this.user,
    this.onUserUpdated,
  });

  @override
  State<CoachingShell> createState() => _CoachingShellState();
}

class _CoachingShellState extends State<CoachingShell> {
  int _selectedIndex = 0;
  late CoachingModel _coaching;

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
  }

  void _onCoachingUpdated(CoachingModel updated) {
    setState(() => _coaching = updated);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CoachingDashboardScreen(
        coaching: _coaching,
        onMembersTap: () => setState(() => _selectedIndex = 1),
      ),
      CoachingMembersScreen(coaching: _coaching, user: widget.user),
      CoachingProfileScreen(
        coaching: _coaching,
        user: widget.user,
        onCoachingUpdated: _onCoachingUpdated,
        onBack: () => Navigator.pop(context),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: CoachingBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}
