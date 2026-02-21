import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A clean, minimal payment receipt shown after successful payment.
/// Works for all payment modes: Razorpay (online), Cash, UPI, Bank Transfer,
/// Cheque, Credit Transfer, and others.
/// Also accessible from payment history in both admin and student views.
class PaymentReceiptScreen extends StatelessWidget {
  final String coachingName;
  final String feeTitle;
  final double amount;

  /// Razorpay payment ID — null for non-Razorpay modes.
  final String? paymentId;

  /// Razorpay order ID — null for non-Razorpay modes.
  final String? orderId;
  final DateTime paidAt;
  final String? studentName;
  final String receiptNo;

  /// Payment mode string, e.g. 'RAZORPAY', 'CASH', 'UPI', 'BANK_TRANSFER',
  /// 'CHEQUE', 'CREDIT_TRANSFER', 'ONLINE', 'OTHER'.
  /// Defaults to 'RAZORPAY' for backward compatibility.
  final String paymentMode;

  /// Reference number for non-Razorpay modes (UPI ID, cheque no, etc.).
  final String? transactionRef;

  // Tax breakdown (optional)
  final String taxType; // NONE | GST_INCLUSIVE | GST_EXCLUSIVE
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double cessAmount;
  final double gstRate;
  final String? sacCode;
  final String? gstNumber; // coaching GSTIN
  final double? baseAmount; // pre-tax amount
  final double? discountAmount;
  final double? fineAmount;

  const PaymentReceiptScreen({
    super.key,
    required this.coachingName,
    required this.feeTitle,
    required this.amount,
    this.paymentId,
    this.orderId,
    required this.paidAt,
    this.studentName,
    required this.receiptNo,
    this.paymentMode = 'RAZORPAY',
    this.transactionRef,
    this.taxType = 'NONE',
    this.taxAmount = 0,
    this.cgstAmount = 0,
    this.sgstAmount = 0,
    this.igstAmount = 0,
    this.cessAmount = 0,
    this.gstRate = 0,
    this.sacCode,
    this.gstNumber,
    this.baseAmount,
    this.discountAmount,
    this.fineAmount,
  });

  bool get _isRazorpay =>
      paymentMode == 'RAZORPAY' || paymentMode == 'ONLINE' || paymentId != null;

  String get _modeLabel {
    switch (paymentMode) {
      case 'RAZORPAY':
      case 'ONLINE':
        return 'Razorpay';
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'CHEQUE':
        return 'Cheque';
      case 'CREDIT_TRANSFER':
        return 'Credit Transfer';
      default:
        return paymentMode;
    }
  }

  String get _successLabel =>
      _isRazorpay ? 'Payment Successful' : 'Payment Recorded';

