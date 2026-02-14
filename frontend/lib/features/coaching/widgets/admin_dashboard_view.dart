import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/action_tile.dart';
import '../models/coaching_model.dart';
import 'stat_card.dart';

/// The "Overview" tab shown to admins inside [CoachingDashboardScreen].
class AdminDashboardView extends StatelessWidget {
  final CoachingModel coaching;
  final UserModel user;

  const AdminDashboardView({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _WelcomeHeader(coaching: coaching, user: user),
          const SizedBox(height: 32),

          // Stats
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
              StatCard(
                title: 'Total Students',
                value: '124',
                icon: Icons.people_alt_rounded,
                color: theme.colorScheme.primary,
              ),
              StatCard(
                title: 'Educators',
                value: '12',
                icon: Icons.record_voice_over_rounded,
                color: theme.colorScheme.primary,
              ),
              StatCard(
                title: 'Active Classes',
                value: '8',
                icon: Icons.auto_stories_rounded,
                color: theme.colorScheme.primary,
              ),
              StatCard(
                title: 'Guardians',
                value: '98',
                icon: Icons.supervisor_account_rounded,
                color: theme.colorScheme.primary,
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
          ActionTile(
            title: 'Admissions & Enrollment',
            subtitle: 'Invite and manage student access',
            icon: Icons.person_add_rounded,
            onTap: () {},
          ),
          ActionTile(
            title: 'Curriculum Management',
            subtitle: 'Organize batches and class schedules',
            icon: Icons.layers_rounded,
            onTap: () {},
          ),
          ActionTile(
            title: 'Communications',
            subtitle: 'Broadcast updates to parents & students',
            icon: Icons.campaign_rounded,
            onTap: () {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────

class _WelcomeHeader extends StatelessWidget {
  final CoachingModel coaching;
  final UserModel user;

  const _WelcomeHeader({required this.coaching, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Hero(
          tag: 'coaching_logo_${coaching.id}',
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              image: coaching.logo != null
                  ? DecorationImage(
                      image: NetworkImage(coaching.logo!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: coaching.logo == null
                ? Icon(Icons.school_rounded, color: theme.colorScheme.primary)
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
                  color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user.name?.split(' ').first != null
                    ? 'Hi, ${user.name?.split(' ').first}'
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
    );
  }
}
