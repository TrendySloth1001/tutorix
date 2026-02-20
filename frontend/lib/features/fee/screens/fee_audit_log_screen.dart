import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

/// Paginated audit trail for fee-related events in a coaching.
class FeeAuditLogScreen extends StatefulWidget {
  final String coachingId;
  const FeeAuditLogScreen({super.key, required this.coachingId});

  @override
  State<FeeAuditLogScreen> createState() => _FeeAuditLogScreenState();
}

class _FeeAuditLogScreenState extends State<FeeAuditLogScreen> {
  final _svc = FeeService();
  final _scrollCtrl = ScrollController();

  List<FeeAuditLogModel> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  static const _limit = 30;

  // Filters
  String? _filterEntityType;
  String? _filterEvent;

  static const _entityTypes = [
    'STRUCTURE',
    'ASSIGNMENT',
    'RECORD',
    'PAYMENT',
    'REFUND',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _logs.length < _total) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }
    try {
      final result = await _svc.listAuditLog(
        widget.coachingId,
        entityType: _filterEntityType,
        event: _filterEvent,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _logs = result['logs'] as List<FeeAuditLogModel>;
        _total = result['total'] as int? ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _page++;
    });
    try {
      final result = await _svc.listAuditLog(
        widget.coachingId,
        entityType: _filterEntityType,
        event: _filterEvent,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _logs.addAll(result['logs'] as List<FeeAuditLogModel>);
        _total = result['total'] as int? ?? 0;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _page--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fee Audit Log',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_alt_rounded,
              color: (_filterEntityType != null || _filterEvent != null)
                  ? AppColors.darkOlive
                  : AppColors.mutedOlive,
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _logs.isEmpty
          ? const _EmptyState()
          : Column(
              children: [
                if (_filterEntityType != null || _filterEvent != null)
                  _ActiveFilterChips(
                    entityType: _filterEntityType,
                    event: _filterEvent,
                    onClear: () {
                      setState(() {
                        _filterEntityType = null;
                        _filterEvent = null;
                      });
                      _load();
                    },
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.darkOlive,
                    onRefresh: _load,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _logs.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _logs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final log = _logs[i];
                        final showDate =
                            i == 0 ||
                            !_sameDay(_logs[i - 1].createdAt, log.createdAt);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDate) _DateDivider(date: log.createdAt),
                            _AuditLogTile(log: log),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Text(
                    'Showing ${_logs.length} of $_total events',
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        selectedEntityType: _filterEntityType,
        selectedEvent: _filterEvent,
        entityTypes: _entityTypes,
        onApply: (et, ev) {
          setState(() {
            _filterEntityType = et;
            _filterEvent = ev;
          });
          _load();
        },
      ),
    );
  }
}

// ── Date divider ─────────────────────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppColors.softGrey.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Text(
            _fmtDate(date),
            style: const TextStyle(
              color: AppColors.mutedOlive,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: AppColors.softGrey.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Single audit log tile ────────────────────────────────────────────────────

class _AuditLogTile extends StatelessWidget {
  final FeeAuditLogModel log;
  const _AuditLogTile({required this.log});

  static const _eventColors = <String, Color>{
    'STRUCTURE_CREATED': Color(0xFF2E7D32),
    'STRUCTURE_REPLACED': Color(0xFFE65100),
    'STRUCTURE_UPDATED': Color(0xFF1565C0),
    'STRUCTURE_DELETED': Color(0xFFC62828),
    'ASSIGNMENT_CREATED': Color(0xFF2E7D32),
    'ASSIGNMENT_REMOVED': Color(0xFFC62828),
    'ASSIGNMENT_PAUSED': Color(0xFF7B1FA2),
    'ASSIGNMENT_UNPAUSED': Color(0xFF2E7D32),
    'PAYMENT_RECORDED': Color(0xFF2E7D32),
    'FEE_WAIVED': Color(0xFF7B1FA2),
    'REFUND_ISSUED': Color(0xFF004D40),
    'INSTALLMENT_SETTINGS_CHANGED': Color(0xFF1565C0),
  };

  @override
  Widget build(BuildContext context) {
    final color = _eventColors[log.event] ?? AppColors.mutedOlive;
    final actorLabel = log.actorType == 'SYSTEM'
        ? 'System'
        : log.actorName ?? log.actorId ?? 'Admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedOlive.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.eventLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Entity type
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGrey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.entityType,
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Time
                Text(
                  _fmtTime(log.createdAt),
                  style: const TextStyle(
                    color: AppColors.mutedOlive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Structure name if available
            if (log.feeStructureName != null) ...[
              Text(
                log.feeStructureName!,
                style: const TextStyle(
                  color: AppColors.darkOlive,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Note
            if (log.note != null && log.note!.isNotEmpty) ...[
              Text(
                log.note!,
                style: const TextStyle(
                  color: AppColors.darkOlive,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
            ],
            // Actor
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: AppColors.mutedOlive,
                ),
                const SizedBox(width: 4),
                Text(
                  actorLabel,
                  style: const TextStyle(
                    color: AppColors.mutedOlive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter sheet ─────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? selectedEntityType;
  final String? selectedEvent;
  final List<String> entityTypes;
  final void Function(String? entityType, String? event) onApply;

  const _FilterSheet({
    required this.selectedEntityType,
    required this.selectedEvent,
    required this.entityTypes,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _entityType;
  String? _event;

  @override
  void initState() {
    super.initState();
    _entityType = widget.selectedEntityType;
    _event = widget.selectedEvent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.softGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Filter Audit Log',
            style: TextStyle(
              color: AppColors.darkOlive,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Entity Type',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.darkOlive,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _entityType == null,
                onTap: () => setState(() => _entityType = null),
              ),
              ...widget.entityTypes.map(
                (et) => _FilterChip(
                  label: et,
                  selected: _entityType == et,
                  onTap: () => setState(
                    () => _entityType = _entityType == et ? null : et,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(null, null);
                  },
                  child: const Text('Clear Filters'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    foregroundColor: AppColors.cream,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(_entityType, _event);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.darkOlive
              : AppColors.softGrey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.cream : AppColors.darkOlive,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Active filters banner ────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  final String? entityType;
  final String? event;
  final VoidCallback onClear;

  const _ActiveFilterChips({
    required this.entityType,
    required this.event,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.darkOlive.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 14,
            color: AppColors.mutedOlive,
          ),
          const SizedBox(width: 6),
          if (entityType != null) _Chip(label: entityType!),
          if (event != null) ...[
            const SizedBox(width: 6),
            _Chip(label: event!),
          ],
          const Spacer(),
          GestureDetector(
            onTap: onClear,
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppColors.darkOlive,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.darkOlive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkOlive,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Empty / Error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: AppColors.mutedOlive,
          ),
          SizedBox(height: 12),
          Text(
            'No audit events yet',
            style: TextStyle(
              color: AppColors.mutedOlive,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Events like creating structures, assigning fees,\nand recording payments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedOlive),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return 'Today';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (d.year == yesterday.year &&
      d.month == yesterday.month &&
      d.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _fmtTime(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
