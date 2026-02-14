import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../models/coaching_model.dart';
import '../widgets/admin_dashboard_view.dart';
import '../widgets/members_view.dart';
import '../widgets/classes_view.dart';
import '../widgets/settings_view.dart';

/// Dashboard shell for a single coaching institute.
///
/// Delegates each tab body to a dedicated widget so this file stays thin.
class CoachingDashboardScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;

  const CoachingDashboardScreen({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  State<CoachingDashboardScreen> createState() =>
      _CoachingDashboardScreenState();
}

class _CoachingDashboardScreenState extends State<CoachingDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Hero(
          tag: 'coaching_name_${widget.coaching.id}',
          child: Material(
            color: Colors.transparent,
            child: Text(
              widget.coaching.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Navigate to coaching settings
            },
            color: theme.colorScheme.primary,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _BottomNav(
        isAdmin: widget.user.isAdmin,
        selectedIndex: _selectedIndex,
        onSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.user.isAdmin) {
      return switch (_selectedIndex) {
        0 => AdminDashboardView(
            coaching: widget.coaching, user: widget.user),
        1 => const MembersView(),
        2 => const ClassesView(),
        3 => SettingsView(coaching: widget.coaching),
        _ => AdminDashboardView(
            coaching: widget.coaching, user: widget.user),
      };
    }
    return _StudentPlaceholder();
  }
}

// ── Private helper widgets ───────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final bool isAdmin;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _BottomNav({
    required this.isAdmin,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Theme(
            data: theme.copyWith(
              navigationBarTheme: NavigationBarThemeData(
                indicatorColor:
                    theme.colorScheme.tertiary.withValues(alpha: 0.3),
                labelTextStyle:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    );
                  }
                  return theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary
                        .withValues(alpha: 0.5),
                  );
                }),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: isAdmin
                  ? _adminDestinations(color)
                  : _defaultDestinations(color),
            ),
          ),
        ),
      ),
    );
  }

  List<NavigationDestination> _adminDestinations(Color c) => [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.dashboard_rounded, color: c),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline_rounded,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.people_rounded, color: c),
          label: 'Members',
        ),
        NavigationDestination(
          icon: Icon(Icons.class_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.class_rounded, color: c),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.settings_rounded, color: c),
          label: 'Settings',
        ),
      ];

  List<NavigationDestination> _defaultDestinations(Color c) => [
        NavigationDestination(
          icon: Icon(Icons.home_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.home_rounded, color: c),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.calendar_today_rounded, color: c),
          label: 'Schedule',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined,
              color: c.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.notifications_rounded, color: c),
          label: 'Alerts',
        ),
      ];
}

class _StudentPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Student Portal Coming Soon',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We are fine-tuning the experience for you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary
                  .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
