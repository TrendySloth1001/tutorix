import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../coaching/models/coaching_model.dart';
import '../../coaching/screens/create_coaching_screen.dart';
import '../../coaching/services/coaching_service.dart';
import '../../coaching/widgets/coaching_card.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final ValueChanged<UserModel>? onUserUpdated;

  const HomeScreen({super.key, required this.user, this.onUserUpdated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CoachingService _coachingService = CoachingService();
  List<CoachingModel> _coachings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoachings();
  }

  Future<void> _loadCoachings() async {
    setState(() => _isLoading = true);
    try {
      _coachings = await _coachingService.getMyCoachings();
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _navigateToCreate() async {
    final result = await Navigator.push<CoachingModel>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCoachingScreen(
          onCoachingCreated: (_, user) => widget.onUserUpdated?.call(user),
        ),
      ),
    );
    if (result != null) _loadCoachings();
  }

  void _navigateToCoaching(CoachingModel coaching) {
    // TODO: implement coaching detail screen
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HomeHeader(user: widget.user),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_coachings.isEmpty)
            SliverFillRemaining(child: _EmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        'My Coachings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    );
                  }
                  final coaching = _coachings[index - 1];
                  return CoachingCard(
                    coaching: coaching,
                    onTap: () => _navigateToCoaching(coaching),
                  );
                }, childCount: _coachings.length + 1),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Coaching'),
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// ── Private sub-widgets ──────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final UserModel user;
  const _HomeHeader({required this.user});

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
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
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
              const SizedBox(width: 16),
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
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
                color: theme.colorScheme.primary,
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
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
            const SizedBox(height: 32),
            Text(
              'No Coachings Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
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
