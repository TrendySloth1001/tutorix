import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import '../services/payment_service.dart';
import 'fee_record_detail_screen.dart';
import 'payment_receipt_screen.dart';

/// Student / Parent fee view for a specific coaching.
/// Groups records by status with a clean summary header.
class MyFeesScreen extends StatefulWidget {
  final String coachingId;
  final String coachingName;
  const MyFeesScreen({
    super.key,
    required this.coachingId,
    required this.coachingName,
  });

  @override
  State<MyFeesScreen> createState() => _MyFeesScreenState();
}

class _MyFeesScreenState extends State<MyFeesScreen> {
  final _svc = FeeService();
  final _paySvc = PaymentService();
  List<FeeRecordModel> _records = [];
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paySvc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _svc.getMyFees(widget.coachingId);
      final records = (result['records'] as List<FeeRecordModel>);
      // Sort: overdue first, then pending, then partial, then paid/waived
      records.sort(
        (a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)),
      );
      setState(() {
        _records = records;
        _summary = result['summary'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _statusOrder(String s) {
    switch (s) {
      case 'OVERDUE':
        return 0;
      case 'PENDING':
        return 1;
      case 'PARTIALLY_PAID':
        return 2;
      case 'PAID':
        return 3;
      case 'WAIVED':
        return 4;
      default:
        return 5;
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
        title: Text(
          'Fees · ${widget.coachingName}',
          style: const TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: AppColors.darkOlive,
              onRefresh: _load,
              child: _records.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [SizedBox(height: 200), _EmptyState()],
                    )
                  : _Body(
                      records: _records,
                      coachingId: widget.coachingId,
                      coachingName: widget.coachingName,
                      serverSummary: _summary,
                      onPayOnline: _payOnline,
                    ),
            ),
    );
  }

  Future<void> _payOnline(FeeRecordModel record) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    debugPrint('[PayOnline] Starting payment for record: ${record.id}');

    try {
      // 1. Create order
      debugPrint('[PayOnline] Creating order...');
      final orderData = await _paySvc.createOrder(widget.coachingId, record.id);

      debugPrint('[PayOnline] Order created: $orderData');

      if (!mounted) return;

      // 2. Open Razorpay checkout
      debugPrint('[PayOnline] Opening Razorpay checkout...');
      final response = await _paySvc.openCheckout(
        orderId: orderData['orderId'] as String,
        amountPaise: (orderData['amount'] as num).toInt(),
        key: orderData['key'] as String,
        feeTitle: record.title,
        userEmail: user?.email,
        userPhone: user?.phone,
        userName: user?.name,
      );

      if (!mounted) return;

      // 3. Verify payment
      final verified = await _paySvc.verifyPayment(
        widget.coachingId,
        record.id,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      if (!mounted) return;

      // 4. Extract enriched payment data
      final vp = verified['verifiedPayment'] as Map<String, dynamic>?;
      final receiptNo =
          vp?['receiptNo'] as String? ?? verified['receiptNo'] as String? ?? '';
      final paidAmount = (vp?['amount'] as num?)?.toDouble() ?? record.balance;

      // 5. Show receipt with tax breakdown
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentReceiptScreen(
            coachingName: widget.coachingName,
            feeTitle: record.title,
            amount: paidAmount,
            paymentId: response.paymentId!,
            orderId: response.orderId!,
            paidAt: vp?['paidAt'] != null
                ? DateTime.tryParse(vp!['paidAt'] as String) ?? DateTime.now()
                : DateTime.now(),
            studentName: record.member?.name,
            receiptNo: receiptNo,
            taxType: record.taxType,
            taxAmount: record.taxAmount,
            cgstAmount: record.cgstAmount,
            sgstAmount: record.sgstAmount,
            igstAmount: record.igstAmount,
            cessAmount: record.cessAmount,
            gstRate: record.gstRate,
            sacCode: record.sacCode,
            baseAmount: record.baseAmount,
            discountAmount: record.discountAmount,
            fineAmount: record.fineAmount,
          ),
        ),
      );

      _load(); // refresh
    } catch (e, st) {
      debugPrint('[PayOnline] ERROR: $e');
      debugPrint('[PayOnline] Stack: $st');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFC62828)),
      );
    }
  }
}

class _Body extends StatelessWidget {
  final List<FeeRecordModel> records;
  final String coachingId;
  final String coachingName;
  final Map<String, dynamic>? serverSummary;
  final void Function(FeeRecordModel) onPayOnline;
  const _Body({
    required this.records,
    required this.coachingId,
    required this.coachingName,
    this.serverSummary,
    required this.onPayOnline,
  });

