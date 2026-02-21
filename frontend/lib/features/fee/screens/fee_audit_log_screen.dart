import 'package:flutter/material.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fee Audit Log',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_alt_rounded,
              color: (_filterEntityType != null || _filterEvent != null)
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
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
                    color: theme.colorScheme.primary,
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
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _fmtDate(date),
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
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

  static Map<String, Color> _eventColorsFor(ColorScheme cs) => {
    'STRUCTURE_CREATED': cs.primary,
    'STRUCTURE_REPLACED': cs.secondary,
    'STRUCTURE_UPDATED': cs.secondary,
    'STRUCTURE_DELETED': cs.error,
    'ASSIGNMENT_CREATED': cs.primary,
    'ASSIGNMENT_UPDATED': cs.secondary,
    'ASSIGNMENT_REMOVED': cs.error,
    'ASSIGNMENT_PAUSED': cs.secondary,
    'ASSIGNMENT_UNPAUSED': cs.primary,
    'PAYMENT_RECORDED': cs.primary,
    'FEE_WAIVED': cs.secondary,
    'REFUND_ISSUED': cs.secondary,
    'INSTALLMENT_SETTINGS_CHANGED': cs.secondary,
  };

  // Human-readable labels for common JSON keys stored in before/after/meta
  static const _fieldLabels = <String, String>{
    'name': 'Name',
    'amount': 'Amount',
    'cycle': 'Billing Cycle',
    'lateFinePerDay': 'Late Fine/Day',
    'taxType': 'Tax Type',
    'gstRate': 'GST Rate',
    'sacCode': 'SAC Code',
    'hsnCode': 'HSN Code',
    'cessRate': 'Cess Rate',
    'gstSupplyType': 'GST Supply Type',
    'description': 'Description',
    'isCurrent': 'Is Current',
    'isActive': 'Active',
    'allowInstallments': 'Allow Installments',
    'installmentCount': 'Installment Count',
    'installmentAmounts': 'Installment Amounts',
    'memberId': 'Member',
    'memberName': 'Member Name',
    'feeStructureId': 'Fee Structure',
    'feeStructureName': 'Structure Name',
    'discountAmount': 'Discount Amount',
    'discountReason': 'Discount Reason',
    'scholarshipTag': 'Scholarship Tag',
    'scholarshipAmount': 'Scholarship Amount',
    'customAmount': 'Custom Amount',
    'startDate': 'Start Date',
    'endDate': 'End Date',
    'pausedReason': 'Pause Reason',
    'paymentAmount': 'Payment Amount',
    'paymentMode': 'Payment Mode',
    'transactionRef': 'Transaction Ref',
    'notes': 'Notes',
    'paidAt': 'Paid At',
    'receiptNo': 'Receipt No.',
    'waivedAmount': 'Waived Amount',
    'waivedReason': 'Waive Reason',
    'refundAmount': 'Refund Amount',
    'refundMode': 'Refund Mode',
    'reason': 'Reason',
    'refundedAt': 'Refunded At',
    'memberCount': 'Members Affected',
    'previousStructureId': 'Previous Structure',
    'newStructureId': 'New Structure',
    'finalAmount': 'Final Amount',
    'paidAmount': 'Paid Amount',
    'status': 'Status',
    'dueDate': 'Due Date',
    'title': 'Fee Title',
  };

  // Keys that represent currency amounts — formatted with ₹ prefix
  static const _currencyKeys = {
    'amount',
    'discountAmount',
    'customAmount',
    'scholarshipAmount',
    'paymentAmount',
    'waivedAmount',
    'refundAmount',
    'finalAmount',
    'paidAmount',
    'lateFinePerDay',
  };

  // Keys that represent rate/percentage values
  static const _percentKeys = {'gstRate', 'cessRate'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _eventColorsFor(theme.colorScheme)[log.event] ?? theme.colorScheme.onSurfaceVariant;
    final actorLabel = log.actorType == 'SYSTEM'
        ? 'System'
        : log.actorName ?? log.actorId ?? 'Admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: event chip, entity chip, time ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    log.entityType,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtTime(log.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Structure / entity name ──
            if (log.feeStructureName != null) ...[
              Text(
                log.feeStructureName!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // ── Free-text note ──
            if (log.note != null && log.note!.isNotEmpty) ...[
              Text(
                log.note!,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // ── Changes section ──
            ..._buildChanges(theme),

            // ── Actor ──
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  actorLabel,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
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

  List<Widget> _buildChanges(ThemeData theme) {
    final before = log.before ?? {};
    final after = log.after ?? {};
    final meta = log.meta ?? {};

    final rows = <_DiffRow>[];

    // ── Meta info (context data attached to the event) ──
    for (final e in meta.entries) {
      if (e.value == null) continue;
      rows.add(
        _DiffRow(
          label: _fieldLabels[e.key] ?? _camelLabel(e.key),
          oldVal: null,
          newVal: _fmt(e.key, e.value),
          isMeta: true,
        ),
      );
    }

    // ── Diff before → after ──
    final allKeys = {...before.keys, ...after.keys};
    for (final key in allKeys) {
      final bVal = before[key];
      final aVal = after[key];
      // Skip if identical (including null == null)
      if (_valEquals(bVal, aVal)) continue;
      rows.add(
        _DiffRow(
          label: _fieldLabels[key] ?? _camelLabel(key),
          oldVal: bVal != null ? _fmt(key, bVal) : null,
          newVal: aVal != null ? _fmt(key, aVal) : null,
        ),
      );
    }

    if (rows.isEmpty) return [];

    return [
      Divider(height: 16, color: theme.colorScheme.outlineVariant),
      Text(
        'DETAILS',
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 6),
      ...rows,
    ];
  }

  bool _valEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i].toString() != b[i].toString()) return false;
      }
      return true;
    }
    return false;
  }

  String _fmt(String key, dynamic value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Yes' : 'No';
    if (_currencyKeys.contains(key) && value is num) {
      return '₹${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
    }
    if (_percentKeys.contains(key) && value is num) return '$value%';
    if (key == 'installmentAmounts' && value is List) {
      if (value.isEmpty) return 'None';
      return value
          .map((x) => '${x['label'] ?? '?'}: ₹${x['amount'] ?? '?'}')
          .join(', ');
    }
    if (value is List) {
      if (value.isEmpty) return 'None';
      return value.length == 1
          ? value.first.toString()
          : '(${value.length} items)';
    }
    return value.toString();
  }

  String _camelLabel(String key) => key
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)!}')
      .trim()
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// Compact row for a single diff entry inside the audit tile
class _DiffRow extends StatelessWidget {
  final String label;
  final String? oldVal;
  final String? newVal;
  final bool isMeta;

  const _DiffRow({
    required this.label,
    required this.oldVal,
    required this.newVal,
    this.isMeta = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Meta rows: just label + value (no arrow)
    if (isMeta) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                newVal ?? '—',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Diff rows: show old → new with color coding
    final isAdded = oldVal == null && newVal != null;
    final isRemoved = oldVal != null && newVal == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: isAdded
                ? Text(
                    newVal!,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : isRemoved
                ? Text(
                    oldVal!,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        oldVal!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      Text(
                        newVal!,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Filter Audit Log',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Entity Type',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
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
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
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
            child: Text(
              'Clear',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No audit events yet',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Events like creating structures, assigning fees,\nand recording payments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
