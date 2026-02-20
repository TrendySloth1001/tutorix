import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

import 'fee_record_detail_screen.dart';

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
        _error = e.toString();
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fee Records',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
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
                ? _ErrorRetry(error: _error!, onRetry: () => _load(reset: true))
                : _records.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    color: AppColors.darkOlive,
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _records.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _records.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.darkOlive, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by student name...',
          hintStyle: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.mutedOlive,
            size: 20,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: AppColors.mutedOlive,
                    size: 18,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.softGrey.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
    return Container(
      height: 44,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _labels.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.darkOlive
                      : AppColors.softGrey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.darkOlive
                        : AppColors.mutedOlive.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: isSelected ? AppColors.cream : AppColors.darkOlive,
                    fontSize: 12,
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
    final statusColor = _statusColor(record.status);
    final memberName = record.member?.name ?? 'Unknown Student';
    final memberPic = record.member?.picture;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: AppColors.softGrey.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.mutedOlive.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar (Display only)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.mutedOlive.withValues(alpha: 0.2),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.softGrey.withValues(alpha: 0.5),
                    backgroundImage: memberPic != null && memberPic.isNotEmpty
                        ? NetworkImage(memberPic)
                        : null,
                    child: memberPic == null || memberPic.isEmpty
                        ? Text(
                            memberName.isNotEmpty
                                ? memberName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.darkOlive,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.darkOlive,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  record.title,
                                  style: const TextStyle(
                                    color: AppColors.mutedOlive,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${record.finalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.darkOlive,
                                  fontSize: 15,
                                ),
                              ),
                              if (record.isPartial || record.isPaid)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Paid ₹${record.paidAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _Chip(
                            label: _statusLabel(record.status),
                            color: statusColor,
                            isFilled: true,
                          ),
                          const SizedBox(width: 8),
                          _Chip(
                            label: 'Due ${_fmtDate(record.dueDate)}',
                            color: record.isOverdue
                                ? const Color(0xFFC62828)
                                : AppColors.mutedOlive,
                          ),
                          if (record.daysOverdue > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${record.daysOverdue}d late',
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFilled
            ? color.withValues(alpha: 0.1)
            : AppColors.softGrey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFilled ? Colors.transparent : color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.mutedOlive,
          ),
          SizedBox(height: 12),
          Text(
            'No fee records found',
            style: TextStyle(color: AppColors.mutedOlive),
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
            style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'PAID':
      return const Color(0xFF2E7D32);
    case 'PENDING':
      return const Color(0xFF1565C0);
    case 'OVERDUE':
      return const Color(0xFFC62828);
    case 'PARTIALLY_PAID':
      return const Color(0xFFE65100);
    case 'WAIVED':
      return AppColors.mutedOlive;
    default:
      return AppColors.mutedOlive;
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
