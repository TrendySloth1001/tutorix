import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import '../services/payment_service.dart';
import 'payment_receipt_screen.dart';

/// Detailed view of a single fee record.
/// Admin can collect payment, waive fee, send reminder.
/// Student/Parent can see status and payment history.
class FeeRecordDetailScreen extends StatefulWidget {
  final String coachingId;
  final String recordId;
  final bool isAdmin;
  final String? coachingName;
  const FeeRecordDetailScreen({
    super.key,
    required this.coachingId,
    required this.recordId,
    this.isAdmin = false,
    this.coachingName,
  });

  @override
  State<FeeRecordDetailScreen> createState() => _FeeRecordDetailScreenState();
}

class _FeeRecordDetailScreenState extends State<FeeRecordDetailScreen> {
  final _svc = FeeService();
  final _paySvc = PaymentService();
  FeeRecordModel? _record;
  List<Map<String, dynamic>> _failedOrders = [];
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
      final results = await Future.wait([
        _svc.getRecord(widget.coachingId, widget.recordId),
        _paySvc.getFailedOrders(widget.coachingId, widget.recordId),
      ]);
      if (!mounted) return;
      setState(() {
        _record = results[0] as FeeRecordModel;
        _failedOrders = (results[1] as List).cast<Map<String, dynamic>>();
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
          if (widget.isAdmin && _record != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.darkOlive,
              ),
              onSelected: (v) => _onAction(v),
              itemBuilder: (_) => [
                if (!_record!.isPaid && !_record!.isWaived) ...[
                  const PopupMenuItem(
                    value: 'remind',
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 20,
                          color: AppColors.darkOlive,
                        ),
                        SizedBox(width: 12),
                        Text('Send Reminder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'waive',
                    child: Row(
                      children: [
                        Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: AppColors.darkOlive,
                        ),
                        SizedBox(width: 12),
                        Text('Waive Fee'),
                      ],
                    ),
                  ),
                ],
                if (_record!.paidAmount > 0)
                  const PopupMenuItem(
                    value: 'refund',
                    child: Row(
                      children: [
                        Icon(
                          Icons.keyboard_return,
                          size: 20,
                          color: AppColors.darkOlive,
                        ),
                        SizedBox(width: 12),
                        Text('Record Refund'),
                      ],
                    ),
                  ),
                if (_record!.paidAmount > 0)
                  const PopupMenuItem(
                    value: 'online_refund',
                    child: Row(
                      children: [
                        Icon(
                          Icons.currency_rupee_rounded,
                          size: 20,
                          color: AppColors.darkOlive,
                        ),
                        SizedBox(width: 12),
                        Text('Online Refund'),
                      ],
                    ),
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
              onRemind: () => _onAction('remind'),
              onWaive: () => _onAction('waive'),
              onRefund: () => _onAction('refund'),
              onPayOnline: _initiateOnlinePayment,
              onPayFull: () => _payOnline(null),
              coachingName: widget.coachingName ?? 'Institute',
              failedOrders: _failedOrders,
            ),
    );
  }

