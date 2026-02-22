import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

import 'fee_record_detail_screen.dart';
import '../../../core/constants/error_strings.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../core/theme/design_tokens.dart';

/// Lists all fee records for a coaching (admin view).
/// Supports filtering by status and member search.
class FeeRecordsScreen extends StatefulWidget {
  final String coachingId;
  final String? initialMemberId;
  const FeeRecordsScreen({
    super.key,
    required this.coachingId,
    this.initialMemberId,
  });

  @override
  State<FeeRecordsScreen> createState() => _FeeRecordsScreenState();
}

class _FeeRecordsScreenState extends State<FeeRecordsScreen> {
  final _svc = FeeService();
  final List<FeeRecordModel> _records = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  String _filterStatus = 'ALL';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  /// Debounce timer for search input to avoid excessive API calls
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 100 &&
        !_loadingMore &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _records.clear();
        _hasMore = true;
      });
    } else {
      setState(() {
        _loadingMore = true;
      });
    }
    try {
      final page = reset ? 1 : _page;
      final result = await _svc.listRecords(
        widget.coachingId,
        memberId: widget.initialMemberId,
        status: _filterStatus == 'ALL' ? null : _filterStatus,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        page: page,
      );
      final newRecords = result['records'] as List<FeeRecordModel>;
      final total = result['total'] as int;
      setState(() {
        if (reset) _records.clear();
        _records.addAll(newRecords);
        _page = page + 1;
        _hasMore = _records.length < total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorSanitizer.sanitize(
          e,
          fallback: FeeErrors.recordsLoadFailed,
        );
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fee Records',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) {
              _searchQuery = v;
              // Debounce search: wait 400ms after last keystroke before querying
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) _load(reset: true);
              });
            },
          ),
          _FilterBar(
            selected: _filterStatus,
            onChanged: (s) {
              _filterStatus = s;
              _load(reset: true);
            },
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorRetry(
                    message: _error!,
                    onRetry: () => _load(reset: true),
                  )
                : _records.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    color: cs.primary,
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp16,
                        vertical: Spacing.sp8,
                      ),
                      itemCount: _records.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _records.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(Spacing.sp16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        return _RecordTile(
                          record: _records[i],
                          coachingId: widget.coachingId,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FeeRecordDetailScreen(
                                  coachingId: widget.coachingId,
                                  recordId: _records[i].id,
                                  isAdmin: true,
                                ),
                              ),
                            );
                            _load(reset: true);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp12,
        Spacing.sp10,
        Spacing.sp12,
        Spacing.sp4,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: FontSize.body,
        ),
        decoration: InputDecoration(
          hintText: 'Search by student name...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: FontSize.body,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Spacing.sp12,
            vertical: Spacing.sp10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  static const _labels = {
    'ALL': 'All',
    'PENDING': 'Pending',
    'OVERDUE': 'Overdue',
    'PARTIALLY_PAID': 'Partial',
    'PAID': 'Paid',
    'WAIVED': 'Waived',
  };
  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 44,
      color: theme.colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp12,
          vertical: Spacing.sp6,
        ),
        children: _labels.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: Spacing.sp8),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sp14,
                  vertical: Spacing.sp4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontSize: FontSize.caption,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final FeeRecordModel record;
  final VoidCallback onTap;
  final String coachingId;
  const _RecordTile({
    required this.record,
    required this.onTap,
    required this.coachingId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(record.status, theme.colorScheme);
    final memberName = record.member?.name ?? 'Unknown Student';
    final memberPic = record.member?.picture;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp10),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.sp12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar (Display only)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: memberPic != null && memberPic.isNotEmpty
                        ? NetworkImage(memberPic)
                        : null,
                    child: memberPic == null || memberPic.isEmpty
                        ? Text(
                            memberName.isNotEmpty
                                ? memberName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: Spacing.sp12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memberName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                    fontSize: FontSize.body,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: Spacing.sp2),
                                Text(
                                  record.title,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: FontSize.caption,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Spacing.sp8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${record.finalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: FontSize.body,
                                ),
                              ),
                              if (record.isPartial || record.isPaid)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: Spacing.sp2,
                                  ),
                                  child: Text(
                                    'Paid ₹${record.paidAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: FontSize.nano,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.sp10),
                      Row(
                        children: [
                          _Chip(
                            label: _statusLabel(record.status),
                            color: statusColor,
                            isFilled: true,
                          ),
                          const SizedBox(width: Spacing.sp8),
                          _Chip(
                            label: 'Due ${_fmtDate(record.dueDate)}',
                            color: record.isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          if (record.daysOverdue > 0) ...[
                            const SizedBox(width: Spacing.sp6),
                            Text(
                              '${record.daysOverdue}d late',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: FontSize.micro,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isFilled;
  const _Chip({
    required this.label,
    required this.color,
    this.isFilled = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp8,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: isFilled
            ? color.withValues(alpha: 0.1)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(
          color: isFilled ? Colors.transparent : color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: FontSize.nano,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

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
            Icons.receipt_long_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.sp12),
          Text(
            'No fee records found',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String s, ColorScheme cs) {
  switch (s) {
    case 'PAID':
      return cs.primary;
    case 'PENDING':
      return cs.secondary;
    case 'OVERDUE':
      return cs.error;
    case 'PARTIALLY_PAID':
      return cs.secondary;
    case 'WAIVED':
      return cs.onSurfaceVariant;
    default:
      return cs.onSurfaceVariant;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'PAID':
      return 'Paid';
    case 'PENDING':
      return 'Pending';
    case 'OVERDUE':
      return 'Overdue';
    case 'PARTIALLY_PAID':
      return 'Partial';
    case 'WAIVED':
      return 'Waived';
    default:
      return s;
  }
}

String _fmtDate(DateTime d) {
  final months = [
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
  return '${d.day} ${months[d.month - 1]}';
}
