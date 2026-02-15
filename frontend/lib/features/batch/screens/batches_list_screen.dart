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
  String _filter = 'all'; // all, active, archived

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
        _batches =
            await _batchService.listBatches(widget.coaching.id, status: status);
      } else {
        _batches = await _batchService.getMyBatches(widget.coaching.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batches: $e')),
        );
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
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_batches.length} batch${_batches.length == 1 ? '' : 'es'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  FilledButton.icon(
                    onPressed: _openCreateBatch,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ── Filter chips (admin only)
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ['all', 'active', 'archived'].map((f) {
                  final selected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _filter = f);
                        _loadBatches();
                      },
                      selectedColor:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _BatchCard(
                            batch: _batches[i],
                            onTap: () => _openBatchDetail(_batches[i]),
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
            Icon(Icons.group_work_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              isAdmin ? 'No batches yet' : 'No batches assigned',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'Create your first batch to get started'
                  : 'You haven\'t been assigned to any batch yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Batch'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Batch Card ───────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  final VoidCallback onTap;
  const _BatchCard({required this.batch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.group_work_rounded,
                        size: 20, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          batch.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (batch.subject != null)
                          Text(
                            batch.subject!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: batch.status),
                ],
              ),
              const SizedBox(height: 12),
              // ── Schedule
              if (batch.days.isNotEmpty ||
                  batch.startTime != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Text(
                      batch.scheduleText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // ── Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.people_outline_rounded,
                    label: '${batch.memberCount}',
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.note_outlined,
                    label: '${batch.noteCount}',
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    icon: Icons.campaign_outlined,
                    label: '${batch.noticeCount}',
                    theme: theme,
                  ),
                  const Spacer(),
                  // Teacher avatar
                  if (batch.teacher != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: batch.teacher!.picture != null
                              ? NetworkImage(batch.teacher!.picture!)
                              : null,
                          child: batch.teacher!.picture == null
                              ? Text(
                                  (batch.teacher!.name ?? 'T')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 10),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          batch.teacher!.name ?? 'Teacher',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Active' : 'Archived',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  const _StatChip(
      {required this.icon, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
