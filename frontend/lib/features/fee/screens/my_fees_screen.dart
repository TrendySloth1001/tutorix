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

  // Multi-select state
  final Set<String> _selected = {};
  bool _selectMode = false;

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
        _selected.removeWhere((id) => !records.any((r) => r.id == id));
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

  List<FeeRecordModel> get _payableRecords => _records
      .where(
        (r) =>
            r.status == 'PENDING' ||
            r.status == 'OVERDUE' ||
            r.status == 'PARTIALLY_PAID',
      )
      .toList();

  double get _selectedTotal {
    return _records
        .where((r) => _selected.contains(r.id))
        .fold<double>(0, (s, r) => s + r.balance);
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selectMode = false;
      } else {
        _selected.add(id);
        _selectMode = true;
      }
    });
  }

  void _selectAllPayable() {
    setState(() {
      final ids = _payableRecords.map((r) => r.id).toSet();
      if (_selected.containsAll(ids)) {
        _selected.clear();
        _selectMode = false;
      } else {
        _selected.addAll(ids);
        _selectMode = true;
      }
    });
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
          _selectMode
              ? '${_selected.length} selected'
              : 'Fees · ${widget.coachingName}',
          style: const TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_selectMode)
            TextButton(
              onPressed: () => setState(() {
                _selected.clear();
                _selectMode = false;
              }),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.darkOlive),
              ),
            ),
          if (!_selectMode && _payableRecords.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.checklist_rounded,
                color: AppColors.darkOlive,
              ),
              tooltip: 'Select fees to pay',
              onPressed: _selectAllPayable,
            ),
        ],
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
                          children: const [
                            SizedBox(height: 200),
                            _EmptyState(),
                          ],
                        )
                      : _buildBody(),
                ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? _PayBar(
              selectedCount: _selected.length,
              totalAmount: _selectedTotal,
              onPayFull: () => _payMulti(null),
              onPayCustom: _showCustomAmountSheet,
            )
          : null,
    );
  }

  // ─── Build the fee list body ───
  Widget _buildBody() {
    final totalPaid =
        ((_summary?['totalPaid'] as num?)?.toDouble()) ??
        _records.fold<double>(0, (s, r) => s + r.paidAmount);
    final totalDue =
        ((_summary?['totalDue'] as num?)?.toDouble()) ??
        _payableRecords.fold<double>(0, (s, r) => s + r.balance);
    final totalOverdue =
        ((_summary?['totalOverdue'] as num?)?.toDouble()) ??
        _records
            .where((r) => r.status == 'OVERDUE')
            .fold<double>(0, (s, r) => s + r.balance);

    final payable = _payableRecords;
    final settled = _records
        .where((r) => r.status == 'PAID' || r.status == 'WAIVED')
        .toList();

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
        // ─── Payable Section ───
        if (payable.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Payable',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkOlive,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${payable.length}',
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_selectMode)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text(
                        'Select All',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: _selectAllPayable,
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final r = payable[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeeCard(
                    record: r,
                    isSelected: _selected.contains(r.id),
                    selectMode: _selectMode,
                    onTap: () {
                      if (_selectMode) {
                        _toggleSelect(r.id);
                      } else {
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => FeeRecordDetailScreen(
                              coachingId: widget.coachingId,
                              recordId: r.id,
                              coachingName: widget.coachingName,
                            ),
                          ),
                        ).then((_) => _load());
                      }
                    },
                    onLongPress: () => _toggleSelect(r.id),
                    onPayOnline: () => _paySingle(r),
                  ),
                );
              }, childCount: payable.length),
            ),
          ),
        ],
        // ─── Settled Section ───
        if (settled.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  const Text(
                    'Settled',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.mutedOlive,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${settled.length}',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final r = settled[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeeCard(
                    record: r,
                    isSelected: false,
                    selectMode: false,
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => FeeRecordDetailScreen(
                          coachingId: widget.coachingId,
                          recordId: r.id,
                          coachingName: widget.coachingName,
                        ),
                      ),
                    ).then((_) => _load()),
                    onLongPress: null,
                    onPayOnline: null,
                  ),
                );
              }, childCount: settled.length),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ─── Single-record online pay ───
  Future<void> _paySingle(FeeRecordModel record) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    try {
      final orderData = await _paySvc.createOrder(
        widget.coachingId,
        record.id,
      );
      if (!mounted) return;

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

      final verified = await _paySvc.verifyPayment(
        widget.coachingId,
        record.id,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );
      if (!mounted) return;

      final vp = verified['verifiedPayment'] as Map<String, dynamic>?;
      final receiptNo =
          vp?['receiptNo'] as String? ??
          verified['receiptNo'] as String? ??
          '';
      final paidAmount =
          (vp?['amount'] as num?)?.toDouble() ?? record.balance;

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
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  // ─── Multi-record online pay ───
  Future<void> _payMulti(double? customAmount) async {
    if (_selected.isEmpty) return;
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    try {
      final orderData = await _paySvc.createMultiOrder(
        widget.coachingId,
        recordIds: _selected.toList(),
        amount: customAmount,
      );
      if (!mounted) return;

      final response = await _paySvc.openCheckout(
        orderId: orderData['orderId'] as String,
        amountPaise: (orderData['amount'] as num).toInt(),
        key: orderData['key'] as String,
        feeTitle:
            '${_selected.length} fee${_selected.length > 1 ? 's' : ''}',
        userEmail: user?.email,
        userPhone: user?.phone,
        userName: user?.name,
      );
      if (!mounted) return;

      await _paySvc.verifyMultiPayment(
        widget.coachingId,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _showCustomAmountSheet() {
    final ctrl = TextEditingController(
      text: _selectedTotal.toStringAsFixed(0),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pay Custom Amount',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.darkOlive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total due: ₹${_selectedTotal.toStringAsFixed(0)} '
              'for ${_selected.length} fee${_selected.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: AppColors.mutedOlive,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [25, 50, 75, 100].map((pct) {
                final amt = (_selectedTotal * pct / 100).round();
                return ActionChip(
                  label: Text('$pct% · ₹$amt'),
                  onPressed: () => ctrl.text = amt.toString(),
                  backgroundColor:
                      AppColors.softGrey.withValues(alpha: 0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkOlive,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  final amt = double.tryParse(ctrl.text.trim());
                  if (amt == null || amt <= 0) return;
                  Navigator.pop(ctx);
                  _payMulti(amt);
                },
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ─── WIDGETS ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Bottom payment bar when records are selected.
class _PayBar extends StatelessWidget {
  final int selectedCount;
  final double totalAmount;
  final VoidCallback onPayFull;
  final VoidCallback onPayCustom;
  const _PayBar({
    required this.selectedCount,
    required this.totalAmount,
    required this.onPayFull,
    required this.onPayCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$selectedCount fee${selectedCount > 1 ? 's' : ''} selected',
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: AppColors.darkOlive,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onPayCustom,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.darkOlive,
                side: const BorderSide(color: AppColors.darkOlive),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Custom',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onPayFull,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.darkOlive,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text(
                'Pay Now',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
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
          Row(
            children: [
              const Text(
                'Fee Summary',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (totalDue > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Due ₹${_formatAmount(totalDue)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
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
                  label: 'Outstanding',
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

/// A single fee record card with selection support.
class _FeeCard extends StatelessWidget {
  final FeeRecordModel record;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPayOnline;
  const _FeeCard({
    required this.record,
    required this.isSelected,
    required this.selectMode,
    required this.onTap,
    this.onLongPress,
    this.onPayOnline,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(record.status);
    final canPay = record.status == 'PENDING' ||
        record.status == 'OVERDUE' ||
        record.status == 'PARTIALLY_PAID';

    return Material(
      color: isSelected
          ? AppColors.darkOlive.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: AppColors.darkOlive,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectMode && canPay)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? AppColors.darkOlive
                            : AppColors.mutedOlive,
                        size: 22,
                      ),
                    ),
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
                        canPay
                            ? '₹${record.balance.toStringAsFixed(0)}'
                            : '₹${record.finalAmount.toStringAsFixed(0)}',
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
              const SizedBox(height: 10),
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
                        '${record.daysOverdue}d overdue',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (record.discountAmount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-₹${record.discountAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (record.isPartial) ...[
                    Text(
                      '₹${record.paidAmount.toStringAsFixed(0)} paid',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              // Validity period
              if (record.validFrom != null || record.validUntil != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 12,
                      color: AppColors.mutedOlive,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _validityLabel(record.validFrom, record.validUntil),
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
              // Tax info
              if (record.hasTax) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 12,
                      color: AppColors.mutedOlive,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'GST ${record.gstRate.toStringAsFixed(0)}%'
                      ' · Tax ₹${record.taxAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
              // Progress bar
              if (canPay) ...[
                const SizedBox(height: 10),
                _ProgressBar(
                  paid: record.paidAmount,
                  total: record.finalAmount,
                  statusColor: statusColor,
                ),
              ],
              // Pay Online (only in non-select mode)
              if (canPay && !selectMode) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
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
                      'Pay ₹${record.balance.toStringAsFixed(0)} Online',
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

  static String _validityLabel(DateTime? from, DateTime? until) {
    if (from != null && until != null) {
      return '${_fmtDate(from)} — ${_fmtDate(until)}';
    }
    if (from != null) return 'From ${_fmtDate(from)}';
    if (until != null) return 'Until ${_fmtDate(until)}';
    return '';
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _formatAmount(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}
