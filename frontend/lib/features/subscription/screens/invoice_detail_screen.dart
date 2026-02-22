import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';
import '../models/invoice_model.dart';

/// Full invoice / receipt screen showing complete payment details.
class InvoiceDetailScreen extends StatelessWidget {
  final InvoiceModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    final (
      Color statusColor,
      IconData statusIcon,
      String statusText,
    ) = switch (invoice.status) {
      'PAID' => (Colors.green.shade700, Icons.check_circle_rounded, 'Paid'),
      'FAILED' => (cs.error, Icons.cancel_rounded, 'Failed'),
      'REFUNDED' => (cs.tertiary, Icons.replay_rounded, 'Refunded'),
      'PENDING' => (
        cs.onSurface.withValues(alpha: 0.5),
        Icons.pending_rounded,
        'Pending',
      ),
      _ => (
        cs.onSurface.withValues(alpha: 0.5),
        Icons.help_outline_rounded,
        invoice.status,
      ),
    };

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Invoice Details'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp24,
          Spacing.sp8,
          Spacing.sp24,
          Spacing.sp48,
        ),
        child: Column(
          children: [
            // ── Status header ──────────────────────────────────────
            const SizedBox(height: Spacing.sp16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 32),
            ),
            const SizedBox(height: Spacing.sp12),
            Text(
              statusText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              _typeLabel(invoice.type),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),

            // ── Amount ─────────────────────────────────────────────
            const SizedBox(height: Spacing.sp24),
            Text(
              '\u20B9${invoice.totalRupees.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),

            // ── Details card ───────────────────────────────────────
            const SizedBox(height: Spacing.sp24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sp20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Plan',
                    value: _planLabel(invoice.planSlug),
                  ),
                  _divider(cs),
                  _DetailRow(
                    label: 'Billing Cycle',
                    value: invoice.billingCycle == 'YEARLY'
                        ? 'Yearly'
                        : 'Monthly',
                  ),
                  _divider(cs),
                  _DetailRow(
                    label: 'Subtotal',
                    value: '\u20B9${invoice.amountRupees.toStringAsFixed(2)}',
                  ),
                  if (invoice.creditAppliedPaise > 0) ...[
                    _divider(cs),
                    _DetailRow(
                      label: 'Credits Applied',
                      value:
                          '- \u20B9${invoice.creditAppliedRupees.toStringAsFixed(2)}',
                      valueColor: Colors.green.shade700,
                    ),
                  ],
                  if (invoice.taxPaise > 0) ...[
                    _divider(cs),
                    _DetailRow(
                      label: 'Tax (GST)',
                      value: '\u20B9${invoice.taxRupees.toStringAsFixed(2)}',
                    ),
                  ],
                  _divider(cs),
                  _DetailRow(
                    label: invoice.creditAppliedPaise > 0
                        ? 'Amount Charged'
                        : 'Total',
                    value: '\u20B9${invoice.totalRupees.toStringAsFixed(2)}',
                    isBold: true,
                  ),
                ],
              ),
            ),

            // ── Payment info card ──────────────────────────────────
            const SizedBox(height: Spacing.sp16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sp20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  if (invoice.invoiceNumber != null) ...[
                    _DetailRow(
                      label: 'Invoice No.',
                      value: invoice.invoiceNumber!,
                    ),
                    _divider(cs),
                  ],
                  _DetailRow(
                    label: 'Date',
                    value: df.format(
                      invoice.paidAt ?? invoice.failedAt ?? invoice.createdAt,
                    ),
                  ),
                  if (invoice.razorpayPaymentId != null) ...[
                    _divider(cs),
                    _DetailRow(
                      label: 'Payment ID',
                      value: invoice.razorpayPaymentId!,
                      canCopy: true,
                    ),
                  ],
                  _divider(cs),
                  _DetailRow(label: 'Currency', value: invoice.currency),
                ],
              ),
            ),

            // ── Notes ──────────────────────────────────────────────
            if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
              const SizedBox(height: Spacing.sp16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.sp20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontSize: FontSize.micro,
                      ),
                    ),
                    const SizedBox(height: Spacing.sp4),
                    Text(invoice.notes!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Spacing.sp10),
    child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),
  );

  String _typeLabel(String type) => switch (type) {
    'INITIAL' => 'First Payment',
    'RENEWAL' => 'Renewal Payment',
    'UPGRADE' => 'Plan Upgrade',
    'REFUND' => 'Refund',
    _ => type,
  };

  String _planLabel(String? slug) => switch (slug) {
    'basic' => 'Basic',
    'standard' => 'Standard',
    'premium' => 'Premium',
    'free' => 'Free',
    _ => slug?.toUpperCase() ?? '—',
  };
}

// ── Detail Row widget ────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool canCopy;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.canCopy = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
            fontSize: FontSize.caption,
          ),
        ),
        const SizedBox(width: Spacing.sp16),
        Flexible(
          child: canCopy
              ? GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    AppAlert.success(context, 'Copied to clipboard');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isBold
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: FontSize.caption,
                            color: valueColor,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Spacing.sp4),
                      Icon(
                        Icons.copy_rounded,
                        size: 12,
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                )
              : Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    fontSize: FontSize.caption,
                    color: valueColor,
                  ),
                  textAlign: TextAlign.end,
                ),
        ),
      ],
    );
  }
}
