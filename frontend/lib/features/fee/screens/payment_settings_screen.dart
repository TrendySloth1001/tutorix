import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/error_strings.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../../../shared/widgets/app_alert.dart';

/// 3-step onboarding wizard for Razorpay Route setup:
///   Step 0 — Tax & Contact (PAN, GSTIN, Phone)
///   Step 1 — Bank Account (with IFSC auto-lookup)
///   Step 2 — Review & Activate
class PaymentSettingsScreen extends StatefulWidget {
  final String coachingId;
  const PaymentSettingsScreen({super.key, required this.coachingId});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _svc = PaymentService();
  final _step0Key = GlobalKey<FormState>();
  final _step1Key = GlobalKey<FormState>();

  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  int _currentStep = 0;
  bool _loading = true;
  bool _saving = false;
  bool _activating = false;
  bool _refreshing = false;
  bool _ifscLookingUp = false;
  bool _verifyingBank = false;
  bool _bankVerified = false;
  bool _obscureAccNum = true;
  DateTime? _bankVerifiedAt;
  String? _error;
  String? _ifscBranchLabel;
  String? _razorpayAccountId;
  bool _razorpayActivated = false;
  String? _onboardingStatus;

  Timer? _ifscDebounce;

  static const _stepLabels = ['Tax Info', 'Bank Account', 'Activate'];

  @override
  void initState() {
    super.initState();
    _load();
    _ifscCtrl.addListener(_onIfscChanged);
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    _ifscCtrl.dispose();
    _ifscDebounce?.cancel();
    super.dispose();
  }

  // ── IFSC auto-lookup ────────────────────────────────────────────

  void _onIfscChanged() {
    final val = _ifscCtrl.text.trim().toUpperCase();
    if (val.length == 11 && RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(val)) {
      _ifscDebounce?.cancel();
      _ifscDebounce = Timer(
        const Duration(milliseconds: 600),
        () => _lookupIfsc(val),
      );
    } else {
      setState(() => _ifscBranchLabel = null);
    }
  }