  @override
  Widget build(BuildContext context) {
    // Use server summary if available, otherwise compute locally
    final totalPaid =
        (serverSummary?['totalPaid'] as num?)?.toDouble() ??
        records.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalDue =
        (serverSummary?['totalDue'] as num?)?.toDouble() ??
        records
            .where(
              (r) =>
                  r.status == 'PENDING' ||
                  r.status == 'PARTIALLY_PAID' ||
                  r.status == 'OVERDUE',
            )
            .fold<double>(0, (s, r) => s + r.balance);
    final totalOverdue =
        (serverSummary?['totalOverdue'] as num?)?.toDouble() ??
        records
            .where((r) => r.status == 'OVERDUE')
            .fold<double>(0, (s, r) => s + r.balance);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _SummaryHeader(
            totalDue: totalDue,
            totalPaid: totalPaid,
            totalOverdue: totalOverdue,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((ctx, i) {
              final r = records[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MyFeeCard(
                  record: r,
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => FeeRecordDetailScreen(
                        coachingId: coachingId,
                        recordId: r.id,
                        coachingName: coachingName,
                      ),
                    ),
                  ),
                  onPayOnline: () => onPayOnline(r),
                ),
              );
            }, childCount: records.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double totalDue;
  final double totalPaid;
  final double totalOverdue;
  const _SummaryHeader({
    required this.totalDue,
    required this.totalPaid,
    required this.totalOverdue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkOlive,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fee Summary',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Paid',
                  amount: totalPaid,
                  color: const Color(0xFF81C784),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Due',
                  amount: totalDue,
                  color: AppColors.cream,
                ),
              ),
              if (totalOverdue > 0)
                Expanded(
                  child: _SummaryItem(
                    label: 'Overdue',
                    amount: totalOverdue,
                    color: const Color(0xFFEF9A9A),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '₹${_formatAmount(amount)}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12),
        ),
      ],
    );
  }
}

class _MyFeeCard extends StatelessWidget {
  final FeeRecordModel record;
  final VoidCallback onTap;
  final VoidCallback onPayOnline;
  const _MyFeeCard({
    required this.record,
    required this.onTap,
    required this.onPayOnline,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    final canPay =
        record.status == 'PENDING' ||
        record.status == 'OVERDUE' ||
        record.status == 'PARTIALLY_PAID';
    return Material(
      color: Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkOlive,
                            fontSize: 14,
                          ),
                        ),
                        if (record.member != null &&
                            record.member!.wardId != null)
                          Text(
                            'For: ${record.member!.name ?? 'Ward'}',
                            style: const TextStyle(
                              color: AppColors.mutedOlive,
                              fontSize: 12,
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
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkOlive,
                          fontSize: 17,
                        ),
                      ),
                      _StatusPill(status: record.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.mutedOlive,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${_fmtDate(record.dueDate)}',
                    style: TextStyle(
                      color: record.isOverdue
                          ? const Color(0xFFC62828)
                          : AppColors.mutedOlive,
                      fontSize: 12,
                      fontWeight: record.isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (record.daysOverdue > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${record.daysOverdue}d',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (record.isPartial) ...[
                    Text(
                      '₹${record.paidAmount.toStringAsFixed(0)} paid',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ₹${record.balance.toStringAsFixed(0)} left',
                      style: const TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (record.status != 'PAID' && record.status != 'WAIVED') ...[
                const SizedBox(height: 10),
                _ProgressBar(
                  paid: record.paidAmount,
                  total: record.finalAmount,
                  statusColor: statusColor,
                ),
              ],
              // ─── Pay Online Button ───
              if (canPay) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: onPayOnline,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.darkOlive,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      record.isPartial
                          ? 'Pay ₹${record.balance.toStringAsFixed(0)} Online'
                          : 'Pay ₹${record.finalAmount.toStringAsFixed(0)} Online',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double paid;
  final double total;
  final Color statusColor;
  const _ProgressBar({
    required this.paid,
    required this.total,
    required this.statusColor,
  });
  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        backgroundColor: AppColors.softGrey.withValues(alpha: 0.4),
        valueColor: AlwaysStoppedAnimation(statusColor),
        minHeight: 4,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
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
            Icons.check_circle_outline_rounded,
            size: 52,
            color: Color(0xFF2E7D32),
          ),
          SizedBox(height: 12),
          Text(
            'No fees due!',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.darkOlive,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'You are all caught up.',
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

String _formatAmount(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
