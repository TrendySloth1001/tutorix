import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/login_session.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../services/user_service.dart';

class SecuritySessionsScreen extends StatefulWidget {
  const SecuritySessionsScreen({super.key});

  @override
  State<SecuritySessionsScreen> createState() => _SecuritySessionsScreenState();
}

class _SecuritySessionsScreenState extends State<SecuritySessionsScreen> {
  final UserService _userService = UserService();
  List<LoginSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      _sessions = await _userService.getSessions();
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to load sessions');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: Text(
          'Security History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          color: theme.colorScheme.onSurface,
        ),
      ),
      body: _isLoading
          ? const SessionsShimmer()
          : _sessions.isEmpty
          ? _EmptyState()
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _sessions.length,
                itemBuilder: (_, i) => _SessionTile(session: _sessions[i]),
              ),
            ),
    );
  }
}

// ── Extracted sub-widgets ────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 80,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text('No session history found', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final LoginSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceInfo = _parseDevice(session.userAgent);
    final dateStr = DateFormat(
      'MMM dd, yyyy',
    ).format(session.createdAt.toLocal());
    final timeStr = DateFormat('hh:mm a').format(session.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _deviceIcon(session.userAgent),
                    color: theme.colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    deviceInfo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                children: [
                  const TextSpan(text: 'You logged in from '),
                  TextSpan(
                    text: deviceInfo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: ' at this IP '),
                  TextSpan(
                    text: session.ip ?? 'Unknown IP',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const TextSpan(text: ' on '),
                  TextSpan(
                    text: dateStr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' at '),
                  TextSpan(
                    text: timeStr,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  static String _parseDevice(String? ua) {
    if (ua == null) return 'Unknown Device';
    if (ua.contains('Android') || ua.contains('iOS')) {
      if (ua.startsWith('Dart/') || !ua.contains('Mozilla')) {
        final cleaned = ua
            .replaceAll('Dart/3.10 ', '')
            .replaceAll(' (dart:io)', '')
            .trim();
        return cleaned.isEmpty ? 'Android Device' : cleaned;
      }
      final match = RegExp(r';\s*([^;)]+)').firstMatch(ua);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
      return ua.contains('Android') ? 'Android Device' : 'iOS Device';
    }
    if (ua.contains('Macintosh')) return 'Mac';
    if (ua.contains('Windows')) return 'Windows PC';
    if (ua.contains('Postman')) return 'Postman / API Client';
    return 'Unknown Device';
  }

  static IconData _deviceIcon(String? ua) {
    if (ua == null) return Icons.devices_rounded;
    if (ua.contains('Android')) return Icons.phone_android_rounded;
    if (ua.contains('iPhone') || ua.contains('iPad')) {
      return Icons.phone_iphone_rounded;
    }
    if (ua.contains('Macintosh')) return Icons.laptop_mac_rounded;
    if (ua.contains('Windows')) return Icons.laptop_windows_rounded;
    return Icons.devices_rounded;
  }
}
