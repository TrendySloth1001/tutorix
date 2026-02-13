import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
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
      final sessions = await _userService.getSessions();
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load sessions: $e')));
      }
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
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  return _buildSessionTile(session);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
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

  Widget _buildSessionTile(LoginSession session) {
    final theme = Theme.of(context);

    // Enhanced device recognition
    String deviceInfo = 'Unknown Device';
    if (session.userAgent != null) {
      final ua = session.userAgent!;

      // If it's our custom format (e.g., "realme RMX5003 (Android 15)")
      if (ua.contains('Android') || ua.contains('iOS')) {
        if (ua.startsWith('Dart/') || !ua.contains('Mozilla')) {
          // It's our simplified format, show it directly after cleaning Dart prefix
          deviceInfo = ua
              .replaceAll('Dart/3.10 ', '')
              .replaceAll(' (dart:io)', '')
              .trim();
          if (deviceInfo.isEmpty || deviceInfo == '(dart:io)')
            deviceInfo = 'Android Device';
        } else {
          // Standard Browser User-Agent parsing
          final modelMatch = RegExp(r';\s*([^;)]+)').firstMatch(ua);
          if (modelMatch != null && modelMatch.group(1) != null) {
            deviceInfo = modelMatch.group(1)!.trim();
          } else {
            deviceInfo = ua.contains('Android')
                ? 'Android Device'
                : 'iOS Device';
          }
        }
      } else if (ua.contains('Macintosh')) {
        deviceInfo = 'Mac';
      } else if (ua.contains('Windows')) {
        deviceInfo = 'Windows PC';
      } else if (ua.contains('Postman')) {
        deviceInfo = 'Postman / API Client';
      }
    }

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
                    _getDeviceIcon(session.userAgent),
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
                    text: session.ip ?? "Unknown IP",
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

  IconData _getDeviceIcon(String? userAgent) {
    if (userAgent == null) return Icons.devices_rounded;
    if (userAgent.contains('Android')) return Icons.phone_android_rounded;
    if (userAgent.contains('iPhone') || userAgent.contains('iPad'))
      return Icons.phone_iphone_rounded;
    if (userAgent.contains('Macintosh')) return Icons.laptop_mac_rounded;
    if (userAgent.contains('Windows')) return Icons.laptop_windows_rounded;
    return Icons.devices_rounded;
  }
}
