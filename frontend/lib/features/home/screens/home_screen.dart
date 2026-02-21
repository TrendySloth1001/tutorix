import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/services/error_logger_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../coaching/models/coaching_model.dart';
import '../../coaching/screens/coaching_onboarding_screen.dart';
import '../../coaching/screens/coaching_shell.dart';
import '../../coaching/services/coaching_service.dart';
import '../../coaching/widgets/coaching_cover_card.dart';
import '../../notifications/screens/personal_notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const HomeScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CoachingService _coachingService = CoachingService();
  final NotificationService _notificationService = NotificationService();
  List<CoachingModel> _myCoachings = [];
  List<CoachingModel> _joinedCoachings = [];
  bool _isLoading = true;
  int _unreadNotifications = 0;

  StreamSubscription? _mySub;
  StreamSubscription? _joinedSub;
  StreamSubscription? _notifSub;

  @override
  void initState() {
    super.initState();
    _loadCoachings();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _mySub?.cancel();
    _joinedSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  void _loadNotificationCount() {
    _notifSub?.cancel();
    _notifSub = _notificationService
        .watchUserNotifications(limit: 1)
        .listen(
          (result) {
            if (!mounted) return;
            final pendingInvites = context
                .read<AuthController>()
                .pendingInvitations
                .length;
            setState(() {
              _unreadNotifications =
                  (result['unreadCount'] ?? 0) + pendingInvites;
            });
          },
          onError: (e) {
            ErrorLoggerService.instance.warn(
              'Notification count stream error',
              category: LogCategory.api,
              error: e.toString(),
            );
          },
        );
  }

  void _loadCoachings() {
    setState(() => _isLoading = true);
    bool gotMy = false, gotJoined = false;

    _mySub?.cancel();
    _mySub = _coachingService.watchMyCoachings().listen(
      (list) {
        if (!mounted) return;
        gotMy = true;
        setState(() {
          _myCoachings = list;
          if (gotJoined) _isLoading = false;
        });
      },
      onError: (e) {
        gotMy = true;
        if (mounted) {
          AppAlert.error(context, e, fallback: 'Failed to load coachings');
          if (gotJoined) setState(() => _isLoading = false);
        }
      },
    );

    _joinedSub?.cancel();
    _joinedSub = _coachingService.watchJoinedCoachings().listen(
      (list) {
        if (!mounted) return;
        gotJoined = true;
        setState(() {
          _joinedCoachings = list;
          if (gotMy) _isLoading = false;
        });
      },
      onError: (e) {
        gotJoined = true;
        if (mounted) {
          if (gotMy) setState(() => _isLoading = false);
        }
      },
    );
  }

  void _navigateToCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingOnboardingScreen(
          onComplete: () {
            Navigator.pop(context);
            _loadCoachings();
          },
        ),
      ),
    );
  }

  void _navigateToCoaching(CoachingModel coaching) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingShell(
          coaching: coaching,
          user: widget.user,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  void _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalNotificationsScreen()),
    );
    // Refresh notification count when returning
    _loadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _myCoachings.isNotEmpty || _joinedCoachings.isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _loadCoachings();
          _loadNotificationCount();
          // Give streams a moment to emit fresh data.
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HomeHeader(
              user: widget.user,
              unreadCount: _unreadNotifications,
              onNotificationTap: _navigateToNotifications,
              onCreateCoaching: !widget.user.isWard ? _navigateToCreate : null,
            ),
            if (_isLoading)
              const SliverFillRemaining(child: HomeShimmer())
            else if (!hasAny)
              SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: Spacing.sp8,
                    bottom: Spacing.sp100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // My Coachings section
                      if (_myCoachings.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'My Coachings',
                          count: _myCoachings.length,
                          icon: Icons.school_rounded,
                        ),
                        const SizedBox(height: Spacing.sp4),
                        for (int i = 0; i < _myCoachings.length; i++) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i < _myCoachings.length - 1
                                  ? Spacing.sp12
                                  : 0,
                            ),
                            child: CoachingCoverCard(
                              coaching: _myCoachings[i],
                              onTap: () => _navigateToCoaching(_myCoachings[i]),
                            ),
                          ),
                        ],
                      ],

                      // Joined section
                      if (_joinedCoachings.isNotEmpty) ...[
                        const SizedBox(height: Spacing.sp24),
                        _SectionHeader(
                          title: 'Joined',
                          count: _joinedCoachings.length,
                          icon: Icons.group_rounded,
                        ),
                        for (int i = 0; i < _joinedCoachings.length; i++) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i < _joinedCoachings.length - 1 ? 12 : 0,
                            ),
                            child: CoachingCoverCard(
                              coaching: _joinedCoachings[i],
                              onTap: () =>
                                  _navigateToCoaching(_joinedCoachings[i]),
                              isOwner: false,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final UserModel user;
  final int unreadCount;
  final VoidCallback onNotificationTap;
  final VoidCallback? onCreateCoaching;

  const _HomeHeader({
    required this.user,
    required this.unreadCount,
    required this.onNotificationTap,
    this.onCreateCoaching,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'GOOD MORNING';
    if (h < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(Spacing.sp24, 60, Spacing.sp24, 0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.1,
                ),
                backgroundImage: user.picture != null
                    ? NetworkImage(user.picture!)
                    : null,
                child: user.picture == null
                    ? Icon(
                        Icons.person_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: Spacing.sp16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _greeting,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.6,
                        ),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      user.name?.split(' ').first ?? 'User',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCreateCoaching != null)
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: onCreateCoaching,
                  tooltip: 'Create Coaching',
                ),
              const SizedBox(width: Spacing.sp4),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: onNotificationTap,
                    color: theme.colorScheme.primary,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: Spacing.sp8,
                      top: Spacing.sp8,
                      child: Container(
                        padding: const EdgeInsets.all(Spacing.sp4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: FontSize.nano,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sp32),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: Spacing.sp32),
            Text(
              'No Coachings Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            Text(
              'Launch your first coaching institute and start managing your classes today.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp20,
        Spacing.sp16,
        Spacing.sp20,
        Spacing.sp8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: Spacing.sp8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: Spacing.sp8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sp8,
              vertical: Spacing.sp2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
