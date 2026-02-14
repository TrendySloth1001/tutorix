import 'package:flutter/material.dart';

/// The "Classes" tab shown to admins inside [CoachingDashboardScreen].
class ClassesView extends StatelessWidget {
  const ClassesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Replace with real data from service
    final classes = const [
      {'name': 'Mathematics 101', 'batch': 'Morning A', 'time': '09:00 AM'},
      {'name': 'Advanced Physics', 'batch': 'Evening B', 'time': '04:30 PM'},
      {'name': 'Literary Analysis', 'batch': 'Weekend C', 'time': '11:00 AM'},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Batches',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Class'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final c = classes[index];
              return _ClassTile(
                name: c['name']!,
                batch: c['batch']!,
                time: c['time']!,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClassTile extends StatelessWidget {
  final String name;
  final String batch;
  final String time;

  const _ClassTile({
    required this.name,
    required this.batch,
    required this.time,
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
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.tertiary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$batch • $time'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