  bool get _hasTax => taxType != 'NONE' && taxAmount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Receipt',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // ─── Success Icon ───
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: theme.colorScheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _successLabel,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(paidAt),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Amount ───
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 36,
                color: theme.colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 32),

            // ─── Receipt Details ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow('Receipt No', receiptNo),
                  _Divider(),
                  _DetailRow('Fee', feeTitle),
                  _Divider(),
                  _DetailRow('Institute', coachingName),
                  if (gstNumber != null && gstNumber!.isNotEmpty) ...[
                    _Divider(),
                    _DetailRow('GSTIN', gstNumber!),
                  ],
                  if (studentName != null) ...[
                    _Divider(),
                    _DetailRow('Student', studentName!),
                  ],
                  _Divider(),
                  _DetailRow('Payment Mode', _modeLabel),
                  if (transactionRef != null && transactionRef!.isNotEmpty) ...[
                    _Divider(),
                    _DetailRow('Reference', transactionRef!),
                  ],
                  if (_isRazorpay &&
                      orderId != null &&
                      orderId!.isNotEmpty) ...[
                    _Divider(),
                    _DetailRow('Order ID', _truncateId(orderId!)),
                  ],
                  if (_isRazorpay &&
                      paymentId != null &&
                      paymentId!.isNotEmpty) ...[
                    _Divider(),
                    _DetailRow('Payment ID', _truncateId(paymentId!)),
                  ],
                ],
              ),
            ),

            // ─── Amount Breakdown ───
            if (baseAmount != null || _hasTax) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (baseAmount != null)
                      _DetailRow(
                        'Base Amount',
                        '₹${baseAmount!.toStringAsFixed(2)}',
                      ),
                    if (discountAmount != null && discountAmount! > 0) ...[
                      _Divider(),
                      _DetailRow(
                        'Discount',
                        '- ₹${discountAmount!.toStringAsFixed(2)}',
                      ),
                    ],
                    // After-discount row: makes taxable base transparent for exclusive GST
                    if (discountAmount != null &&
                        discountAmount! > 0 &&
                        taxType == 'GST_EXCLUSIVE' &&
                        _hasTax) ...[
                      _Divider(),
                      _DetailRow(
                        'After Discount',
                        '₹${(baseAmount! - discountAmount!).toStringAsFixed(2)}',
                      ),
                    ],
                    if (fineAmount != null && fineAmount! > 0) ...[
                      _Divider(),
                      _DetailRow(
                        'Late Fine',
                        '+ ₹${fineAmount!.toStringAsFixed(2)}',
                      ),
                    ],
                    // GST_EXCLUSIVE: shown as additive above total
                    if (_hasTax && taxType == 'GST_EXCLUSIVE') ...[
                      _Divider(),
                      _DetailRow(
                        'GST @ ${gstRate.toStringAsFixed(0)}%',
                        '+ ₹${taxAmount.toStringAsFixed(2)}',
                      ),
                      if (cgstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  CGST @ ${(gstRate / 2).toStringAsFixed(1)}%',
                          '₹${cgstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (sgstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  SGST @ ${(gstRate / 2).toStringAsFixed(1)}%',
                          '₹${sgstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (igstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  IGST @ ${gstRate.toStringAsFixed(1)}%',
                          '₹${igstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (cessAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  Cess',
                          '₹${cessAmount.toStringAsFixed(2)}',
                        ),
                      ],
                    ],
                    if (sacCode != null && sacCode!.isNotEmpty) ...[
                      _Divider(),
                      _DetailRow('SAC Code', sacCode!),
                    ],
                    _Divider(),
                    _DetailRow('Total Paid', '₹${amount.toStringAsFixed(2)}'),
                    // GST_INCLUSIVE: tax shown as informational sub-rows after total
                    if (_hasTax && taxType == 'GST_INCLUSIVE') ...[
                      _Divider(),
                      _DetailRow(
                        '  incl. GST @ ${gstRate.toStringAsFixed(0)}%',
                        '₹${taxAmount.toStringAsFixed(2)}',
                      ),
                      if (cgstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  incl. CGST @ ${(gstRate / 2).toStringAsFixed(1)}%',
                          '₹${cgstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (sgstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  incl. SGST @ ${(gstRate / 2).toStringAsFixed(1)}%',
                          '₹${sgstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (igstAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  incl. IGST @ ${gstRate.toStringAsFixed(1)}%',
                          '₹${igstAmount.toStringAsFixed(2)}',
                        ),
                      ],
                      if (cessAmount > 0) ...[
                        _Divider(),
                        _DetailRow(
                          '  incl. Cess',
                          '₹${cessAmount.toStringAsFixed(2)}',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ─── Actions ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyReceipt(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Copy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _copyReceipt(BuildContext context) {
    final lines = <String>[
      'Payment Receipt — $coachingName',
      '━━━━━━━━━━━━━━━━━━━━━━━━',
      'Receipt: $receiptNo',
      'Amount: ₹${amount.toStringAsFixed(2)}',
      'Fee: $feeTitle',
      'Institute: $coachingName',
    ];
    if (gstNumber != null && gstNumber!.isNotEmpty) {
      lines.add('GSTIN: $gstNumber');
    }
    if (studentName != null) lines.add('Student: $studentName');
    if (_hasTax) {
      lines.add(
        'Tax (GST ${gstRate.toStringAsFixed(0)}%): ₹${taxAmount.toStringAsFixed(2)}',
      );
      if (cgstAmount > 0)
        lines.add('  CGST: ₹${cgstAmount.toStringAsFixed(2)}');
      if (sgstAmount > 0)
        lines.add('  SGST: ₹${sgstAmount.toStringAsFixed(2)}');
      if (igstAmount > 0)
        lines.add('  IGST: ₹${igstAmount.toStringAsFixed(2)}');
      if (cessAmount > 0)
        lines.add('  Cess: ₹${cessAmount.toStringAsFixed(2)}');
    }
    lines.add('Payment Mode: $_modeLabel');
    if (transactionRef != null && transactionRef!.isNotEmpty) {
      lines.add('Reference: $transactionRef');
    }
    if (_isRazorpay && orderId != null && orderId!.isNotEmpty) {
      lines.add('Order ID: $orderId');
    }
    if (_isRazorpay && paymentId != null && paymentId!.isNotEmpty) {
      lines.add('Payment ID: $paymentId');
    }
    lines.addAll([
      'Date: ${_formatDateTime(paidAt)}',
      '━━━━━━━━━━━━━━━━━━━━━━━━',
    ]);

    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt copied to clipboard')),
    );
  }

  String _truncateId(String id) {
    if (id.length <= 20) return id;
    return '${id.substring(0, 18)}…';
  }

  String _formatDateTime(DateTime dt) {
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
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$min $amPm';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
