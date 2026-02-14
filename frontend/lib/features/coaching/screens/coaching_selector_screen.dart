import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../profile/screens/profile_screen.dart';
import '../models/coaching_model.dart';
import '../services/coaching_service.dart';
import '../widgets/coaching_card.dart';
import 'coaching_dashboard_screen.dart';
import 'create_coaching_screen.dart';

class CoachingSelectorScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final ValueChanged<UserModel> onUserUpdated;

  const CoachingSelectorScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  @override
  State<CoachingSelectorScreen> createState() =>
      _CoachingSelectorScreenState();
}

class _CoachingSelectorScreenState extends State<CoachingSelectorScreen> {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load coachings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCreate() async {
    final result = await Navigator.push<CoachingModel>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCoachingScreen(
          onCoachingCreated: (_, updatedUser) =>
              widget.onUserUpdated(updatedUser),
        ),
      ),
    );
    if (result != null) _loadCoachings();
  }

  void _navigateToCoaching(CoachingModel coaching) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoachingDashboardScreen(
          coaching: coaching,
          user: widget.user,
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: widget.user,
          onLogout: widget.onLogout,
          onUserUpdated: widget.onUserUpdated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Tutorix',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: -1,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _navigateToProfile,
            icon: Hero(
              tag: 'user_avatar',
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary
                        .withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.tertiary
                      .withValues(alpha: 0.2),
                  backgroundImage: widget.user.picture != null
                      ? NetworkImage(widget.user.picture!)
                      : null,
                  child: widget.user.picture == null
                      ? Text(
                          widget.user.name
                                  ?.substring(0, 1)
                                  .toUpperCase() ??
                              'U',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coachings.isEmpty
              ? _EmptyState(onGetStarted: _navigateToCreate)
              : RefreshIndicator(
                  onRefresh: _loadCoachings,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _coachings.length,
                    itemBuilder: (_, i) => CoachingCard(
                      coaching: _coachings[i],
                      onTap: () =>
                          _navigateToCoaching(_coachings[i]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Launch Institute'),
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _EmptyState({required this.onGetStarted});

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
                color: theme.colorScheme.tertiary
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_outlined,
                  size: 80,
                  color: theme.colorScheme.primary
                      .withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            Text('No Institutes Yet',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Create your first coaching institute to start managing your academic programs.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.secondary
                    .withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: onGetStarted,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Get Started Now'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
