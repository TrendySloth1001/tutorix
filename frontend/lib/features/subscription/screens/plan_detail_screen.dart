import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/app_alert.dart';
import '../models/plan_model.dart';
import '../services/subscription_service.dart';

/// Dedicated plan detail + purchase screen.
///
/// Shows full feature breakdown, a mandatory purchase-policy acceptance
/// checkbox, and a confirmation bottom sheet before initiating the
/// Razorpay checkout flow.
class PlanDetailScreen extends StatefulWidget {
  final PlanModel plan;
  final String coachingId;
  final bool yearly;

  const PlanDetailScreen({
    super.key,
    required this.plan,
    required this.coachingId,
    required this.yearly,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen>
    with WidgetsBindingObserver {
  final _service = SubscriptionService.instance;
  bool _policyAccepted = false;
  bool _isSubscribing = false;
  bool _awaitingPayment = false; // true while user is in the browser paying
  StreamSubscription<Uri>? _linkSub;

  PlanModel get plan => widget.plan;
  bool get yearly => widget.yearly;

  // ── Helpers ───────────────────────────────────────────────────────

  String get _priceLabel {
    if (plan.isFree) return '\u20B90';
    return yearly
        ? '\u20B9${plan.effectiveMonthlyRupees.toStringAsFixed(0)}/mo'
        : '\u20B9${plan.priceMonthly.toStringAsFixed(0)}/mo';
  }

  String get _billedLabel {
    if (plan.isFree) return 'Free forever';
    return yearly
        ? 'Billed \u20B9${plan.priceYearly.toStringAsFixed(0)}/year'
        : 'Billed monthly';
  }

  // ── Subscribe flow ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for deep link callbacks (tutorix://subscription/payment-complete)
    final appLinks = AppLinks();
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      if (!mounted || !_awaitingPayment) return;
      if (uri.scheme == 'tutorix' &&
          uri.host == 'subscription' &&
          uri.path.contains('payment-complete')) {
        _awaitingPayment = false;
        _verifyPayment();
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the user returns from the payment browser, verify payment.
    if (state == AppLifecycleState.resumed && _awaitingPayment) {
      _awaitingPayment = false;
      _verifyPayment();
    }
  }

  Future<void> _onBuyPressed() async {
    if (!_policyAccepted || _isSubscribing) return;

    // Show confirmation bottom sheet
    final confirmed = await _showConfirmationSheet();
    if (confirmed != true || !mounted) return;

    setState(() => _isSubscribing = true);
    try {
      final result = await _service.subscribe(
        coachingId: widget.coachingId,
        planSlug: plan.slug,
        cycle: yearly ? 'YEARLY' : 'MONTHLY',
      );
      if (!mounted) return;

      final uri = Uri.parse(result.shortUrl);
      final canOpen = await canLaunchUrl(uri);
      if (!mounted) return;

      if (canOpen) {
        _awaitingPayment = true;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Don't pop — wait for user to return, then verify in didChangeAppLifecycleState
      } else {
        AppAlert.error(context, 'Could not open payment page');
      }
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e, fallback: 'Failed to start subscription');
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  /// Called when the user returns from the payment browser.
  /// Polls the backend to check if payment completed, then pops with result.
  Future<void> _verifyPayment() async {
    if (!mounted) return;
    setState(() => _isSubscribing = true);

    try {
      // Give Razorpay a moment to process
      await Future.delayed(const Duration(seconds: 1));

      // Poll up to 3 times with 2-second gaps
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!mounted) return;

        final result = await _service.verifyPayment(widget.coachingId);

        if (result.activated) {
          if (!mounted) return;
          AppAlert.success(context, 'Payment successful! Plan activated.');
          Navigator.of(context).pop(true);
          return;
        }

        if (result.status == 'expired' || result.status == 'cancelled') {
          if (!mounted) return;
          AppAlert.error(
            context,
            'Payment link ${result.status}. Please try again.',
          );
          setState(() => _isSubscribing = false);
          return;
        }

        // Still pending — wait and retry
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      // After 3 attempts, still not paid
      if (!mounted) return;
      AppAlert.info(
        context,
        title: 'Payment Processing',
        message:
            'Payment is being processed. It may take a few moments. '
            'Please check back shortly.',
      );
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e, fallback: 'Could not verify payment');
    } finally {
      if (mounted) setState(() => _isSubscribing = false);
    }
  }

  Future<bool?> _showConfirmationSheet() {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final amount = yearly ? plan.priceYearly : plan.priceMonthly;
    final cycle = yearly ? 'year' : 'month';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp24,
              Spacing.sp8,
              Spacing.sp24,
              Spacing.sp24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.full),
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.sp24),

                // Confirmation icon
                Container(
                  padding: const EdgeInsets.all(Spacing.sp16),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 32,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: Spacing.sp20),

                Text(
                  'Confirm Purchase',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: Spacing.sp12),

                // Summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Spacing.sp16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Column(
                    children: [
                      _summaryRow(theme, 'Plan', plan.name),
                      const SizedBox(height: Spacing.sp8),
                      _summaryRow(
                        theme,
                        'Billing',
                        yearly ? 'Yearly' : 'Monthly',
                      ),
                      const SizedBox(height: Spacing.sp8),
                      Divider(
                        color: cs.primary.withValues(alpha: 0.08),
                        height: 1,
                      ),
                      const SizedBox(height: Spacing.sp8),
                      _summaryRow(
                        theme,
                        'Amount',
                        '\u20B9${amount.toStringAsFixed(0)}/$cycle',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.sp12),

                Text(
                  'You will be redirected to Razorpay to complete payment. '
                  'Your subscription will activate once payment is confirmed.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: Spacing.sp24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sp12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.lock_rounded, size: 16),
                        label: Text('Pay \u20B9${amount.toStringAsFixed(0)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(
    ThemeData theme,
    String label,
    String value, {
    bool isBold = false,
  }) {
    final cs = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isBold ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(plan.name), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.sp20,
          Spacing.sp8,
          Spacing.sp20,
          Spacing.sp120,
        ),
        children: [
          // ── Header ──────────────────────────────────────────────
          _buildPriceHeader(theme),
          const SizedBox(height: Spacing.sp24),

          // ── Quotas ──────────────────────────────────────────────
          _buildSectionTitle(theme, 'What You Get'),
          const SizedBox(height: Spacing.sp12),
          _buildQuotaSection(theme),
          const SizedBox(height: Spacing.sp24),

          // ── Features ────────────────────────────────────────────
          _buildSectionTitle(theme, 'Features Included'),
          const SizedBox(height: Spacing.sp12),
          _buildFeatureList(theme),
          const SizedBox(height: Spacing.sp24),

          // ── Policy ──────────────────────────────────────────────
          _buildPurchasePolicy(theme),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  // ── Price header ──────────────────────────────────────────────────

  Widget _buildPriceHeader(ThemeData theme) {
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.06),
            cs.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Plan badge
          if (plan.isPopular)
            Container(
              margin: const EdgeInsets.only(bottom: Spacing.sp12),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sp12,
                vertical: Spacing.sp4,
              ),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              child: Text(
                '\u2B50 Most Popular',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  fontSize: FontSize.micro,
                ),
              ),
            ),

          // Price
          Text(
            _priceLabel,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: Spacing.sp4),
          Text(
            _billedLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),

          if (yearly && plan.yearlySavingsPercent > 0) ...[
            const SizedBox(height: Spacing.sp8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sp10,
                vertical: Spacing.sp4,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
              child: Text(
                'Save ${plan.yearlySavingsPercent}% with yearly billing',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: FontSize.nano,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    );
  }

  // ── Quotas ────────────────────────────────────────────────────────

  Widget _buildQuotaSection(ThemeData theme) {
    final cs = theme.colorScheme;

    final quotas = <(IconData, String, String)>[
      (
        Icons.people_outline_rounded,
        'Students',
        plan.formatQuota(plan.maxStudents),
      ),
      (Icons.school_outlined, 'Teachers', plan.formatQuota(plan.maxTeachers)),
      (
        Icons.inventory_2_outlined,
        'Batches',
        plan.formatQuota(plan.maxBatches),
      ),
      (Icons.cloud_outlined, 'Storage', plan.storageLabel),
      (
        Icons.assignment_outlined,
        'Assessments / month',
        plan.formatQuota(plan.maxAssessmentsPerMonth),
      ),
      (
        Icons.person_outline_rounded,
        'Parents',
        plan.formatQuota(plan.maxParents),
      ),
      (
        Icons.admin_panel_settings_outlined,
        'Admins',
        plan.formatQuota(plan.maxAdmins),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < quotas.length; i++) ...[
            _quotaRow(theme, quotas[i].$1, quotas[i].$2, quotas[i].$3),
            if (i < quotas.length - 1)
              Divider(
                height: Spacing.sp16,
                color: cs.primary.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }

  Widget _quotaRow(ThemeData theme, IconData icon, String label, String value) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary.withValues(alpha: 0.6)),
        const SizedBox(width: Spacing.sp12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Feature list ──────────────────────────────────────────────────

  Widget _buildFeatureList(ThemeData theme) {
    final cs = theme.colorScheme;

    final allFeatures = <(String, bool)>[
      ('Online Payment Collection', plan.hasRazorpay),
      ('Auto Fee Reminders', plan.hasAutoRemind),
      ('Fee Reports & Analytics', plan.hasFeeReports),
      ('Fee Ledger Tracking', plan.hasFeeLedger),
      ('Route Payouts', plan.hasRoutePayouts),
      ('Push Notifications', plan.hasPushNotify),
      ('Email Notifications', plan.hasEmailNotify),
      ('SMS Notifications', plan.hasSmsNotify),
      ('WhatsApp Notifications', plan.hasWhatsappNotify),
      ('Custom Branding / Logo', plan.hasCustomLogo),
      ('White Label Solution', plan.hasWhiteLabel),
    ];

    return Container(
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < allFeatures.length; i++) ...[
            _featureRow(theme, allFeatures[i].$1, allFeatures[i].$2),
            if (i < allFeatures.length - 1)
              Divider(
                height: Spacing.sp16,
                color: cs.primary.withValues(alpha: 0.05),
              ),
          ],
        ],
      ),
    );
  }

  Widget _featureRow(ThemeData theme, String label, bool included) {
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(
          included ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 18,
          color: included
              ? Colors.green.shade600
              : cs.onSurface.withValues(alpha: 0.2),
        ),
        const SizedBox(width: Spacing.sp12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: included
                  ? cs.onSurface.withValues(alpha: 0.8)
                  : cs.onSurface.withValues(alpha: 0.35),
              decoration: included ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ],
    );
  }

  // ── Purchase policy ───────────────────────────────────────────────

  Widget _buildPurchasePolicy(ThemeData theme) {
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 18, color: cs.primary),
              const SizedBox(width: Spacing.sp8),
              Text(
                'Purchase Policy',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp12),
          _policyItem(
            theme,
            'Your subscription will auto-renew at the end of each '
            'billing cycle unless cancelled.',
          ),
          _policyItem(
            theme,
            'You can cancel anytime from the Subscription Dashboard. '
            'Cancellation applies at the end of the current billing period.',
          ),
          _policyItem(
            theme,
            'No refunds for partial billing periods. If you delete your '
            'coaching, 50% of the remaining subscription value will be '
            'credited to your account.',
          ),
          _policyItem(
            theme,
            'Plan downgrades take effect at the next billing cycle. '
            'Upgrades are applied immediately.',
          ),
          _policyItem(
            theme,
            'Tutorix reserves the right to modify plan pricing with '
            '30 days prior notice. Existing subscriptions will be '
            'honoured until renewal.',
          ),
          const SizedBox(height: Spacing.sp12),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _policyAccepted = !_policyAccepted);
            },
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _policyAccepted,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _policyAccepted = v ?? false);
                    },
                  ),
                ),
                const SizedBox(width: Spacing.sp8),
                Expanded(
                  child: Text(
                    'I have read and agree to the purchase policy',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyItem(ThemeData theme, String text) {
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.circle,
              size: 5,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(width: Spacing.sp8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                height: 1.5,
                fontSize: FontSize.nano,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────

  Widget _buildBottomBar(ThemeData theme) {
    final cs = theme.colorScheme;
    final amount = yearly ? plan.priceYearly : plan.priceMonthly;
    final cycle = yearly ? 'year' : 'month';

    return Container(
      padding: EdgeInsets.fromLTRB(
        Spacing.sp20,
        Spacing.sp12,
        Spacing.sp20,
        MediaQuery.of(context).padding.bottom + Spacing.sp12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!plan.isFree) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  '\u20B9${amount.toStringAsFixed(0)}/$cycle',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp12),
          ],
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _policyAccepted && !_isSubscribing
                  ? _onBuyPressed
                  : null,
              icon: _isSubscribing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : Icon(
                      _policyAccepted
                          ? Icons.lock_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                    ),
              label: Text(
                _isSubscribing
                    ? 'Processing...'
                    : _policyAccepted
                    ? 'Subscribe to ${plan.name}'
                    : 'Accept policy to continue',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: FontSize.body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
