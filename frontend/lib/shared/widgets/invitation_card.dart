import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/constants/api_constants.dart';

class InvitationCard extends StatelessWidget {
  final Map<String, dynamic> invitation;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool isResponding;

  const InvitationCard({
    super.key,
    required this.invitation,
    this.onAccept,
    this.onDecline,
    this.isResponding = false,
  });

  String? _getFullUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiConstants.baseUrl}/$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coaching = invitation['coaching'] as Map<String, dynamic>?;
    final invitedBy = invitation['invitedBy'] as Map<String, dynamic>?;
    final ward = invitation['ward'] as Map<String, dynamic>?;
    final role = invitation['role'] as String? ?? 'STUDENT';
    final message = invitation['message'] as String?;

    final coverImage = _getFullUrl(coaching?['coverImage'] as String?);
    final logo = _getFullUrl(coaching?['logo'] as String?);
    final coachingName = coaching?['name'] ?? 'A Coaching';
    final inviterName = invitedBy?['name'] ?? 'Someone';

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sp16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cover Image Area with Overlapping Logo & Top-Right Role Tag
          SizedBox(
            height: 140,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover Image
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 120,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.xl),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        coverImage != null
                            ? Image.network(
                                coverImage,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _buildPlaceholderPattern(theme),
                              )
                            : _buildPlaceholderPattern(theme),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.0),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Role Chip (Moved to Top Right)
                Positioned(
                  top: Spacing.sp12,
                  right: Spacing.sp12,
                  child: _buildRoleChip(role, theme, isOverlay: true),
                ),

                // Logo Positioned to overlap bottom-left
                Positioned(
                  left: Spacing.sp20,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(Spacing.sp4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      backgroundImage: logo != null ? NetworkImage(logo) : null,
                      child: logo == null
                          ? Icon(
                              Icons.school_rounded,
                              color: theme.colorScheme.primary,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Content Body
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp20,
              0,
              Spacing.sp20,
              Spacing.sp20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Name + Inviter (Role moved to image)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: Spacing.sp80), // Space for logo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            coachingName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: FontSize.title,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: Spacing.sp4),
                          Text(
                            'Invited by $inviterName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: Spacing.sp16),

                // Message (if any)
                if (message != null && message.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.sp12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      '"$message"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sp16),
                ],

                // Ward Info (if any)
                if (ward != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.child_care_rounded,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: Spacing.sp8),
                      Text(
                        'For your child: ',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        ward['name'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sp20),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isResponding ? null : onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error),
                          padding: const EdgeInsets.symmetric(
                            vertical: Spacing.sp12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sp12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isResponding ? null : onAccept,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            vertical: Spacing.sp12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        child: isResponding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPattern(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.school_rounded,
              size: 140,
              color: theme.colorScheme.surface.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Icon(
              Icons.image_not_supported_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(
    String role,
    ThemeData theme, {
    bool isOverlay = false,
  }) {
    Color color;
    switch (role) {
      case 'TEACHER':
        color = Colors.blue;
        break;
      case 'PARENT':
        color = Colors.teal;
        break;
      default:
        color = theme.colorScheme.secondary.withValues(
          alpha: 0.5,
        ); // Amber darker
    }

    // If overlay, make it look better on dark/image background
    final bgColor = isOverlay
        ? theme.colorScheme.surface.withValues(alpha: 0.9)
        : color.withValues(alpha: 0.15);
    final textColor = isOverlay ? color : color;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp12,
        vertical: Spacing.sp6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: isOverlay
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        role,
        style: TextStyle(
          color: textColor,
          fontSize: FontSize.nano,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
