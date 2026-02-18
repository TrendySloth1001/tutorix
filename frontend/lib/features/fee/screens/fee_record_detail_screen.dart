import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

/// Detailed view of a single fee record.
/// Admin can collect payment, waive fee, send reminder.
/// Student/Parent can see status and payment history.
class FeeRecordDetailScreen extends StatefulWidget {
  final String coachingId;
  final String recordId;
  final bool isAdmin;
  const FeeRecordDetailScreen({
    super.key,
    required this.coachingId,
    required this.recordId,
    this.isAdmin = false,
  });

  @override
  State<FeeRecordDetailScreen> createState() => _FeeRecordDetailScreenState();
}

class _FeeRecordDetailScreenState extends State<FeeRecordDetailScreen> {
  final _svc = FeeService();
  FeeRecordModel? _record;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _svc.getRecord(widget.coachingId, widget.recordId);
      setState(() {
        _record = r;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
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
          'Fee Details',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (widget.isAdmin &&
              _record != null &&
              !_record!.isPaid &&
              !_record!.isWaived)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.darkOlive,
              ),
              onSelected: (v) => _onAction(v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'remind',
                  child: Text('Send Reminder'),
                ),
                const PopupMenuItem(value: 'waive', child: Text('Waive Fee')),
              ],
            ),
          if (widget.isAdmin && _record != null && _record!.paidAmount > 0)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.darkOlive,
              ),
              onSelected: (v) => _onAction(v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'refund',
                  child: Text('Record Refund'),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _Body(
              record: _record!,
              isAdmin: widget.isAdmin,
              onCollect: _showCollectSheet,
            ),
    );
  }

  Future<void> _onAction(String action) async {
    if (action == 'remind') {
      try {
        await _svc.sendReminder(widget.coachingId, widget.recordId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminder marked as sent')),
          );
        }
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else if (action == 'waive') {
      _showWaiveDialog();
    } else if (action == 'refund') {
      _showRefundSheet();
    }
  }

  void _showWaiveDialog() {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Waive Fee',
          style: TextStyle(color: AppColors.darkOlive),
        ),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.waiveFee(
                  widget.coachingId,
                  widget.recordId,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Fee waived')));
                }
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Waive'),
          ),
        ],
      ),
    );
  }

  void _showCollectSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectPaymentSheet(
        record: _record!,
        onSubmit: (amount, mode, ref, notes, date) async {
          await _svc.recordPayment(
            widget.coachingId,
            widget.recordId,
            amount: amount,
            mode: mode,
            transactionRef: ref,
            notes: notes,
            paidAt: date,
          );
          _load();
        },
      ),
    );
  }

  void _showRefundSheet() {
    final amtCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String mode = 'CASH';
    bool submitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
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
                'Record Refund',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.darkOlive,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amtCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Refund Amount (₹)',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Refund Mode'),
                items: const [
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(
                    value: 'BANK_TRANSFER',
                    child: Text('Bank Transfer'),
                  ),
                  DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                ],
                onChanged: (v) => setSt(() => mode = v ?? 'CASH'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amtCtrl.text.trim());
                          if (amt == null || amt <= 0) return;
                          setSt(() => submitting = true);
                          try {
                            await _svc.recordRefund(
                              widget.coachingId,
                              widget.recordId,
                              amount: amt,
                              reason: reasonCtrl.text.trim().isEmpty
                                  ? null
                                  : reasonCtrl.text.trim(),
                              mode: mode,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            setSt(() => submitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.cream,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Process Refund'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final FeeRecordModel record;
  final bool isAdmin;
  final VoidCallback onCollect;
  const _Body({
    required this.record,
    required this.isAdmin,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (record.daysOverdue > 0) ...[
            _OverdueBanner(days: record.daysOverdue),
            const SizedBox(height: 12),
          ],
          _HeaderCard(record: record),
          const SizedBox(height: 20),
          _BreakdownCard(record: record),
          const SizedBox(height: 20),
          if (record.payments.isNotEmpty) ...[
            _PaymentHistory(payments: record.payments),
            const SizedBox(height: 20),
          ],
          if (record.refunds.isNotEmpty) ...[
            _RefundHistory(refunds: record.refunds),
            const SizedBox(height: 20),
          ],
          if (record.member != null) ...[
            _MemberCard(member: record.member!),
            const SizedBox(height: 20),
          ],
          if (isAdmin && !record.isPaid && !record.isWaived)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCollect,
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  record.isPartial
                      ? 'Collect Remaining ₹${record.balance.toStringAsFixed(0)}'
                      : 'Collect Payment',
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  final int days;
  const _OverdueBanner({required this.days});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC62828).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_off_rounded,
            color: Color(0xFFC62828),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This fee is $days day${days == 1 ? '' : 's'} overdue',
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final FeeRecordModel record;
  const _HeaderCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 6),
                _StatusBadge(status: record.status),
                const SizedBox(height: 8),
                Text(
                  'Due: ${_fmtDateLong(record.dueDate)}',
                  style: const TextStyle(
                    color: AppColors.mutedOlive,
                    fontSize: 13,
                  ),
                ),
                if (record.paidAt != null)
                  Text(
                    'Paid: ${_fmtDateLong(record.paidAt!)}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${record.finalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: AppColors.darkOlive,
                ),
              ),
              if (record.isPartial)
                Text(
                  '₹${record.balance.toStringAsFixed(0)} left',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  final FeeRecordModel record;
  const _BreakdownCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Breakdown',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkOlive,
            ),
          ),
          const SizedBox(height: 12),
          _Row('Base Amount', '₹${record.baseAmount.toStringAsFixed(0)}'),
          if (record.discountAmount > 0)
            _Row(
              'Discount',
              '- ₹${record.discountAmount.toStringAsFixed(0)}',
              color: const Color(0xFF2E7D32),
            ),
          if (record.fineAmount > 0)
            _Row(
              'Late Fine',
              '+ ₹${record.fineAmount.toStringAsFixed(0)}',
              color: const Color(0xFFC62828),
            ),
          const Divider(height: 20),
          _Row(
            'Total',
            '₹${record.finalAmount.toStringAsFixed(0)}',
            bold: true,
          ),
          if (record.paidAmount > 0)
            _Row(
              'Paid',
              '₹${record.paidAmount.toStringAsFixed(0)}',
              color: const Color(0xFF2E7D32),
              bold: true,
            ),
          if (record.isPartial)
            _Row(
              'Balance',
              '₹${record.balance.toStringAsFixed(0)}',
              color: const Color(0xFFE65100),
              bold: true,
            ),
          if (record.receiptNo != null) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: record.receiptNo!));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt number copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_rounded,
                      size: 14,
                      color: AppColors.mutedOlive,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Receipt: ${record.receiptNo}',
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: AppColors.mutedOlive,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _Row(this.label, this.value, {this.color, this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.mutedOlive,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.darkOlive,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  final List<FeePaymentModel> payments;
  const _PaymentHistory({required this.payments});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
          ),
        ),
        const SizedBox(height: 10),
        ...payments.map((p) => _PaymentRow(payment: p)),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final FeePaymentModel payment;
  const _PaymentRow({required this.payment});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF2E7D32),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.modeLabel}${payment.transactionRef != null ? ' · ${payment.transactionRef}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.darkOlive,
                  ),
                ),
                Text(
                  _fmtDateLong(payment.paidAt),
                  style: const TextStyle(
                    color: AppColors.mutedOlive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${payment.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RefundHistory extends StatelessWidget {
  final List<FeeRefundModel> refunds;
  const _RefundHistory({required this.refunds});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Refund History',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
          ),
        ),
        const SizedBox(height: 10),
        ...refunds.map((r) => _RefundRow(refund: r)),
      ],
    );
  }
}