  Future<void> _lookupIfsc(String ifsc) async {
    if (!mounted) return;
    setState(() {
      _ifscLookingUp = true;
      _ifscBranchLabel = null;
    });
    try {
      final res = await http
          .get(Uri.parse('https://ifsc.razorpay.com/$ifsc'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final bank = data['BANK'] as String?;
        final branch = data['BRANCH'] as String?;
        final city = data['CITY'] as String?;
        if (bank != null && bank.isNotEmpty) {
          setState(() {
            _bankNameCtrl.text = bank;
            _ifscBranchLabel = [
              branch,
              city,
            ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
          });
        }
      }
    } catch (_) {
      // silent — user can still fill bank name manually
    } finally {
      if (mounted) setState(() => _ifscLookingUp = false);
    }
  }

  // ── Data load / save ────────────────────────────────────────────

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
        _phoneCtrl.text = data['contactPhone'] as String? ?? '';
        _bankNameCtrl.text = data['bankName'] as String? ?? '';
        _accNameCtrl.text = data['bankAccountName'] as String? ?? '';
        _accNumCtrl.text =
            data['bankAccountNumberRaw'] as String? ??
            data['bankAccountNumber'] as String? ??
            '';
        _ifscCtrl.text = data['bankIfscCode'] as String? ?? '';
        _razorpayAccountId = data['razorpayAccountId'] as String?;
        _razorpayActivated = data['razorpayActivated'] as bool? ?? false;
        _onboardingStatus = data['razorpayOnboardingStatus'] as String?;
        _bankVerified = data['bankVerified'] as bool? ?? false;
        final verifiedAtRaw = data['bankVerifiedAt'] as String?;
        _bankVerifiedAt = verifiedAtRaw != null
            ? DateTime.tryParse(verifiedAtRaw)
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorSanitizer.sanitize(e, fallback: PaymentErrors.loadFailed);
        _loading = false;
      });
    }
  }

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.updatePaymentSettings(
        widget.coachingId,
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
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
      return true;
    } catch (e) {
      if (mounted) AppAlert.error(context, e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Step navigation ─────────────────────────────────────────────

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (!_step0Key.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_step1Key.currentState!.validate()) return;
      final ok = await _save();
      if (ok && mounted) setState(() => _currentStep = 2);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ── Razorpay Route actions ──────────────────────────────────────

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
        ownerPhone: _phoneCtrl.text.trim().isNotEmpty
            ? _phoneCtrl.text.trim()
            : (user.phone ?? '').replaceAll(RegExp(r'^\+91'), ''),
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
      AppAlert.success(context, msg);
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
      AppAlert.success(context, PaymentSuccess.accountRemoved);
      _load();
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e);
    }
  }

  Future<void> _verifyBank() async {
    // Validate bank details are saved first
    if (_accNumCtrl.text.trim().isEmpty ||
        _ifscCtrl.text.trim().isEmpty ||
        _accNameCtrl.text.trim().isEmpty) {
      AppAlert.error(
        context,
        'Please save your bank details first (Account Number, IFSC, Account Holder Name)',
      );
      return;
    }

    // Save before verifying to ensure latest values are on backend
    final saved = await _save();
    if (!saved || !mounted) return;

    setState(() => _verifyingBank = true);
    try {
      final result = await _svc.verifyBankAccount(widget.coachingId);
      if (!mounted) return;

      final verified = result['verified'] as bool? ?? false;
      final nameAtBank = result['nameAtBank'] as String?;
      final message = result['message'] as String? ?? 'Verification completed';

      setState(() {
        _bankVerified = verified;
        if (verified) _bankVerifiedAt = DateTime.now();
      });

      if (verified) {
        AppAlert.success(
          context,
          nameAtBank != null
              ? 'Bank verified! Name at bank: $nameAtBank'
              : message,
        );
      } else {
        AppAlert.error(context, message);
      }
    } catch (e) {
      if (!mounted) return;
      AppAlert.error(context, e);
    } finally {
      if (mounted) setState(() => _verifyingBank = false);
    }
  }

  // ── Step content builders ───────────────────────────────────────

  Widget _buildStep0(ThemeData theme) {
    return Form(
      key: _step0Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.receipt_long_rounded,
            title: 'Tax & Contact Details',
            subtitle:
                'This information is used for generating payment receipts '
                'and registering your Razorpay account for payouts.',
            theme: theme,
          ),
          const SizedBox(height: Spacing.sp24),
          _FieldCard(
            theme: theme,
            icon: Icons.badge_rounded,
            title: 'PAN Number',
            why:
                'Mandatory for Razorpay KYC and TDS compliance on payouts above '
                '₹50,000/year. Must be the PAN of the coaching owner.',
            child: TextFormField(
              controller: _panCtrl,
              decoration: const InputDecoration(
                labelText: 'PAN Number',
                hintText: 'e.g. AADCB2230M',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(v.trim())) {
                  return 'Invalid PAN format';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: Spacing.sp20),
          _FieldCard(
            theme: theme,
            icon: Icons.account_balance_rounded,
            title: 'GSTIN (Optional)',
            why:
                'Only needed if your coaching is GST-registered — applicable when '
                'annual turnover exceeds ₹20 lakhs. Leave blank if not registered.',
            child: TextFormField(
              controller: _gstCtrl,
              decoration: const InputDecoration(
                labelText: 'GSTIN (Optional)',
                hintText: 'e.g. 27AADCB2230M1ZT',
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(
                  r'^\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z0-9]$',
                ).hasMatch(v.trim())) {
                  return 'Invalid GSTIN format';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: Spacing.sp20),
          _FieldCard(
            theme: theme,
            icon: Icons.phone_rounded,
            title: 'Contact Phone',
            why:
                'Used for payment alerts, dispute notifications, and to register '
                'your Razorpay linked account. Must be a valid Indian mobile number.',
            child: TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Phone',
                hintText: '9876543210',
                prefixText: '+91 ',
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
                  return 'Enter a valid 10-digit Indian mobile number';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            icon: Icons.account_balance_outlined,
            title: 'Bank Account Details',
            subtitle:
                'Student payments will be settled into this account. '
                'Ensure details match your bank records exactly to avoid payout failures.',
            theme: theme,
          ),
          const SizedBox(height: Spacing.sp24),
          _FieldCard(
            theme: theme,
            icon: Icons.person_rounded,
            title: 'Account Holder Name',
            why:
                'Must exactly match the name on your bank account. '
                'Used by Razorpay for name verification during payout.',
            child: TextFormField(
              controller: _accNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Holder Name',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: Spacing.sp20),
          _FieldCard(
            theme: theme,
            icon: Icons.tag_rounded,
            title: 'Account Number',
            why:
                'Your 9–18 digit savings or current account number. '
                'Find it in your passbook, bank app, or cheque book.',
            child: TextFormField(
              controller: _accNumCtrl,
              decoration: InputDecoration(
                labelText: 'Account Number',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureAccNum
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureAccNum = !_obscureAccNum),
                ),
              ),
              keyboardType: TextInputType.number,
              obscureText: _obscureAccNum,
              enableSuggestions: false,
            ),
          ),
          const SizedBox(height: Spacing.sp20),
          _FieldCard(
            theme: theme,
            icon: Icons.qr_code_rounded,
            title: 'IFSC Code',
            why:
                'The 11-character code that identifies your bank branch — '
                'find it on your cheque book, passbook, or in your bank app. '
                'Bank name is auto-filled once a valid IFSC is entered.',
            child: TextFormField(
              controller: _ifscCtrl,
              decoration: InputDecoration(
                labelText: 'IFSC Code',
                hintText: 'e.g. SBIN0001234',
                suffixIcon: _ifscLookingUp
                    ? const Padding(
                        padding: EdgeInsets.all(Spacing.sp12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _ifscBranchLabel != null
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : null,
                helperText: _ifscBranchLabel,
                helperStyle: TextStyle(color: theme.colorScheme.primary),
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                final upper = v.toUpperCase();
                if (upper != v) {
                  _ifscCtrl.value = _ifscCtrl.value.copyWith(
                    text: upper,
                    selection: TextSelection.collapsed(offset: upper.length),
                  );
                }
              },
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim())) {
                  return 'Invalid IFSC format';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: Spacing.sp20),
          _FieldCard(
            theme: theme,
            icon: Icons.corporate_fare_rounded,
            title: 'Bank Name',
            why:
                'Auto-filled when you enter a valid IFSC code above. '
                'You can edit this if needed.',
            child: TextFormField(
              controller: _bankNameCtrl,
              decoration: const InputDecoration(labelText: 'Bank Name'),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: Spacing.sp24),

          // ── Bank Verification ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.sp20),
            decoration: BoxDecoration(
              color: _bankVerified
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: _bankVerified
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _bankVerified
                          ? Icons.verified_rounded
                          : Icons.security_rounded,
                      color: _bankVerified
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: Spacing.sp8),
                    Text(
                      _bankVerified
                          ? 'Bank Account Verified'
                          : 'Verify Bank Account',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _bankVerified
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sp8),
                Text(
                  _bankVerified
                      ? 'Your bank account has been verified via penny drop.'
                            '${_bankVerifiedAt != null ? ' Verified on ${_bankVerifiedAt!.day}/${_bankVerifiedAt!.month}/${_bankVerifiedAt!.year}.' : ''}'
                      : 'A ₹1 penny drop will be made to verify your account details. '
                            'This confirms your account number, IFSC, and account holder name are correct.',
                  style: TextStyle(
                    fontSize: FontSize.caption,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (!_bankVerified) ...[
                  const SizedBox(height: Spacing.sp16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _verifyingBank ? null : _verifyBank,
                      icon: _verifyingBank
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_outlined, size: 18),
                      label: Text(
                        _verifyingBank ? 'Verifying…' : 'Verify via Penny Drop',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.rocket_launch_rounded,
          title: 'Activate Payments',
          subtitle:
              'Review your details and create a Razorpay linked account. '
              'Once activated, student payments are split and settled '
              'directly into your bank — no manual transfers needed.',
          theme: theme,
        ),
        const SizedBox(height: Spacing.sp24),
        _SummaryCard(
          theme: theme,
          panNumber: _panCtrl.text.trim(),
          bankAccountName: _accNameCtrl.text.trim(),
          bankAccountNumber: _accNumCtrl.text.trim(),
          ifscCode: _ifscCtrl.text.trim(),
          bankName: _bankNameCtrl.text.trim(),
          bankVerified: _bankVerified,
        ),
        const SizedBox(height: Spacing.sp24),
        _buildRouteStatusCard(theme),
      ],
    );
  }

  Widget _buildRouteStatusCard(ThemeData theme) {
    if (_razorpayAccountId == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.sp20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to activate',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              "Razorpay will review your details and activate your account within "
              "1–2 business days. You'll receive an email at each stage.",
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.caption,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Spacing.sp16),
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
                      ? 'Creating account...'
                      : 'Activate Razorpay Route',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isActive = _razorpayActivated;
    final isPending =
        _onboardingStatus == 'under_review' ||
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
      statusColor = theme.colorScheme.tertiary;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Verification Pending';
      statusSubtitle = _onboardingStatus == 'needs_clarification'
          ? 'Razorpay needs more info — check your registered email'
          : 'Razorpay is reviewing your details (1–2 business days)';
    } else {
      statusColor = theme.colorScheme.error;
      statusIcon = Icons.warning_rounded;
      statusTitle = 'Account ${_onboardingStatus ?? 'Unknown'}';
      statusSubtitle = 'Contact support for help';
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
          ? ErrorRetry(message: _error!, onRetry: _load)
          : Column(
              children: [
                // ── Step progress indicator ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.sp24,
                    Spacing.sp12,
                    Spacing.sp24,
                    Spacing.sp4,
                  ),
                  child: _StepIndicator(
                    current: _currentStep,
                    labels: _stepLabels,
                    theme: theme,
                  ),
                ),
                // ── Step content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sp20,
                      Spacing.sp20,
                      Spacing.sp20,
                      Spacing.sp8,
                    ),
                    child: [
                      _buildStep0(theme),
                      _buildStep1(theme),
                      _buildStep2(theme),
                    ][_currentStep],
                  ),
                ),
                // ── Bottom navigation ──
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.sp20,
                      Spacing.sp8,
                      Spacing.sp20,
                      Spacing.sp16,
                    ),
                    child: Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              onPressed: _prevStep,
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: Spacing.sp12),
                        ],
                        if (_currentStep < 2)
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: _saving ? null : _nextStep,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
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
                                  : Text(
                                      _currentStep == 1
                                          ? 'Save & Continue'
                                          : 'Next',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: FontSize.body,
                                      ),
                                    ),
                            ),
                          )
                        else
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(Radii.md),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Done'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> labels;
  final ThemeData theme;
  const _StepIndicator({
    required this.current,
    required this.labels,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final done = current > stepIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Container(
                height: 2,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final done = current > stepIndex;
        final active = current == stepIndex;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: done || active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: Center(
                child: done
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: FontSize.caption,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              labels[stepIndex],
              style: TextStyle(
                fontSize: FontSize.micro,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;
  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 24),
        ),
        const SizedBox(height: Spacing.sp12),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
            fontSize: FontSize.sub,
          ),
        ),
        const SizedBox(height: Spacing.sp4),
        Text(
          subtitle,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: FontSize.caption,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _FieldCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String why;
  final Widget child;
  const _FieldCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.why,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.sp6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: FontSize.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sp4),
        Text(
          why,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: FontSize.micro,
            height: 1.4,
          ),
        ),
        const SizedBox(height: Spacing.sp8),
        child,
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ThemeData theme;
  final String panNumber;
  final String bankAccountName;
  final String bankAccountNumber;
  final String ifscCode;
  final String bankName;
  final bool bankVerified;
  const _SummaryCard({
    required this.theme,
    required this.panNumber,
    required this.bankAccountName,
    required this.bankAccountNumber,
    required this.ifscCode,
    required this.bankName,
    this.bankVerified = false,
  });

  String _mask(String acc) {
    if (acc.length <= 4) return acc;
    return '${'•' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final empty =
        panNumber.isEmpty &&
        bankAccountName.isEmpty &&
        bankAccountNumber.isEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.sp16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: Spacing.sp6),
              Text(
                'Review your details',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  fontSize: FontSize.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sp12),
          if (empty)
            Text(
              'No details saved yet — go back and fill in your information.',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: FontSize.caption,
              ),
            )
          else ...[
            if (panNumber.isNotEmpty)
              _SummaryRow(label: 'PAN', value: panNumber, theme: theme),
            if (bankAccountName.isNotEmpty)
              _SummaryRow(
                label: 'Account Holder',
                value: bankAccountName,
                theme: theme,
              ),
            if (bankAccountNumber.isNotEmpty)
              _SummaryRow(
                label: 'Account No.',
                value: _mask(bankAccountNumber),
                theme: theme,
              ),
            if (ifscCode.isNotEmpty)
              _SummaryRow(label: 'IFSC', value: ifscCode, theme: theme),
            if (bankName.isNotEmpty)
              _SummaryRow(label: 'Bank', value: bankName, theme: theme),
            const SizedBox(height: Spacing.sp4),
            _SummaryRow(
              label: 'Bank Verified',
              value: bankVerified ? '✓ Verified' : '✗ Not verified',
              theme: theme,
              valueColor: bankVerified
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sp8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.caption,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: FontSize.caption,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
