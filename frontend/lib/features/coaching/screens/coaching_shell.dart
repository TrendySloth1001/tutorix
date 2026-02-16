import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../widgets/coaching_bottom_nav.dart';
import 'coaching_dashboard_screen.dart';
import 'coaching_members_screen.dart';
import 'coaching_profile_screen.dart';
import '../../batch/screens/batches_list_screen.dart';

/// Root shell for a coaching — holds the [CoachingBottomNav] and lazily
/// builds screens only when visited for the first time.
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

  /// Track which tabs have been visited so we only build them lazily.
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _coaching = widget.coaching;
  }

  void _onCoachingUpdated(CoachingModel updated) {
    setState(() => _coaching = updated);
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return CoachingDashboardScreen(
          coaching: _coaching,
          user: widget.user,
          onMembersTap: () => setState(() {
            _selectedIndex = 1;
            _visitedTabs.add(1);
          }),
          onBack: () => Navigator.pop(context),
        );
      case 1:
        return CoachingMembersScreen(coaching: _coaching, user: widget.user);
      case 2:
        return BatchesListScreen(coaching: _coaching, user: widget.user);
      case 3:
        return CoachingProfileScreen(
          coaching: _coaching,
          user: widget.user,
          onCoachingUpdated: _onCoachingUpdated,
          onBack: () => Navigator.pop(context),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(4, (i) {
          // Only build screens that have been visited
          if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
          return _buildScreen(i);
        }),
      ),
      bottomNavigationBar: CoachingBottomNav(
        selectedIndex: _selectedIndex,
        onItemSelected: (i) => setState(() {
          _selectedIndex = i;
          _visitedTabs.add(i);
        }),
      ),
    );
  }
}
