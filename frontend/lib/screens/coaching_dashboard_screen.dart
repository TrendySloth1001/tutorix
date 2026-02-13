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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
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
                  indicatorColor: theme.colorScheme.tertiary.withValues(
                    alpha: 0.3,
                  ),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      );
                    }
                    return theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    );
                  }),
                ),
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: _buildNavigationDestinations(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<NavigationDestination> _buildNavigationDestinations() {
    final color = Theme.of(context).colorScheme.primary;
    if (widget.user.isAdmin) {
      return [
        NavigationDestination(
          icon: Icon(
            Icons.dashboard_outlined,
            color: color.withValues(alpha: 0.5),
          ),
          selectedIcon: Icon(Icons.dashboard_rounded, color: color),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.people_outline_rounded,
            color: color.withValues(alpha: 0.5),
          ),
          selectedIcon: Icon(Icons.people_rounded, color: color),
          label: 'Members',
        ),
        NavigationDestination(
          icon: Icon(Icons.class_outlined, color: color.withValues(alpha: 0.5)),
          selectedIcon: Icon(Icons.class_rounded, color: color),
          label: 'Classes',
        ),
        NavigationDestination(
          icon: Icon(
            Icons.settings_outlined,
            color: color.withValues(alpha: 0.5),
          ),
          selectedIcon: Icon(Icons.settings_rounded, color: color),
          label: 'Settings',
        ),
      ];
    }

    return [
      NavigationDestination(
        icon: Icon(Icons.home_outlined, color: color.withValues(alpha: 0.5)),
        selectedIcon: Icon(Icons.home_rounded, color: color),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.calendar_today_outlined,
          color: color.withValues(alpha: 0.5),
        ),
        selectedIcon: Icon(Icons.calendar_today_rounded, color: color),
        label: 'Schedule',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.notifications_outlined,
          color: color.withValues(alpha: 0.5),
        ),
        selectedIcon: Icon(Icons.notifications_rounded, color: color),
        label: 'Alerts',
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_rounded,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Student Portal Coming Soon',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We are fine-tuning the experience for you.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDashboard() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Welcome Header
          Row(
            children: [
              Hero(
                tag: 'coaching_logo_${widget.coaching.id}',
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    image: widget.coaching.logo != null
                        ? DecorationImage(
                            image: NetworkImage(widget.coaching.logo!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: widget.coaching.logo == null
                      ? Icon(
                          Icons.school_rounded,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Internal Dashboard',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.6,
                        ),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.user.name?.split(' ').first != null
                          ? 'Hi, ${widget.user.name?.split(' ').first}'
                          : 'Hello Admin',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick stats in a premium grid
          Text(
            'Institute Insight',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard(
                'Total Students',
                '—',
                Icons.people_alt_rounded,
                theme.colorScheme.primary,
              ),
              _buildStatCard(
                'Educators',
                '—',
                Icons.record_voice_over_rounded,
                theme.colorScheme.primary,
              ),
              _buildStatCard(
                'Active Classes',
                '—',
                Icons.auto_stories_rounded,
                theme.colorScheme.primary,
              ),
              _buildStatCard(
                'Guardians',
                '—',
                Icons.supervisor_account_rounded,
                theme.colorScheme.primary,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick actions
          Text(
            'Management Tools',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionTile(
            'Admissions & Enrollment',
            'Invite and manage student access',
            Icons.person_add_rounded,
            () {},
          ),
          _buildActionTile(
            'Curriculum Management',
            'Organize batches and class schedules',
            Icons.layers_rounded,
            () {},
          ),
          _buildActionTile(
            'Communications',
            'Broadcast updates to parents & students',
            Icons.campaign_rounded,
            () {},
          ),

          const SizedBox(height: 40),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 24),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildMembersView() {
    final theme = Theme.of(context);
    final List<Map<String, String>> members = [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Internal Directory',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Invite'),
              ),
            ],
          ),
        ),
        if (members.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No members yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.tertiary.withValues(
                        alpha: 0.3,
                      ),
                      child: Text(
                        member['name']![0],
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                    title: Text(
                      member['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(member['role']!),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        member['status']!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildClassesView() {
    final theme = Theme.of(context);
    final List<Map<String, String>> classes = [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Batches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Class'),
              ),
            ],
          ),
        ),
        if (classes.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes scheduled',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classItem = classes[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      classItem['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${classItem['batch']} • ${classItem['time']}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsView() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildActionTile(
          'Coaching Identity',
          'Modify name, description and visual style',
          Icons.edit_note_rounded,
          () {},
        ),
        _buildActionTile(
          'Discovery Link',
          'Manage your @${widget.coaching.slug} handle',
          Icons.link_rounded,
          () {},
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.red,
            ),
            title: const Text(
              'Offboard Coaching',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Completely remove this institute and its data',
            ),
            onTap: () {},
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
