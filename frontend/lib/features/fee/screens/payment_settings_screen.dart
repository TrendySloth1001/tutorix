import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../shared/widgets/app_alert.dart';

/// Admin screen for configuring coaching payment settings:
/// bank account, GSTIN, PAN — required for Razorpay Route transfers.
class PaymentSettingsScreen extends StatefulWidget {
  final String coachingId;
  const PaymentSettingsScreen({super.key, required this.coachingId});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _svc = PaymentService();
  final _formKey = GlobalKey<FormState>();

  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _activating = false;
  bool _refreshing = false;
  String? _error;
  String? _razorpayAccountId;
  bool _razorpayActivated = false;
  String? _onboardingStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getPaymentSettings(widget.coachingId);
      if (!mounted) return;
      setState(() {
        _gstCtrl.text = data['gstNumber'] as String? ?? '';
        _panCtrl.text = data['panNumber'] as String? ?? '';
        _bankNameCtrl.text = data['bankName'] as String? ?? '';
        _accNameCtrl.text = data['bankAccountName'] as String? ?? '';
        _accNumCtrl.text = data['bankAccountNumber'] as String? ?? '';
        _ifscCtrl.text = data['bankIfscCode'] as String? ?? '';
        _razorpayAccountId = data['razorpayAccountId'] as String?;
        _razorpayActivated = data['razorpayActivated'] as bool? ?? false;
        _onboardingStatus = data['razorpayOnboardingStatus'] as String?;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.updatePaymentSettings(
        widget.coachingId,
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim().isEmpty
            ? null
            : _bankNameCtrl.text.trim(),
        bankAccountName: _accNameCtrl.text.trim().isEmpty
            ? null
            : _accNameCtrl.text.trim(),
        bankAccountNumber: _accNumCtrl.text.trim().isEmpty
            ? null
            : _accNumCtrl.text.trim(),
        bankIfscCode: _ifscCtrl.text.trim().isEmpty
            ? null
            : _ifscCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Razorpay Route Linked Account ──────────────────────────────

  Future<void> _activateRoute() async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    // Validate bank details are filled
    if (_accNumCtrl.text.trim().isEmpty ||
        _ifscCtrl.text.trim().isEmpty ||
        _accNameCtrl.text.trim().isEmpty) {
      AppAlert.error(
        context,
        'Please save your bank details first (Account Number, IFSC, Account Holder Name)',
      );
      return;
    }

    final confirm = await AppAlert.confirm(
      context,
      title: 'Activate Razorpay Route',
      message:
          'This will create a linked account on Razorpay for receiving payments directly. '
          'Your bank details and PAN will be shared with Razorpay for KYC verification.\n\n'
          'Continue?',
      confirmText: 'Activate',
      cancelText: 'Cancel',
    );
    if (!confirm || !mounted) return;

    setState(() => _activating = true);
    try {
      final result = await _svc.createLinkedAccount(
        widget.coachingId,
        ownerName: user.name ?? 'Account Owner',
        ownerEmail: user.email,
        ownerPhone: (user.phone ?? '').replaceAll(RegExp(r'^\+91'), ''),
      );
      if (!mounted) return;

      final msg = result['message'] as String? ?? 'Linked account created';
      AppAlert.info(context, title: 'Route Activation', message: msg);
      _load(); // reload status
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    try {
      final result = await _svc.refreshLinkedAccountStatus(widget.coachingId);
      if (!mounted) return;

      final msg = result['message'] as String? ?? 'Status updated';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _deleteLinkedAccount() async {
    final confirm = await AppAlert.confirm(
      context,
      title: 'Remove Linked Account',
      message:
          'This will delete the Razorpay linked account. '
          'Payments will no longer be routed to your bank automatically.\n\n'
          'This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!confirm || !mounted) return;

    try {
      await _svc.deleteLinkedAccount(widget.coachingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linked account removed')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e);
    }
  }

  Widget _buildRouteStatusCard(ThemeData theme) {
    // No linked account yet — show activation CTA
    if (_razorpayAccountId == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.sp16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Razorpay Route Not Configured',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.secondary,
                          fontSize: FontSize.body,
                        ),
                      ),
                      Text(
                        'Activate to receive payments directly in your bank account',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: FontSize.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sp12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _activating ? null : _activateRoute,
                icon: _activating
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(
                  _activating
                      ? 'Creating linked account...'
                      : 'Activate Razorpay Route',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Linked account exists
    final isActive = _razorpayActivated;
    final isPending = _onboardingStatus == 'under_review' ||
        _onboardingStatus == 'needs_clarification';

    final Color statusColor;
    final IconData statusIcon;
    final String statusTitle;
    final String statusSubtitle;

    if (isActive) {
      statusColor = theme.colorScheme.primary;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = 'Razorpay Route Active';
      statusSubtitle = 'Payments are routed directly to your bank account';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Verification Pending';
      statusSubtitle = _onboardingStatus == 'needs_clarification'
          ? 'Razorpay requires additional information — check your email'
          : 'Razorpay is reviewing your details (1-2 business days)';
    } else {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.warning_rounded;
      statusTitle = 'Account ${_onboardingStatus ?? 'Unknown'}';
      statusSubtitle = 'Contact support if you need help';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: Spacing.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        fontSize: FontSize.body,
                      ),
                    ),
                    Text(
                      statusSubtitle,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: FontSize.caption,
                      ),
                    ),
                    if (_razorpayAccountId != null)
                      Text(
                        'Account: $_razorpayAccountId',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: FontSize.micro,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!isActive) ...[
            const SizedBox(height: Spacing.sp12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refreshStatus,
                    icon: _refreshing
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Check Status'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sp8),
                OutlinedButton.icon(
                  onPressed: _deleteLinkedAccount,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    'Remove',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: FontSize.sub,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: Spacing.sp12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.sp20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Razorpay Route Status ──
                    _buildRouteStatusCard(theme),

                    // ── Tax Details ──
                    const SizedBox(height: Spacing.sp24),
                    Text(
                      'Tax Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize.sub,
                      ),
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN',
                        hintText: 'e.g. 27AADCB2230M1ZT',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return null; // optional
                        }
                        final re = RegExp(
                          r'^\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z0-9]$',
                        );
                        if (!re.hasMatch(v.trim())) {
                          return 'Invalid GSTIN format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _panCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PAN Number',
                        hintText: 'e.g. AADCB2230M',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return null; // optional
                        }
                        final re = RegExp(r'^[A-Z]{5}\d{4}[A-Z]$');
                        if (!re.hasMatch(v.trim())) {
                          return 'Invalid PAN format';
                        }
                        return null;
                      },
                    ),

                    // ── Bank Details ──
                    const SizedBox(height: Spacing.sp24),
                    Text(
                      'Bank Account Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontSize: FontSize.sub,
                      ),
                    ),
                    const SizedBox(height: Spacing.sp4),
                    Text(
                      'Required for receiving payments via Razorpay Route',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: FontSize.caption,
                      ),
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _accNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                      ),
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _accNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _ifscCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IFSC Code',
                        hintText: 'e.g. SBIN0001234',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return null; // optional
                        }
                        final re = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                        if (!re.hasMatch(v.trim())) {
                          return 'Invalid IFSC format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: Spacing.sp12),
                    TextFormField(
                      controller: _bankNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g. State Bank of India',
                      ),
                    ),

                    // ── Save Button ──
                    const SizedBox(height: Spacing.sp32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                        ),
                        child: _saving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: theme.colorScheme.onPrimary,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: FontSize.body,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: Spacing.sp32),
                  ],
                ),
              ),
            ),
    );
  }
}
