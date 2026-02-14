import 'package:flutter/material.dart';
import '../models/coaching_model.dart';

/// Simple, clean coaching tile for daily use - no heavy cards.
class CoachingCard extends StatelessWidget {
  final CoachingModel coaching;
  final VoidCallback onTap;
  final bool showRole;

  const CoachingCard({
    super.key,
    required this.coaching,
    required this.onTap,
    this.showRole = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = coaching.logo != null && coaching.logo!.isNotEmpty;
    final isJoined = showRole && coaching.myRole != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Hero(
                tag: 'coaching_logo_${coaching.id}',
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isJoined
                        ? _getRoleColor(coaching.myRole).withValues(alpha: 0.08)
                        : theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: hasLogo
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            coaching.logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildAvatarPlaceholder(theme, isJoined),
                          ),
                        )
                      : _buildAvatarPlaceholder(theme, isJoined),
                ),
              ),
              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + role badge
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            coaching.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isJoined) ...[
                          const SizedBox(width: 8),
                          _buildRoleBadge(theme, coaching.myRole!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),

                    // For joined coachings: show owner + members
                    // For my coachings: show members + description
                    if (isJoined) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 13,
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'by ${coaching.ownerName ?? 'Unknown'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '  •  ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${coaching.memberCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 14,
                            color: theme.colorScheme.secondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${coaching.memberCount} members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          if (coaching.description != null &&
                              coaching.description!.isNotEmpty) ...[
                            Text(
                              '  •  ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                coaching.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: isJoined
                    ? _getRoleColor(coaching.myRole).withValues(alpha: 0.4)
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String? role) {
    if (role == 'TEACHER') return Colors.blue;
    if (role == 'STUDENT') return Colors.orange;
    return Colors.grey;
  }

  Widget _buildAvatarPlaceholder(ThemeData theme, bool isJoined) {
    final initials = coaching.name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    final color = isJoined
        ? _getRoleColor(coaching.myRole)
        : theme.colorScheme.primary;

    return Center(
      child: Text(
        initials.isEmpty ? 'C' : initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildRoleBadge(ThemeData theme, String role) {
    final isTeacher = role == 'TEACHER';
    final color = isTeacher ? Colors.blue : Colors.orange;
    final label = isTeacher ? 'Teacher' : 'Student';
    final icon = isTeacher ? Icons.school_rounded : Icons.person_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
