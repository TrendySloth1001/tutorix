import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';

/// A clean, minimal payment receipt shown after successful online payment.
/// Also accessible from payment history in both admin and student views.
class PaymentReceiptScreen extends StatelessWidget {
  final String coachingName;
  final String feeTitle;
  final double amount;
  final String paymentId;
  final String orderId;
  final DateTime paidAt;
  final String? studentName;
  final String receiptNo;

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
    required this.paymentId,
    required this.orderId,
    required this.paidAt,
    this.studentName,
    required this.receiptNo,
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

  bool get _hasTax => taxType != 'NONE' && taxAmount > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.darkOlive),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Receipt',
          style: TextStyle(
            color: AppColors.darkOlive,
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
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF2E7D32),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(paidAt),
              style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // ─── Amount ───
            Text(
              '₹${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 36,
                color: AppColors.darkOlive,
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
                  _DetailRow('Payment Mode', 'Razorpay'),
                  _Divider(),
                  _DetailRow('Order ID', _truncateId(orderId)),
                  _Divider(),
                  _DetailRow('Payment ID', _truncateId(paymentId)),
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
                    const Text(
                      'Amount Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkOlive,
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
                    if (discountAmount != null && discountAmount! > 0 &&
                        taxType == 'GST_EXCLUSIVE' && _hasTax) ...[
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
                        _DetailRow('  Cess', '₹${cessAmount.toStringAsFixed(2)}'),
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
                        _DetailRow('  incl. Cess', '₹${cessAmount.toStringAsFixed(2)}'),
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
                      foregroundColor: AppColors.darkOlive,
                      side: BorderSide(
                        color: AppColors.mutedOlive.withValues(alpha: 0.3),
                      ),
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
                      backgroundColor: AppColors.darkOlive,
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
    lines.addAll([
      'Payment Mode: Razorpay',
      'Order ID: $orderId',
      'Payment ID: $paymentId',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.darkOlive,
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
    return Divider(height: 1, color: AppColors.softGrey.withValues(alpha: 0.5));
  }
}