class _RefundRow extends StatelessWidget {
  final FeeRefundModel refund;
  const _RefundRow({required this.refund});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.keyboard_return_rounded,
            color: Color(0xFF1565C0),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${refund.mode}${refund.reason != null ? ' · ${refund.reason}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.darkOlive,
                  ),
                ),
                Text(
                  _fmtDateLong(refund.refundedAt),
                  style: const TextStyle(
                    color: AppColors.mutedOlive,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '- ₹${refund.amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1565C0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FeeMemberInfo member;
  const _MemberCard({required this.member});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.softGrey,
            backgroundImage: member.picture != null
                ? NetworkImage(member.picture!)
                : null,
            child: member.picture == null
                ? const Icon(Icons.person_rounded, color: AppColors.mutedOlive)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkOlive,
                  ),
                ),
                if (member.parentName != null)
                  Text(
                    'Parent: ${member.parentName}',
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 12,
                    ),
                  ),
                if (member.phone != null || member.parentPhone != null)
                  Text(
                    member.phone ?? member.parentPhone ?? '',
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 12,
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ─── Collect Payment Sheet ─────────────────────────────────────────────

class _CollectPaymentSheet extends StatefulWidget {
  final FeeRecordModel record;
  final Future<void> Function(
    double amount,
    String mode,
    String? ref,
    String? notes,
    DateTime? date,
  )
  onSubmit;
  const _CollectPaymentSheet({required this.record, required this.onSubmit});

  @override
  State<_CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<_CollectPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _mode = 'CASH';
  DateTime? _paidAt;
  bool _submitting = false;

  static const _modes = [
    'CASH',
    'UPI',
    'ONLINE',
    'BANK_TRANSFER',
    'CHEQUE',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.record.balance.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          Text(
            'Collect Payment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Balance: ₹${widget.record.balance.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment Mode',
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
            children: _modes.map((m) {
              final sel = m == _mode;
              return GestureDetector(
                onTap: () => setState(() => _mode = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.darkOlive
                        : AppColors.softGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? AppColors.darkOlive
                          : AppColors.mutedOlive.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _modeLabel(m),
                    style: TextStyle(
                      color: sel ? AppColors.cream : AppColors.darkOlive,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          if (_mode != 'CASH')
            TextField(
              controller: _refCtrl,
              decoration: InputDecoration(
                labelText: _mode == 'UPI'
                    ? 'UPI Transaction ID'
                    : _mode == 'CHEQUE'
                    ? 'Cheque No.'
                    : 'Reference No.',
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.mutedOlive.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.mutedOlive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _paidAt != null
                        ? 'Paid on: ${_fmtDateLong(_paidAt!)}'
                        : 'Payment date: Today',
                    style: const TextStyle(
                      color: AppColors.darkOlive,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.cream,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Confirm Payment'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paidAt = picked);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (amount > widget.record.balance + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount exceeds balance of ₹${widget.record.balance.toStringAsFixed(0)}',
          ),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        amount,
        _mode,
        _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        _paidAt,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'CASH':
        return '💵 Cash';
      case 'UPI':
        return '📱 UPI';
      case 'ONLINE':
        return '💳 Online';
      case 'BANK_TRANSFER':
        return '🏦 Bank Transfer';
      case 'CHEQUE':
        return '📝 Cheque';
      default:
        return m;
    }
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

String _fmtDateLong(DateTime d) {
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
