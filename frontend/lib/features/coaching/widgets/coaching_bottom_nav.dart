import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Custom bottom navigation for the coaching detail screens.
///
/// Three tabs: Dashboard, Members, Profile — using the same pill-style
/// animation as [CustomBottomNav].
class CoachingBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isAdmin;

  const CoachingBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isAdmin = false,
  });

  List<_NavDef> get _items => [
    const _NavDef(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    if (isAdmin)
      const _NavDef(icon: Icons.people_rounded, label: 'Members')
    else
      const _NavDef(icon: Icons.quiz_rounded, label: 'Assessment'),
    const _NavDef(icon: Icons.group_work_rounded, label: 'Batches'),
    const _NavDef(icon: Icons.school_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.xl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sp12,
            vertical: Spacing.sp12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              return _NavItem(
                icon: item.icon,
                label: item.label,
                isSelected: selectedIndex == i,
                onTap: () => onItemSelected(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavDef {
  final IconData icon;
  final String label;
  const _NavDef({required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp16,
          vertical: Spacing.sp10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary.withValues(alpha: 0.5),
            ),
            if (isSelected) ...[
              const SizedBox(width: Spacing.sp8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
