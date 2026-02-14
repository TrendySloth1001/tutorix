import 'package:flutter/material.dart';

/// The "Members" tab shown to admins inside [CoachingDashboardScreen].
class MembersView extends StatelessWidget {
  const MembersView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Replace with real data from service
    final members = const [
      {'name': 'Arjun Mehra', 'role': 'Lead Educator', 'status': 'Active'},
      {'name': 'Sara Khan', 'role': 'Student', 'status': 'Online'},
      {'name': 'Rohan Das', 'role': 'Student', 'status': 'Away'},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Internal Directory',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Invite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final m = members[index];
              return _MemberTile(
                name: m['name']!,
                role: m['role']!,
                status: m['status']!,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String role;
  final String status;

  const _MemberTile({
    required this.name,
    required this.role,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          backgroundColor:
              theme.colorScheme.tertiary.withValues(alpha: 0.3),
          child: Text(
            name[0],
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
