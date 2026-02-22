import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/design_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Coaching detail bottom navigation bar.
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
    const _NavDef(
      icon: PhosphorIconsRegular.squaresFour,
      activeIcon: PhosphorIconsFill.squaresFour,
      label: 'Dashboard',
    ),
    if (isAdmin)
      const _NavDef(
        icon: PhosphorIconsRegular.users,
        activeIcon: PhosphorIconsFill.users,
        label: 'Members',
      )
    else
      const _NavDef(
        icon: PhosphorIconsRegular.clipboardText,
        activeIcon: PhosphorIconsFill.clipboardText,
        label: 'Assessment',
      ),
    const _NavDef(
      icon: PhosphorIconsRegular.usersThree,
      activeIcon: PhosphorIconsFill.usersThree,
      label: 'Batches',
    ),
    const _NavDef(
      icon: PhosphorIconsRegular.graduationCap,
      activeIcon: PhosphorIconsFill.graduationCap,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sp8,
            vertical: Spacing.sp8,
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Expanded(
                child: _NavItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isSelected: selectedIndex == i,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onItemSelected(i);
                  },
                ),
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
  final IconData activeIcon;
  final String label;
  const _NavDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sp20,
              vertical: Spacing.sp6,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.full),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              size: Spacing.sp24,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.sp4),
          Text(
            label,
            style: TextStyle(
              fontSize: FontSize.micro,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? activeColor : inactiveColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