  Future<void> _onAction(String action) async {
    if (action == 'remind') {
      try {
        await _svc.sendReminder(widget.coachingId, widget.recordId);
        if (mounted) AppAlert.success(context, 'Reminder marked as sent');
        _load();
      } catch (e) {
        if (mounted) AppAlert.error(context, e);
      }
    } else if (action == 'waive') {
      _showWaiveDialog();
    } else if (action == 'refund') {
      _showRefundSheet();
    } else if (action == 'online_refund') {
      _showOnlineRefundSheet();
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
                if (mounted)
                  AppAlert.success(context, 'Fee waived successfully');
                _load();
              } catch (e) {
                if (mounted) AppAlert.error(context, e);
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

  /// Entry point: shows installment picker if admin has configured installments,
  /// otherwise goes straight to full-balance payment.
  Future<void> _initiateOnlinePayment() async {
    if (_record == null) return;
    final structure = _record!.feeStructure;
    if (structure != null && structure.allowInstallments) {
      _showInstallmentPicker(structure);
    } else {
      await _payOnline(null);
    }
  }

  void _showInstallmentPicker(FeeStructureModel structure) {
    final balance = _record?.balance ?? 0;
    final paidAmount = _record?.paidAmount ?? 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InstallmentPickerSheet(
        fixedItems: structure.installmentAmounts,
        installmentCount: structure.installmentCount,
        balance: balance,
        paidAmount: paidAmount,
        onSelected: (double? amount) => _payOnline(amount),
      ),
    );
  }

  Future<void> _payOnline(double? amount) async {
    if (_record == null) return;
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    Map<String, dynamic>? orderData;
    try {
      orderData = await _paySvc.createOrder(
        widget.coachingId,
        widget.recordId,
        amount: amount,
      );

      if (!mounted) return;

      final response = await _paySvc.openCheckout(
        orderId: orderData['orderId'] as String,
        amountPaise: (orderData['amount'] as num).toInt(),
        key: orderData['key'] as String,
        feeTitle: _record!.title,
        userEmail: user?.email,
        userPhone: user?.phone,
        userName: user?.name,
      );

      if (!mounted) return;

      final verified = await _paySvc.verifyPayment(
        widget.coachingId,
        widget.recordId,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      if (!mounted) return;

      final vp = verified['verifiedPayment'] as Map<String, dynamic>?;
      final receiptNo =
          vp?['receiptNo'] as String? ?? verified['receiptNo'] as String? ?? '';
      final paidAmount =
          (vp?['amount'] as num?)?.toDouble() ?? _record!.balance;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentReceiptScreen(
            coachingName: widget.coachingName ?? 'Institute',
            feeTitle: _record!.title,
            amount: paidAmount,
            paymentId: response.paymentId!,
            orderId: response.orderId!,
            paidAt: vp?['paidAt'] != null
                ? DateTime.tryParse(vp!['paidAt'] as String) ?? DateTime.now()
                : DateTime.now(),
            studentName: _record!.member?.name,
            receiptNo: receiptNo,
            paymentMode: 'RAZORPAY',
            taxType: _record!.taxType,
            taxAmount: _record!.taxAmount,
            cgstAmount: _record!.cgstAmount,
            sgstAmount: _record!.sgstAmount,
            igstAmount: _record!.igstAmount,
            cessAmount: _record!.cessAmount,
            gstRate: _record!.gstRate,
            sacCode: _record!.sacCode,
            baseAmount: _record!.baseAmount,
            discountAmount: _record!.discountAmount,
            fineAmount: _record!.fineAmount,
          ),
        ),
      );

      _load();
    } catch (e) {
      if (orderData != null) {
        final internalId = orderData['internalOrderId'] as String?;
        if (internalId != null) {
          final reason = e.toString().replaceFirst('Exception: ', '');
          await _paySvc.markOrderFailed(widget.coachingId, internalId, reason);
        }
      }
      await _load();
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg == 'Payment cancelled') return; // user dismissed — no snackbar
      AppAlert.error(context, msg);
    }
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
                          if (_record != null && amt > _record!.paidAmount) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Cannot refund more than paid amount (₹${_record!.paidAmount.toStringAsFixed(0)})',
                                ),
                              ),
                            );
                            return;
                          }
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

  void _showOnlineRefundSheet() {
    bool loading = true;
    List<Map<String, dynamic>> payments = [];
    String? selectedPaymentId;
    final amtCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          // Load payments once, not on every rebuild
          if (loading && payments.isEmpty) {
            // Use Future.microtask to avoid side-effect in build
            Future.microtask(() {
              _paySvc
                  .getOnlinePayments(widget.coachingId, widget.recordId)
                  .then((data) {
                    if (ctx.mounted) {
                      setSt(() {
                        payments = data;
                        loading = false;
                      });
                    }
                  })
                  .catchError((e) {
                    if (ctx.mounted) {
                      setSt(() => loading = false);
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  });
              loading = false; // prevent re-trigger on rebuild
            });
          }

          return Container(
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
                  'Online Refund',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: AppColors.darkOlive,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select an online payment to refund via Razorpay',
                  style: TextStyle(color: AppColors.mutedOlive, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No online payments found for this record',
                        style: TextStyle(color: AppColors.mutedOlive),
                      ),
                    ),
                  )
                else ...[
                  ...payments.map((p) {
                    final id = p['id'] as String;
                    final amt = (p['amount'] as num).toDouble();
                    final date = DateTime.tryParse(
                      p['paidAt'] as String? ?? '',
                    );
                    final selected = selectedPaymentId == id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected
                            ? AppColors.darkOlive.withValues(alpha: 0.08)
                            : AppColors.softGrey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setSt(() {
                            selectedPaymentId = id;
                            amtCtrl.text = amt.toStringAsFixed(0);
                          }),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: AppColors.darkOlive,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${amt.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkOlive,
                                        ),
                                      ),
                                      if (date != null)
                                        Text(
                                          '${date.day}/${date.month}/${date.year}',
                                          style: const TextStyle(
                                            color: AppColors.mutedOlive,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  p['receiptNo'] as String? ?? '',
                                  style: const TextStyle(
                                    color: AppColors.mutedOlive,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount (₹)',
                      prefixText: '₹ ',
                      helperText: 'Leave as-is for full refund',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: submitting || selectedPaymentId == null
                          ? null
                          : () async {
                              final amt = double.tryParse(amtCtrl.text.trim());
                              if (amt == null || amt <= 0) return;
                              // Upper-bound: find selected payment's amount
                              final selPay = payments.firstWhere(
                                (p) => p['id'] == selectedPaymentId,
                                orElse: () => <String, dynamic>{},
                              );
                              final payAmt =
                                  (selPay['amount'] as num?)?.toDouble() ?? 0;
                              if (amt > payAmt) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cannot refund more than payment amount (₹${payAmt.toStringAsFixed(0)})',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              setSt(() => submitting = true);
                              try {
                                await _paySvc.initiateOnlineRefund(
                                  widget.coachingId,
                                  widget.recordId,
                                  paymentId: selectedPaymentId!,
                                  amount: amt,
                                  reason: reasonCtrl.text.trim().isEmpty
                                      ? null
                                      : reasonCtrl.text.trim(),
                                );
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Refund initiated'),
                                    ),
                                  );
                                }
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
                          : const Text('Initiate Refund via Razorpay'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final FeeRecordModel record;
  final bool isAdmin;
  final VoidCallback onCollect;
  final VoidCallback onRemind;
  final VoidCallback onWaive;
  final VoidCallback onRefund;
  final VoidCallback onPayOnline;
  final VoidCallback onPayFull;
  final String coachingName;
  final List<Map<String, dynamic>> failedOrders;

  const _Body({
    required this.record,
    required this.isAdmin,
    required this.onCollect,
    required this.onRemind,
    required this.onWaive,
    required this.onRefund,
    required this.onPayOnline,
    required this.onPayFull,
    required this.coachingName,
    this.failedOrders = const [],
  });

  static bool _hasInstallments(FeeRecordModel r) {
    final s = r.feeStructure;
    return s != null && s.allowInstallments;
  }

  /// Compute label for the installment button.
  /// Shows the next-due per-installment amount based on structure config.
  static String _installmentLabel(FeeRecordModel r) {
    final s = r.feeStructure;
    if (s == null) return r.balance.toStringAsFixed(0);
    // If admin defined fixed amounts, find the first unpaid installment
    if (s.installmentAmounts.isNotEmpty) {
      double cumulative = 0;
      for (final item in s.installmentAmounts) {
        cumulative += item.amount;
        if (r.paidAmount < cumulative - 0.01) {
          return item.amount.toStringAsFixed(0);
        }
      }
      return s.installmentAmounts.last.amount.toStringAsFixed(0);
    }
    // Auto-computed from installmentCount — use TOTAL amount, not remaining balance
    if (s.installmentCount > 0) {
      final total = r.balance + r.paidAmount; // equals finalAmount
      final per = (total / s.installmentCount * 100).ceilToDouble() / 100;
      return per.toStringAsFixed(0);
    }
    return r.balance.toStringAsFixed(0);
  }

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
          if (isAdmin) ...[
            const SizedBox(height: 16),
            _QuickActions(
              record: record,
              onRemind: onRemind,
              onWaive: onWaive,
              onRefund: onRefund,
            ),
          ],
          const SizedBox(height: 20),
          _BreakdownCard(record: record),
          const SizedBox(height: 20),
          if (record.payments.isNotEmpty) ...[
            _PaymentHistory(
              payments: record.payments,
              coachingName: coachingName,
              record: record,
            ),
            const SizedBox(height: 20),
          ],
          if (record.refunds.isNotEmpty) ...[
            _RefundHistory(refunds: record.refunds),
            const SizedBox(height: 20),
          ],
          if (failedOrders.isNotEmpty) ...[
            _FailedAttempts(orders: failedOrders),
            const SizedBox(height: 20),
          ],
          if (record.member != null) ...[
            _MemberCard(member: record.member!),
            const SizedBox(height: 20),
          ],
          if (isAdmin && !record.isPaid && !record.isWaived)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: onCollect,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkOlive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  record.isPartial
                      ? 'Collect Remaining ₹${record.balance.toStringAsFixed(0)}'
                      : 'Collect Payment',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          // ─── Pay Online (Student / Parent) ───
          if (!isAdmin && !record.isPaid && !record.isWaived) ...[
            if (_hasInstallments(record)) ...[
              // Two-button row: installment (primary) + full (outlined)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: onPayOnline,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkOlive,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.splitscreen_rounded, size: 20),
                        label: Text(
                          'Pay ₹${_installmentLabel(record)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: onPayFull,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkOlive,
                          side: const BorderSide(color: AppColors.darkOlive),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: Text(
                          'Full ₹${record.balance.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: onPayFull,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    record.isPartial
                        ? 'Pay ₹${record.balance.toStringAsFixed(0)} Online'
                        : 'Pay ₹${record.finalAmount.toStringAsFixed(0)} Online',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final FeeRecordModel record;
  final VoidCallback onRemind;
  final VoidCallback onWaive;
  final VoidCallback onRefund;

  const _QuickActions({
    required this.record,
    required this.onRemind,
    required this.onWaive,
    required this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];

    if (!record.isPaid && !record.isWaived) {
      actions.add(
        _ActionButton(
          icon: Icons.notifications_outlined,
          label: 'Remind',
          onTap: onRemind,
        ),
      );
      actions.add(const SizedBox(width: 12));
      actions.add(
        _ActionButton(
          icon: Icons.remove_circle_outline,
          label: 'Waive',
          onTap: onWaive,
        ),
      );
    }

    if (record.paidAmount > 0) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 12));
      actions.add(
        _ActionButton(
          icon: Icons.keyboard_return_rounded,
          label: 'Refund',
          onTap: onRefund,
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Row(children: actions);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.softGrey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.mutedOlive.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.darkOlive, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkOlive,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
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
    final isInclusive = record.taxType == 'GST_INCLUSIVE';
    final isExclusive = record.taxType == 'GST_EXCLUSIVE';
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
          // ── Line items replace Base Amount when present ──
          if (record.lineItems.isNotEmpty) ...[
            ...record.lineItems.map(
              (item) => _Row(item.label, '₹${item.amount.toStringAsFixed(0)}'),
            ),
            _Row(
              'Subtotal',
              '₹${record.baseAmount.toStringAsFixed(0)}',
              bold: true,
            ),
          ] else
            _Row('Base Amount', '₹${record.baseAmount.toStringAsFixed(0)}'),
          // ── Discount ──
          if (record.discountAmount > 0)
            _Row(
              'Discount',
              '- ₹${record.discountAmount.toStringAsFixed(0)}',
              color: const Color(0xFF2E7D32),
            ),
          // ── Late Fine ──
          if (record.fineAmount > 0)
            _Row(
              'Late Fine',
              '+ ₹${record.fineAmount.toStringAsFixed(0)}',
              color: const Color(0xFFC62828),
            ),
          // ── GST_EXCLUSIVE: show taxable base + additive GST above total ──
          if (record.hasTax && isExclusive) ...[
            if (record.discountAmount > 0)
              _Row(
                'After Discount',
                '₹${(record.baseAmount - record.discountAmount).toStringAsFixed(0)}',
              ),
            const Divider(height: 16),
            _Row(
              'GST @ ${record.gstRate.toStringAsFixed(0)}%',
              '+ ₹${record.taxAmount.toStringAsFixed(0)}',
            ),
            if (record.cgstAmount > 0)
              _Row(
                '  CGST @ ${(record.gstRate / 2).toStringAsFixed(1)}%',
                '₹${record.cgstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.sgstAmount > 0)
              _Row(
                '  SGST @ ${(record.gstRate / 2).toStringAsFixed(1)}%',
                '₹${record.sgstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.igstAmount > 0)
              _Row(
                '  IGST @ ${record.gstRate.toStringAsFixed(1)}%',
                '₹${record.igstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.cessAmount > 0)
              _Row(
                '  Cess',
                '₹${record.cessAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
          ],
          // ── Total ──
          const Divider(height: 20),
          _Row(
            'Total',
            '₹${record.finalAmount.toStringAsFixed(0)}',
            bold: true,
          ),
          // ── GST_INCLUSIVE: informational sub-rows after total ──
          // GST is already inside the Total — shown for transparency only.
          if (record.hasTax && isInclusive) ...[
            _Row(
              '  incl. GST ${record.gstRate.toStringAsFixed(0)}%',
              '₹${record.taxAmount.toStringAsFixed(0)}',
              color: AppColors.mutedOlive,
            ),
            if (record.cgstAmount > 0)
              _Row(
                '  CGST @ ${(record.gstRate / 2).toStringAsFixed(1)}%',
                '₹${record.cgstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.sgstAmount > 0)
              _Row(
                '  SGST @ ${(record.gstRate / 2).toStringAsFixed(1)}%',
                '₹${record.sgstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.igstAmount > 0)
              _Row(
                '  IGST @ ${record.gstRate.toStringAsFixed(1)}%',
                '₹${record.igstAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
            if (record.cessAmount > 0)
              _Row(
                '  incl. Cess',
                '₹${record.cessAmount.toStringAsFixed(0)}',
                color: AppColors.mutedOlive,
              ),
          ],
          if (record.hasTax && record.sacCode != null)
            _Row('SAC Code', record.sacCode!),
          // ── Paid / Balance ──
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
  final String coachingName;
  final FeeRecordModel record;
  const _PaymentHistory({
    required this.payments,
    required this.coachingName,
    required this.record,
  });
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
        ...payments.map(
          (p) => _PaymentRow(
            payment: p,
            coachingName: coachingName,
            record: record,
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final FeePaymentModel payment;
  final String coachingName;
  final FeeRecordModel record;
  const _PaymentRow({
    required this.payment,
    required this.coachingName,
    required this.record,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentReceiptScreen(
            coachingName: coachingName,
            feeTitle: record.title,
            amount: payment.amount,
            paymentId: payment.razorpayPaymentId,
            orderId: payment.razorpayOrderId,
            paidAt: payment.paidAt,
            receiptNo: payment.receiptNo ?? '',
            paymentMode: payment.mode,
            transactionRef: payment.transactionRef,
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
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.softGrey.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.primaryGreen,
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
                color: AppColors.primaryGreen,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.mutedOlive,
              size: 16,
            ),
          ],
        ),
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
        color: AppColors.softGrey.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.keyboard_return_rounded,
            color: AppColors.darkOlive,
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
              color: AppColors.darkOlive,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedAttempts extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _FailedAttempts({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Failed Attempts',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
          ),
        ),
        const SizedBox(height: 10),
        ...orders.map((o) {
          final paise = (o['amountPaise'] as num?)?.toInt() ?? 0;
          final amtStr = '₹${(paise / 100).toStringAsFixed(0)}';
          final reason =
              (o['failureReason'] as String?)?.replaceFirst(
                'Exception: ',
                '',
              ) ??
              'Unknown reason';
          final failedAt = o['failedAt'] != null
              ? DateTime.tryParse(o['failedAt'] as String)
              : null;
          final dateStr = failedAt != null
              ? '${failedAt.day} ${_monthName(failedAt.month)} '
                    '${failedAt.hour.toString().padLeft(2, '0')}:'
                    '${failedAt.minute.toString().padLeft(2, '0')}'
              : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.softGrey.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cancel_rounded,
                  color: Color(0xFFC62828),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedOlive,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  amtStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC62828),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static String _monthName(int m) {
    const months = [
      '',
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
    return months[m];
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _modeIcon(m),
                        size: 13,
                        color: sel ? AppColors.cream : AppColors.darkOlive,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _modeLabel(m),
                        style: TextStyle(
                          color: sel ? AppColors.cream : AppColors.darkOlive,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'ONLINE':
        return 'Online';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      case 'OTHER':
        return 'Other';
      default:
        return m;
    }
  }

  IconData _modeIcon(String m) {
    switch (m) {
      case 'CASH':
        return Icons.payments_rounded;
      case 'UPI':
        return Icons.qr_code_rounded;
      case 'ONLINE':
        return Icons.credit_card_rounded;
      case 'BANK_TRANSFER':
        return Icons.account_balance_rounded;
      case 'CHEQUE':
        return Icons.receipt_long_rounded;
      default:
        return Icons.more_horiz_rounded;
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

// ── Installment amount picker bottom sheet ──────────────────────────────────

class _InstallmentPickerSheet extends StatelessWidget {
  final List<InstallmentAmountItem> fixedItems;
  final int installmentCount;
  final double balance;
  final double paidAmount;
  final void Function(double? amount) onSelected;

  const _InstallmentPickerSheet({
    required this.fixedItems,
    required this.installmentCount,
    required this.balance,
    required this.paidAmount,
    required this.onSelected,
  });

  double get _totalAmount => balance + paidAmount;

  /// All options computed from the FULL fee (not just remaining balance).
  /// Paid installments are included so they can be shown as ticked.
  List<InstallmentAmountItem> get _options {
    if (fixedItems.isNotEmpty) return fixedItems;
    if (installmentCount > 0) {
      final total = _totalAmount;
      final per = (total / installmentCount * 100).ceilToDouble() / 100;
      return List.generate(installmentCount, (i) {
        final isLast = i == installmentCount - 1;
        final amt = isLast ? total - per * i : per;
        return InstallmentAmountItem(
          label: 'Installment ${i + 1} of $installmentCount',
          amount: amt > 0 ? amt : 0,
        );
      });
    }
    return [];
  }

  /// Returns whether option at [index] has already been paid.
  /// Uses cumulative sum of options vs. paidAmount.
  bool _isPaid(List<InstallmentAmountItem> options, int index) {
    double cumulative = 0;
    for (int i = 0; i <= index; i++) {
      cumulative += options[i].amount;
    }
    return paidAmount >= cumulative - 0.01;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
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
            'Choose Payment Option',
            style: TextStyle(
              color: AppColors.darkOlive,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Outstanding balance: ₹${balance.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.mutedOlive, fontSize: 12),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              options.length == installmentCount && fixedItems.isEmpty
                  ? 'Split into $installmentCount equal installments'
                  : '${options.length} payment options available',
              style: const TextStyle(
                color: AppColors.mutedOlive,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Installment options
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final paid = _isPaid(options, i);
            // An option is payable if not already paid and its amount ≤ balance
            final isPayable = !paid && item.amount <= balance + 0.01;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: isPayable
                    ? () {
                        Navigator.pop(context);
                        onSelected(item.amount);
                      }
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: paid
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.07)
                        : isPayable
                        ? AppColors.darkOlive.withValues(alpha: 0.07)
                        : AppColors.softGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: paid
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
                          : isPayable
                          ? AppColors.darkOlive.withValues(alpha: 0.25)
                          : AppColors.softGrey,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: paid
                                ? const Color(0xFF2E7D32)
                                : isPayable
                                ? AppColors.darkOlive
                                : AppColors.mutedOlive,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '₹${item.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: paid
                              ? const Color(0xFF2E7D32)
                              : isPayable
                              ? AppColors.darkOlive
                              : AppColors.mutedOlive,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (paid)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Color(0xFF2E7D32),
                        )
                      else if (!isPayable)
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.mutedOlive,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Divider(height: 16),
          // Pay full balance option
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.darkOlive,
              side: const BorderSide(color: AppColors.darkOlive),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onSelected(null); // null = pay full balance
            },
            child: Text(
              'Pay Full Balance  ₹${balance.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
