import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/coaching_service.dart';
import 'create_coaching_screen.dart';
import 'coaching_dashboard_screen.dart';

class CoachingSelectorScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final Function(UserModel) onUserUpdated;

  const CoachingSelectorScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onUserUpdated,
  });

  @override
  State<CoachingSelectorScreen> createState() => _CoachingSelectorScreenState();
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
      final coachings = await _coachingService.getMyCoachings();
      setState(() {
        _coachings = coachings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load coachings: $e')));
      }
    }
  }

  void _navigateToCreateCoaching() async {
    final result = await Navigator.push<CoachingModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCoachingScreen(
          onCoachingCreated: (coaching, updatedUser) {
            widget.onUserUpdated(updatedUser);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Coachings'),
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: widget.user.picture != null
                  ? NetworkImage(widget.user.picture!)
                  : null,
              child: widget.user.picture == null
                  ? Text(widget.user.name?.substring(0, 1).toUpperCase() ?? 'U')
                  : null,
            ),
            onPressed: () => _showProfileMenu(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateCoaching,
        icon: const Icon(Icons.add),
        label: const Text('Create Coaching'),
      ),
    );
  }

  Widget _buildContent() {
    if (_coachings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCoachings,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _coachings.length,
        itemBuilder: (context, index) {
          final coaching = _coachings[index];
          return _buildCoachingCard(coaching);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 100,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Tutorix!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Start your journey by creating your first coaching institute.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToCreateCoaching,
              icon: const Icon(Icons.add),
              label: const Text('Create Your Coaching'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingCard(CoachingModel coaching) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToCoaching(coaching),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: coaching.logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(coaching.logo!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.school,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coaching.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${coaching.slug}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    if (coaching.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        coaching.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: widget.user.picture != null
                    ? NetworkImage(widget.user.picture!)
                    : null,
                child: widget.user.picture == null
                    ? Text(
                        widget.user.name?.substring(0, 1).toUpperCase() ?? 'U',
                      )
                    : null,
              ),
              title: Text(widget.user.name ?? 'User'),
              subtitle: Text(widget.user.email),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
