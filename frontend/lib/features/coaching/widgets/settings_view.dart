import 'package:flutter/material.dart';
import '../../../shared/widgets/action_tile.dart';
import '../models/coaching_model.dart';

/// The "Settings" tab shown to admins inside [CoachingDashboardScreen].
class SettingsView extends StatelessWidget {
  final CoachingModel coaching;

  const SettingsView({super.key, required this.coaching});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ActionTile(
          title: 'Coaching Identity',
          subtitle: 'Modify name, description and visual style',
          icon: Icons.edit_note_rounded,
          onTap: () {},
        ),
        ActionTile(
          title: 'Discovery Link',
          subtitle: 'Manage your @${coaching.slug} handle',
          icon: Icons.link_rounded,
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.red.withValues(alpha: 0.1)),
          ),
          child: ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: Colors.red),
            title: const Text(
              'Offboard Coaching',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
                'Completely remove this institute and its data'),
            onTap: () {},
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
