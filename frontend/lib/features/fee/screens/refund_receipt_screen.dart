import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutorix/core/constants/error_strings.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';

/// A clean, minimal refund receipt screen shown after a refund is processed.
/// Works for both manual (Cash, UPI, Bank Transfer, Cheque) and online
/// (Razorpay) refunds. Accessible from admin, parent, and student views.
class RefundReceiptScreen extends StatelessWidget {
  final String coachingName;
  final String feeTitle;
  final double amount;
  final DateTime refundedAt;
  final String? studentName;
  final String refundMode; // CASH, UPI, BANK_TRANSFER, CHEQUE, RAZORPAY
  final String? reason;

  /// Admin who processed the refund.
  final String? processedByName;

  /// Razorpay refund ID — null for manual refunds.
  final String? razorpayRefundId;

  /// The original Razorpay payment ID that was refunded.
  final String? razorpayPaymentId;

  /// Razorpay refund status: INITIATED | PROCESSED | FAILED.
  final String? razorpayStatus;

  const RefundReceiptScreen({
    super.key,
    required this.coachingName,
    required this.feeTitle,
    required this.amount,
    required this.refundedAt,
    this.studentName,
    this.refundMode = 'CASH',
    this.reason,
    this.processedByName,
    this.razorpayRefundId,
    this.razorpayPaymentId,
    this.razorpayStatus,
  });

  bool get _isOnline =>
      refundMode == 'RAZORPAY' ||
      refundMode == 'ONLINE' ||
      razorpayRefundId != null;

  String get _modeLabel {
    switch (refundMode) {
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
      default:
        return refundMode;
    }
  }

  String get _statusLabel {
    switch (razorpayStatus) {
      case 'INITIATED':
        return 'Processing';
      case 'PROCESSED':
        return 'Completed';
      case 'FAILED':
        return 'Failed';
      default:
        return 'Completed';
    }
  }

  Color _statusColor(ThemeData theme) {
    switch (razorpayStatus) {
      case 'INITIATED':
        return Colors.orange;
      case 'FAILED':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData get _headerIcon {
    switch (razorpayStatus) {
      case 'INITIATED':
        return Icons.schedule_rounded;
      case 'FAILED':
        return Icons.error_outline_rounded;
      default:
        return Icons.check_rounded;
    }
  }

  String get _headerLabel {
    if (_isOnline) {
      switch (razorpayStatus) {
        case 'INITIATED':
          return 'Refund Processing';
        case 'FAILED':
          return 'Refund Failed';
        default:
          return 'Refund Successful';
      }
    }
    return 'Refund Recorded';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusClr = _statusColor(theme);
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
          'Refund Receipt',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: FontSize.sub,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sp24,
          vertical: Spacing.sp16,
        ),
        child: Column(
          children: [
            const SizedBox(height: Spacing.sp8),
            // ─── Status Icon ───
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: statusClr.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_headerIcon, color: statusClr, size: 40),
            ),
            const SizedBox(height: Spacing.sp16),
            Text(
              _headerLabel,
              style: TextStyle(
                color: statusClr,
                fontWeight: FontWeight.w700,
                fontSize: FontSize.title,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              _formatDateTime(refundedAt),
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp32),

            // ─── Amount (debit) ───
            Text(
              '- ₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: FontSize.hero,
                color: theme.colorScheme.error,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sp12,
                vertical: Spacing.sp4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                'DEBIT',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                  fontSize: FontSize.caption,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: Spacing.sp32),

            // ─── Refund Details ───
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sp20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              child: Column(
                children: [
                  _DetailRow('Fee', feeTitle),
                  const _Divider(),
                  _DetailRow('Institute', coachingName),
                  if (studentName != null) ...[
                    const _Divider(),
                    _DetailRow('Student', studentName!),
                  ],
                  const _Divider(),
                  _DetailRow('Refund Mode', _modeLabel),
                  const _Divider(),
                  _DetailRow('Status', _statusLabel),
                  if (processedByName != null &&
                      processedByName!.isNotEmpty) ...[
                    const _Divider(),
                    _DetailRow('Processed By', processedByName!),
                  ],
                  if (reason != null && reason!.isNotEmpty) ...[
                    const _Divider(),
                    _DetailRow('Reason', reason!),
                  ],
                  if (_isOnline &&
                      razorpayRefundId != null &&
                      razorpayRefundId!.isNotEmpty) ...[
                    const _Divider(),
                    _DetailRow('Refund ID', _truncateId(razorpayRefundId!)),
                  ],
                  if (_isOnline &&
                      razorpayPaymentId != null &&
                      razorpayPaymentId!.isNotEmpty) ...[
                    const _Divider(),
                    _DetailRow(
                      'Original Payment',
                      _truncateId(razorpayPaymentId!),
                    ),
                  ],
                ],
              ),
            ),

            // ─── Status Note for INITIATED ───
            if (_isOnline && razorpayStatus == 'INITIATED') ...[
              const SizedBox(height: Spacing.sp16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.sp16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: Spacing.sp12),
                    Expanded(
                      child: Text(
                        'Razorpay is processing this refund. It may take 5–7 business days to reflect in the original payment method.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: FontSize.caption,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: Spacing.sp24),

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
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.sp14,
                      ),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Copy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.sp14,
                      ),
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
            const SizedBox(height: Spacing.sp32),
          ],
        ),
      ),
    );
  }

  void _copyReceipt(BuildContext context) {
    final lines = <String>[
      'Refund Receipt — $coachingName',
      '━━━━━━━━━━━━━━━━━━━━━━━━',
      'Amount: ₹${amount.toStringAsFixed(2)} (DEBIT)',
      'Fee: $feeTitle',
      'Institute: $coachingName',
    ];
    if (studentName != null) lines.add('Student: $studentName');
    lines.add('Refund Mode: $_modeLabel');
    lines.add('Status: $_statusLabel');
    if (processedByName != null) lines.add('Processed By: $processedByName');
    if (reason != null && reason!.isNotEmpty) lines.add('Reason: $reason');
    if (_isOnline && razorpayRefundId != null) {
      lines.add('Refund ID: $razorpayRefundId');
    }
    if (_isOnline && razorpayPaymentId != null) {
      lines.add('Original Payment: $razorpayPaymentId');
    }
    lines.addAll([
      'Date: ${_formatDateTime(refundedAt)}',
      '━━━━━━━━━━━━━━━━━━━━━━━━',
    ]);

    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (context.mounted) AppAlert.success(context, FeeSuccess.receiptCopied);
  }

  String _truncateId(String id) {
    if (id.length <= 20) return id;
    return '${id.substring(0, 18)}…';
  }

  String _formatDateTime(DateTime dt) {
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
      padding: const EdgeInsets.symmetric(vertical: Spacing.sp10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.body,
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
                fontSize: FontSize.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
