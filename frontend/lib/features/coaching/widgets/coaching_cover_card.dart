import 'package:flutter/material.dart';
import '../models/coaching_model.dart';

/// Premium full-width coaching card with cover image background.
/// Used for "My Coachings" section - high visual impact.
class CoachingCoverCard extends StatelessWidget {
  final CoachingModel coaching;
  final VoidCallback onTap;
  final bool isOwner;
  final String? role;

  const CoachingCoverCard({
    super.key,
    required this.coaching,
    required this.onTap,
    this.isOwner = true,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasLogo = coaching.logo != null && coaching.logo!.isNotEmpty;
    final hasCover =
        coaching.coverImage != null && coaching.coverImage!.isNotEmpty;
    final hasTagline = coaching.tagline != null && coaching.tagline!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ─── COVER IMAGE BACKGROUND ───
                  if (hasCover)
                    Image.network(
                      coaching.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPlaceholderBackground(colors),
                    )
                  else
                    _buildPlaceholderBackground(colors),

                  // ─── GRADIENT OVERLAY ───
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.75),
                          Colors.black.withValues(alpha: 0.92),
                        ],
                        stops: const [0.0, 0.25, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // ─── CONTENT ───
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Logo - larger size
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: hasLogo
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    coaching.logo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildLogoPlaceholder(theme),
                                  ),
                                )
                              : _buildLogoPlaceholder(theme),
                        ),
                        const SizedBox(width: 14),

                        // Name + Tagline + Stats
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                coaching.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Tagline
                              if (hasTagline) ...[
                                const SizedBox(height: 2),
                                Text(
                                  coaching.tagline!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              const SizedBox(height: 6),

                              // Stats row
                              Row(
                                children: [
                                  _buildStat(
                                    icon: Icons.people_rounded,
                                    value: '${coaching.memberCount}',
                                  ),
                                  const SizedBox(width: 12),
                                  if (coaching.branches.isNotEmpty)
                                    _buildStat(
                                      icon: Icons.location_on_rounded,
                                      value: '${coaching.branches.length}',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Right side: Role badge + Arrow
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Role badge
                            _buildRoleBadge(),

                            // Arrow
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    final displayRole = role ?? coaching.myRole;
    final roleIsOwner = isOwner && displayRole == null;

    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (roleIsOwner) {
      label = 'O';
      bgColor = Colors.amber.shade400;
      textColor = Colors.amber.shade900;
      icon = Icons.star_rounded;
    } else if (displayRole == 'TEACHER') {
      label = 'T';
      bgColor = Colors.blue.shade400;
      textColor = Colors.blue.shade900;
      icon = Icons.school_rounded;
    } else if (displayRole == 'STUDENT') {
      label = 'S';
      bgColor = Colors.orange.shade400;
      textColor = Colors.orange.shade900;
      icon = Icons.person_rounded;
    } else {
      label = 'O';
      bgColor = Colors.amber.shade400;
      textColor = Colors.amber.shade900;
      icon = Icons.star_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBackground(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.7),
            colors.primary.withValues(alpha: 0.9),
            colors.primary,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          size: 60,
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
    );
  }

  Widget _buildLogoPlaceholder(ThemeData theme) {
    final initials = coaching.name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Center(
      child: Text(
        initials.isEmpty ? 'C' : initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _buildStat({required IconData icon, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.75)),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
