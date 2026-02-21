import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/cache_manager.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../profile/services/user_service.dart';

/// App-wide settings screen.
///
/// Includes the privacy toggles (moved from Profile), the offline-cache
/// toggle, and cache / data management actions.
class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const SettingsScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cache = CacheManager.instance;
  final _userService = UserService();

  bool _offlineCacheEnabled = false;
  bool _loadingCacheSetting = true;

  // Cache stats
  int _cacheEntries = 0;
  String _cacheSize = '0 KB';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _cache.isEnabled;
    final entries = await _cache.entryCount;
    final bytes = await _cache.sizeInBytes;
    if (mounted) {
      setState(() {
        _offlineCacheEnabled = enabled;
        _cacheEntries = entries;
        _cacheSize = _formatBytes(bytes);
        _loadingCacheSetting = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Privacy ────────────────────────────────────────────────────────

  Future<void> _updatePrivacy({
    bool? showEmailInSearch,
    bool? showPhoneInSearch,
    bool? showWardsInSearch,
  }) async {
    try {
      final updated = await _userService.updatePrivacy(
        showEmailInSearch: showEmailInSearch,
        showPhoneInSearch: showPhoneInSearch,
        showWardsInSearch: showWardsInSearch,
      );
      if (updated != null && mounted) {
        widget.onUserUpdated?.call(updated);
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to update privacy');
      }
    }
  }

  // ── Cache actions ──────────────────────────────────────────────────

  Future<void> _toggleOfflineCache(bool value) async {
    setState(() => _offlineCacheEnabled = value);
    await _cache.setEnabled(value);
    if (mounted) {
      AppAlert.success(
        context,
        value ? 'Offline cache enabled' : 'Offline cache disabled',
      );
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Clear cache?',
      message:
          'This will remove all cached data ($_cacheEntries entries, $_cacheSize). '
          'You\'ll need an internet connection to reload data.',
    );
    if (confirmed != true) return;

    await _cache.clearAll();
    await _loadSettings();
    if (mounted) AppAlert.success(context, 'Cache cleared');
  }

  Future<void> _deleteAllData() async {
    final confirmed = await AppAlert.confirm(
      context,
      title: 'Delete all local data?',
      message:
          'This will delete the entire local database including settings. '
          'The offline-cache toggle will be reset to off.',
    );
    if (confirmed != true) return;

    await _cache.deleteAll();
    setState(() {
      _offlineCacheEnabled = false;
      _cacheEntries = 0;
      _cacheSize = '0 B';
    });
    if (mounted) AppAlert.success(context, 'All local data deleted');
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          // ─── Appearance ───────────────────────────────────────
          _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
          const SizedBox(height: 12),
          _ThemeSelector(),

          const SizedBox(height: 32),

          // ─── Search Privacy ───────────────────────────────────
          _SectionHeader(title: 'Search Privacy', icon: Icons.shield_outlined),
          const SizedBox(height: 4),
          Text(
            'Control what others see when they search for you to send an invite',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _PrivacyToggle(
            icon: Icons.email_outlined,
            title: 'Show email',
            value: user.showEmailInSearch,
            onChanged: (v) => _updatePrivacy(showEmailInSearch: v),
          ),
          _PrivacyToggle(
            icon: Icons.phone_outlined,
            title: 'Show phone number',
            value: user.showPhoneInSearch,
            onChanged: (v) => _updatePrivacy(showPhoneInSearch: v),
          ),
          _PrivacyToggle(
            icon: Icons.child_care_rounded,
            title: 'Show student profiles',
            value: user.showWardsInSearch,
            onChanged: (v) => _updatePrivacy(showWardsInSearch: v),
          ),

          const SizedBox(height: 32),

          // ─── Offline Storage ──────────────────────────────────
          _SectionHeader(
            title: 'Offline Storage',
            icon: Icons.download_for_offline_outlined,
          ),
          const SizedBox(height: 4),
          Text(
            'Cache data locally so screens load instantly. '
            'Only new or updated data is fetched from the server.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _ToggleTile(
            icon: Icons.cached_rounded,
            title: 'Enable offline cache',
            subtitle: _loadingCacheSetting
                ? 'Loading…'
                : _offlineCacheEnabled
                ? '$_cacheEntries entries · $_cacheSize'
                : 'Disabled — data loaded from server every time',
            value: _offlineCacheEnabled,
            onChanged: _toggleOfflineCache,
          ),

          const SizedBox(height: 32),

          // ─── Data Management ──────────────────────────────────
          _SectionHeader(
            title: 'Data Management',
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Clear cache',
            subtitle: '$_cacheEntries cached entries · $_cacheSize',
            onTap: _clearCache,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete all local data',
            subtitle: 'Removes database, settings, and cache',
            isDestructive: true,
            onTap: _deleteAllData,
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Private helper widgets ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacyToggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.secondary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isDestructive ? AppColors.error : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.15)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: accent.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme selector ─────────────────────────────────────────────────────

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = context.watch<ThemeProvider>().mode;

    const modes = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];

    return Row(
      children: modes.map((entry) {
        final (mode, icon, label) = entry;
        final selected = current == mode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => context.read<ThemeProvider>().setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.secondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.15),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
