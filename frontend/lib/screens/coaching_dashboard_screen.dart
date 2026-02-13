import 'package:flutter/material.dart';
import '../models/user_model.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.coaching.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to coaching settings
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _buildNavigationDestinations(),
      ),
    );
  }

  List<NavigationDestination> _buildNavigationDestinations() {
    // Show different nav items based on user role
    if (widget.user.isAdmin) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Members',
        ),
        NavigationDestination(
          icon: Icon(Icons.class_outlined),
          selectedIcon: Icon(Icons.class_),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ];
    }

    // Default view for other roles
    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.schedule_outlined),
        selectedIcon: Icon(Icons.schedule),
        label: 'Schedule',
      ),
      NavigationDestination(
        icon: Icon(Icons.notifications_outlined),
        selectedIcon: Icon(Icons.notifications),
        label: 'Notifications',
      ),
    ];
  }

  Widget _buildBody() {
    if (widget.user.isAdmin) {
      return _buildAdminBody();
    }
    return _buildDefaultBody();
  }

  Widget _buildAdminBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildAdminDashboard();
      case 1:
        return _buildMembersView();
      case 2:
        return _buildClassesView();
      case 3:
        return _buildSettingsView();
      default:
        return _buildAdminDashboard();
    }
  }

  Widget _buildDefaultBody() {
    return const Center(child: Text('Coming soon...'));
  }

  Widget _buildAdminDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back!',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          widget.coaching.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick stats
          Text(
            'Overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Students',
                  '0',
                  Icons.school,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Teachers',
                  '0',
                  Icons.person,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Classes',
                  '0',
                  Icons.class_,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Parents',
                  '0',
                  Icons.family_restroom,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildActionTile(
            'Invite Members',
            'Add teachers, parents, and students',
            Icons.person_add,
            () {
              // TODO: Navigate to invite screen
            },
          ),
          _buildActionTile(
            'Create Class',
            'Set up a new class or batch',
            Icons.add_circle_outline,
            () {
              // TODO: Navigate to create class screen
            },
          ),
          _buildActionTile(
            'View Schedule',
            'Manage timetables and sessions',
            Icons.calendar_today,
            () {
              // TODO: Navigate to schedule screen
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildMembersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('No members yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Start by inviting teachers, parents, and students',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // TODO: Navigate to invite screen
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Invite Members'),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.class_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text('No classes yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Create your first class to get started',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // TODO: Navigate to create class screen
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Class'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Edit Coaching Details'),
          subtitle: const Text('Name, description, logo'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to edit coaching screen
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('Coaching URL'),
          subtitle: Text('@${widget.coaching.slug}'),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              // TODO: Copy link
            },
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.red),
          title: const Text(
            'Delete Coaching',
            style: TextStyle(color: Colors.red),
          ),
          subtitle: const Text('This action cannot be undone'),
          onTap: () {
            // TODO: Show delete confirmation
          },
        ),
      ],
    );
  }
}
