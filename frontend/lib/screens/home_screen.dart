import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/coaching_service.dart';
import '../widgets/coaching_card.dart';
import 'create_coaching_screen.dart';
import 'coaching_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final Function(UserModel)? onUserUpdated;

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
      final coachings = await _coachingService.getMyCoachings();
      setState(() {
        _coachings = coachings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToCreateCoaching() async {
    final result = await Navigator.push<CoachingModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCoachingScreen(
          onCoachingCreated: (coaching, updatedUser) {
            widget.onUserUpdated?.call(updatedUser);
          },
        ),
      ),
    );

    if (result != null) {
      _loadCoachings();
    }
  }

  void _navigateToCoaching(CoachingModel coaching) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CoachingDashboardScreen(coaching: coaching, user: widget.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Simple Header
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Tutorix Home',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: -1,
                ),
              ),
              centerTitle: true,
              titlePadding: const EdgeInsets.only(bottom: 16),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_coachings.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Text(
                        'My Coachings',
                        style: theme.textTheme.titleLarge?.copyWith(
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
        onPressed: _navigateToCreateCoaching,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Coaching'),
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildEmptyState() {
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
