import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../coaching/models/coaching_model.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';
import 'create_batch_screen.dart';
import 'batch_detail_screen.dart';

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

  bool get _isAdmin =>
      widget.coaching.ownerId == widget.user.id ||
      widget.coaching.myRole == 'ADMIN';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      if (_isAdmin) {
        final status = _filter == 'all' ? null : _filter;
        _batches = await _batchService.listBatches(
          widget.coaching.id,
          status: status,
        );
      } else {
        _batches = await _batchService.getMyBatches(widget.coaching.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load batches: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      const SizedBox(height: 2),
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
                      borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'New',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: ['all', 'active', 'archived'].map((f) {
                  final selected = _filter == f;
                  final label = f[0].toUpperCase() + f.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _filter = f);
                        _loadBatches();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
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
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // ── Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _batches.isEmpty
                ? _EmptyState(isAdmin: _isAdmin, onTap: _openCreateBatch)
                : RefreshIndicator(
                    onRefresh: _loadBatches,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: _batches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            Text(
              isAdmin ? 'No batches yet' : 'No batches assigned',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
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
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Batch'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    const SizedBox(width: 8),
                    _StatusBadge(status: batch.status),
                  ],
                ),

                // ── Subject
                if (batch.subject != null) ...[
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 12),
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
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
    final isActive = status == 'active';
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Archived',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
