import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../coaching/models/coaching_model.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';
import 'create_batch_screen.dart';
import 'batch_detail_screen.dart';
import '../../../core/theme/design_tokens.dart';

/// Batches list — the 4th tab in the coaching shell.
/// Admins see all batches; teachers/students see only their assigned batches.
class BatchesListScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;

  const BatchesListScreen({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  State<BatchesListScreen> createState() => _BatchesListScreenState();
}

class _BatchesListScreenState extends State<BatchesListScreen> {
  final BatchService _batchService = BatchService();

  List<BatchModel> _batches = [];
  bool _isLoading = true;
  String _filter = 'all';
  StreamSubscription? _sub;

  bool get _isAdmin =>
      widget.coaching.ownerId == widget.user.id ||
      widget.coaching.myRole == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _loadBatches() {
    setState(() => _isLoading = true);
    _sub?.cancel();

    final Stream<List<BatchModel>> stream;
    if (_isAdmin) {
      final status = _filter == 'all' ? null : _filter;
      stream = _batchService.watchBatches(widget.coaching.id, status: status);
    } else {
      stream = _batchService.watchMyBatches(widget.coaching.id);
    }

    _sub = stream.listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _batches = list;
          _isLoading = false;
        });
      },
      onError: (e) {
        if (mounted) {
          AppAlert.error(context, e, fallback: 'Failed to load batches');
          setState(() => _isLoading = false);
        }
      },
    );
  }

  void _openCreateBatch() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBatchScreen(coaching: widget.coaching),
      ),
    );
    if (created == true) _loadBatches();
  }

  void _openBatchDetail(BatchModel batch) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchDetailScreen(
          coaching: widget.coaching,
          batchId: batch.id,
          user: widget.user,
        ),
      ),
    );
    if (changed == true) _loadBatches();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),
          // ── Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batches',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: Spacing.sp2),
                      Text(
                        '${_batches.length} batch${_batches.length == 1 ? '' : 'es'} · ${widget.coaching.name}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _openCreateBatch,
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sp16,
                            vertical: Spacing.sp10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: Spacing.sp6),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: FontSize.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Filter pills (admin only)
          if (_isAdmin) ...[
            const SizedBox(height: Spacing.sp16),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sp20),
                children: ['all', 'active', 'archived'].map((f) {
                  final selected = _filter == f;
                  final label = f[0].toUpperCase() + f.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(right: Spacing.sp8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _filter = f);
                        _loadBatches();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sp20,
                          vertical: Spacing.sp8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: selected
                              ? null
                              : Border.all(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.55,
                                  ),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: FontSize.body,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: Spacing.sp16),
          // ── Content
          Expanded(
            child: _isLoading
                ? const BatchListShimmer()
                : _batches.isEmpty
                ? _EmptyState(isAdmin: _isAdmin, onTap: _openCreateBatch)
                : RefreshIndicator(
                    onRefresh: () async {
                      _loadBatches();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.sp20,
                        0,
                        Spacing.sp20,
                        Spacing.sp100,
                      ),
                      itemCount: _batches.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: Spacing.sp14),
                      itemBuilder: (context, i) => _BatchCard(
                        batch: _batches[i],
                        onTap: () => _openBatchDetail(_batches[i]),
                        index: i,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onTap;
  const _EmptyState({required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sp40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sp24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_work_outlined,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: Spacing.sp24),
            Text(
              isAdmin ? 'No batches yet' : 'No batches assigned',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: Spacing.sp8),
            Text(
              isAdmin
                  ? 'Create your first batch to organise\nstudents and start teaching'
                  : 'You haven\'t been assigned to any batch yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                height: 1.5,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: Spacing.sp28),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Batch'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp24,
                    vertical: Spacing.sp14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Batch Card — Clean & Themed ──────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onTap;
  final int index;
  const _BatchCard({
    required this.batch,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sp16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Name + Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batch.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.sp8),
                    _StatusBadge(status: batch.status),
                  ],
                ),

                // ── Subject
                if (batch.subject != null) ...[
                  const SizedBox(height: Spacing.sp4),
                  Text(
                    batch.subject!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                // ── Schedule
                if (batch.days.isNotEmpty || batch.startTime != null) ...[
                  const SizedBox(height: Spacing.sp12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      const SizedBox(width: Spacing.sp6),
                      Text(
                        batch.scheduleText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Teacher
                if (batch.teacher != null) ...[
                  const SizedBox(height: Spacing.sp12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundImage: batch.teacher!.picture != null
                            ? NetworkImage(batch.teacher!.picture!)
                            : null,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: batch.teacher!.picture == null
                            ? Text(
                                (batch.teacher!.name ?? 'T')[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: FontSize.nano,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Spacing.sp6),
                      Text(
                        batch.teacher!.name ?? 'Teacher',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status Badge ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = status == 'active';
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp10,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Spacing.sp6),
          Text(
            isActive ? 'Active' : 'Archived',
            style: TextStyle(
              fontSize: FontSize.micro,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
