import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../core/constants/error_strings.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import '../services/payment_service.dart';
import 'fee_record_detail_screen.dart';
import 'fee_member_profile_screen.dart';
import 'fee_ledger_screen.dart';
import 'payment_receipt_screen.dart';
import '../../../core/theme/design_tokens.dart';

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

class _MyFeesScreenState extends State<MyFeesScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FeeService();
  final _paySvc = PaymentService();
  late final TabController _tab;
  List<FeeRecordModel> _records = [];
  bool _loading = true;
  String? _error;
  String? _myMemberId; // student's own memberId in this coaching

  // Transaction history tab
  final List<Map<String, dynamic>> _transactions = [];
  bool _txLoading = false;
  String? _txError;
  int _txPage = 1;
  int _txTotal = 0;
  bool _txHasMore = true;

  // Multi-select state
  final Set<String> _selected = {};
  bool _selectMode = false;

  // Server-authoritative: online payments are only available when coaching
  // has completed Razorpay Route onboarding.
  bool _onlinePayEnabled = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      // Lazy-load transactions on first visit to History tab
      if (_tab.index == 1 &&
          !_tab.indexIsChanging &&
          _transactions.isEmpty &&
          !_txLoading) {
        _loadTransactions(reset: true);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _paySvc.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (reset) {
      setState(() {
        _txLoading = true;
        _txError = null;
        _txPage = 1;
        _transactions.clear();
        _txHasMore = true;
      });
    } else {
      if (!_txHasMore || _txLoading) return;
      setState(() => _txLoading = true);
    }
    try {
      final result = await _paySvc.getMyTransactions(
        widget.coachingId,
        page: reset ? 1 : _txPage,
      );
      if (!mounted) return;
      final txns =
          (result['transactions'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final total = result['total'] as int? ?? 0;
      setState(() {
        if (reset) _transactions.clear();
        _transactions.addAll(txns);
        _txTotal = total;
        _txPage = (reset ? 1 : _txPage) + 1;
        _txHasMore = _transactions.length < _txTotal;
        _txLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _txError = ErrorSanitizer.sanitize(e, fallback: FeeErrors.loadFailed);
        _txLoading = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _svc.getMyFees(widget.coachingId);
      final records = (result['records'] as List<FeeRecordModel>);
      final onlinePay = result['onlinePaymentEnabled'] as bool? ?? false;
      // Sort: overdue first, then pending, then partial, then paid/waived
      records.sort(
        (a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)),
      );
      // Derive own memberId from the first direct record (not ward)
      final firstMemberId = records.isNotEmpty ? records.first.memberId : null;
      setState(() {
        _records = records;
        _onlinePayEnabled = onlinePay;
        if (firstMemberId != null) _myMemberId = firstMemberId;
        _loading = false;
        _selected.removeWhere((id) => !records.any((r) => r.id == id));
      });
    } catch (e) {
      setState(() {
        _error = ErrorSanitizer.sanitize(e, fallback: FeeErrors.loadFailed);
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectMode
              ? '${_selected.length} selected'
              : 'Fees · ${widget.coachingName}',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: FontSize.sub,
          ),
        ),
        actions: [
          if (_selectMode)
            TextButton(
              onPressed: () => setState(() {
                _selected.clear();
                _selectMode = false;
              }),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          if (!_selectMode && _payableRecords.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.checklist_rounded,
                color: theme.colorScheme.onSurface,
              ),
              tooltip: 'Select fees to pay',
              onPressed: _selectAllPayable,
            ),
        ],
        bottom: _selectMode
            ? null
            : TabBar(
                controller: _tab,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: FontSize.body,
                ),
                tabs: const [
                  Tab(text: 'Fees'),
                  Tab(text: 'History'),
                ],
              ),
      ),
      body: _selectMode
          // In select mode show only the fees list (no TabBarView)
          ? (_loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ErrorRetry(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: theme.colorScheme.primary,
                    onRefresh: _load,
                    child: _records.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: Spacing.sp200),
                              _EmptyState(),
                            ],
                          )
                        : _buildBody(),
                  ))
          : TabBarView(
              controller: _tab,
              children: [
                // ─── Tab 0: Fees ───
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? ErrorRetry(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        color: theme.colorScheme.primary,
                        onRefresh: _load,
                        child: _records.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: Spacing.sp200),
                                  _EmptyState(),
                                ],
                              )
                            : _buildBody(),
                      ),
                // ─── Tab 1: History ───
                RefreshIndicator(
                  color: theme.colorScheme.primary,
                  onRefresh: _loadTransactions,
                  child: _txLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _txError != null
                      ? ErrorRetry(
                          message: _txError!,
                          onRetry: _loadTransactions,
                        )
                      : _TransactionHistory(
                          transactions: _transactions,
                          coachingId: widget.coachingId,
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _selectMode && _selected.isNotEmpty
          ? _PayBar(
              selectedCount: _selected.length,
              totalAmount: _selectedTotal,
              onPayFull: _onlinePayEnabled ? _payMulti : null,
              onlinePayEnabled: _onlinePayEnabled,
            )
          : null,
    );
  }

  // ─── Build the fee list body ───
  Widget _buildBody() {
    final theme = Theme.of(context);
    final payable = _payableRecords;
    final settled = _records
        .where((r) => r.status == 'PAID' || r.status == 'WAIVED')
        .toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Account shortcuts ───
        if (_myMemberId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp16,
                Spacing.sp14,
                Spacing.sp16,
                Spacing.sp4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AccountShortcutButton(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Account Summary',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeeMemberProfileScreen(
                            coachingId: widget.coachingId,
                            memberId: _myMemberId!,
                            isAdmin: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.sp10),
                  Expanded(
                    child: _AccountShortcutButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'Full Ledger',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeeLedgerScreen(
                            coachingId: widget.coachingId,
                            memberId: _myMemberId!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ─── Payable Section ───
        if (payable.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp16,
                Spacing.sp16,
                Spacing.sp16,
                Spacing.sp4,
              ),
              child: Row(
                children: [
                  Text(
                    'Payable',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                      fontSize: FontSize.body,
                    ),
                  ),
                  const SizedBox(width: Spacing.sp6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp8,
                      vertical: Spacing.sp2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      '${payable.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: FontSize.caption,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!_selectMode)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sp8,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text(
                        'Select All',
                        style: TextStyle(fontSize: FontSize.caption),
                      ),
                      onPressed: _selectAllPayable,
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sp16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final r = payable[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp10),
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
                    onPayOnline: _onlinePayEnabled
                        ? () => _initiatePayment(r)
                        : null,
                    onPayFull: _onlinePayEnabled ? () => _paySingle(r) : null,
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
              padding: const EdgeInsets.fromLTRB(
                Spacing.sp16,
                Spacing.sp16,
                Spacing.sp16,
                Spacing.sp4,
              ),
              child: Row(
                children: [
                  Text(
                    'Settled',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: FontSize.body,
                    ),
                  ),
                  const SizedBox(width: Spacing.sp6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp8,
                      vertical: Spacing.sp2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      '${settled.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: FontSize.caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sp16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) {
                final r = settled[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp10),
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
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.sp100)),
      ],
    );
  }

  // ─── Installment-aware entry point ───
  void _initiatePayment(FeeRecordModel record) {
    final structure = record.feeStructure;
    if (structure != null && structure.allowInstallments) {
      _showInstallmentPickerForRecord(record, structure);
    } else {
      _paySingle(record);
    }
  }

  void _showInstallmentPickerForRecord(
    FeeRecordModel record,
    FeeStructureModel structure,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeeInstallmentSheet(
        fixedItems: structure.installmentAmounts,
        installmentCount: structure.installmentCount,
        balance: record.balance,
        paidAmount: record.paidAmount,
        onSelected: (double? amount) => _paySingle(record, amount: amount),
      ),
    );
  }

  // ─── Single-record online pay ───
  Future<void> _paySingle(FeeRecordModel record, {double? amount}) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    Map<String, dynamic>? orderData;
    try {
      orderData = await _paySvc.createOrder(
        widget.coachingId,
        record.id,
        amount: amount,
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

      final oid = response.orderId;
      final pid = response.paymentId;
      final sig = response.signature;
      if (oid == null || pid == null || sig == null) {
        throw Exception('Incomplete payment response from Razorpay');
      }

      final verified = await _paySvc.verifyPayment(
        widget.coachingId,
        record.id,
        razorpayOrderId: oid,
        razorpayPaymentId: pid,
        razorpaySignature: sig,
      );
      if (!mounted) return;

      final vp = verified['verifiedPayment'] as Map<String, dynamic>?;
      final receiptNo =
          vp?['receiptNo'] as String? ?? verified['receiptNo'] as String? ?? '';
      final paidAmount = (vp?['amount'] as num?)?.toDouble() ?? record.balance;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentReceiptScreen(
            coachingName: widget.coachingName,
            feeTitle: record.title,
            amount: paidAmount,
            paymentId: pid,
            orderId: oid,
            paidAt: vp?['paidAt'] != null
                ? DateTime.tryParse(vp!['paidAt'] as String) ?? DateTime.now()
                : DateTime.now(),
            studentName: record.member?.name,
            receiptNo: receiptNo,
            paymentMode: 'RAZORPAY',
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
      _loadTransactions();
    } catch (e) {
      if (orderData != null) {
        final internalId = orderData['internalOrderId'] as String?;
        if (internalId != null) {
          final reason = ErrorSanitizer.sanitize(
            e,
            fallback: FeeErrors.paymentFailed,
          );
          await _paySvc.markOrderFailed(widget.coachingId, internalId, reason);
        }
      }
      if (!mounted) return;
      final msg = ErrorSanitizer.sanitize(e, fallback: FeeErrors.paymentFailed);
      if (msg == 'Payment cancelled') return;
      // External wallet: show info instead of error (webhook will confirm)
      if (msg.contains('being processed via')) {
        AppAlert.info(context, title: 'Processing', message: msg);
        return;
      }
      final viewDetails = await AppAlert.confirm(
        context,
        title: 'Payment Failed',
        message: msg,
        confirmText: 'View Details',
        cancelText: 'Close',
        icon: Icons.error_outline_rounded,
        confirmColor: Theme.of(context).colorScheme.error,
      );
      if (viewDetails && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeeRecordDetailScreen(
              coachingId: widget.coachingId,
              recordId: record.id,
              coachingName: widget.coachingName,
            ),
          ),
        ).then((_) => _load());
      }
    }
  }

  // ─── Multi-record online pay ───
  Future<void> _payMulti() async {
    if (_selected.isEmpty) return;
    final auth = Provider.of<AuthController>(context, listen: false);
    final user = auth.user;

    Map<String, dynamic>? orderData;
    try {
      orderData = await _paySvc.createMultiOrder(
        widget.coachingId,
        recordIds: _selected.toList(),
      );
      if (!mounted) return;

      final response = await _paySvc.openCheckout(
        orderId: orderData['orderId'] as String,
        amountPaise: (orderData['amount'] as num).toInt(),
        key: orderData['key'] as String,
        feeTitle: '${_selected.length} fee${_selected.length > 1 ? 's' : ''}',
        userEmail: user?.email,
        userPhone: user?.phone,
        userName: user?.name,
      );
      if (!mounted) return;

      final oid = response.orderId;
      final pid = response.paymentId;
      final sig = response.signature;
      if (oid == null || pid == null || sig == null) {
        throw Exception('Incomplete payment response from Razorpay');
      }

      await _paySvc.verifyMultiPayment(
        widget.coachingId,
        razorpayOrderId: oid,
        razorpayPaymentId: pid,
        razorpaySignature: sig,
      );
      if (!mounted) return;

      AppAlert.success(context, 'Payment successful! All fees have been paid.');
      setState(() {
        _selected.clear();
        _selectMode = false;
      });
      _load();
      _loadTransactions();
    } catch (e) {
      if (orderData != null) {
        final internalId = orderData['internalOrderId'] as String?;
        if (internalId != null) {
          final reason = ErrorSanitizer.sanitize(
            e,
            fallback: FeeErrors.paymentFailed,
          );
          await _paySvc.markOrderFailed(widget.coachingId, internalId, reason);
        }
      }
      if (!mounted) return;
      final msg = ErrorSanitizer.sanitize(e, fallback: FeeErrors.paymentFailed);
      if (msg == 'Payment cancelled') return;
      // External wallet: show info instead of error (webhook will confirm)
      if (msg.contains('being processed via')) {
        AppAlert.info(context, title: 'Processing', message: msg);
        return;
      }
      AppAlert.error(context, msg);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ─── WIDGETS ──────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Quick-access shortcut button for account summary / ledger.
class _AccountShortcutButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AccountShortcutButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.sp12,
            horizontal: Spacing.sp14,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: Spacing.sp8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: FontSize.body,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom payment bar when records are selected.
class _PayBar extends StatelessWidget {
  final int selectedCount;
  final double totalAmount;
  final VoidCallback? onPayFull;
  final bool onlinePayEnabled;
  const _PayBar({
    required this.selectedCount,
    required this.totalAmount,
    required this.onPayFull,
    required this.onlinePayEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp20,
        Spacing.sp12,
        Spacing.sp20,
        Spacing.sp16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
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
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: FontSize.caption,
                    ),
                  ),
                  Text(
                    '\u20b9${totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: FontSize.title,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.sp12),
            if (onlinePayEnabled)
              FilledButton.icon(
                onPressed: onPayFull,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp16,
                    vertical: Spacing.sp10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: FontSize.body,
                  ),
                ),
              )
            else
              Flexible(
                child: Text(
                  'Online payments not enabled',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: FontSize.caption,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
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
  final VoidCallback? onPayFull;
  const _FeeCard({
    required this.record,
    required this.isSelected,
    required this.selectMode,
    required this.onTap,
    this.onLongPress,
    this.onPayOnline,
    this.onPayFull,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(record.status, theme.colorScheme);
    final canPay =
        record.status == 'PENDING' ||
        record.status == 'OVERDUE' ||
        record.status == 'PARTIALLY_PAID';

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(Spacing.sp16),
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(Radii.lg),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectMode && canPay)
                    Padding(
                      padding: const EdgeInsets.only(right: Spacing.sp10),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            fontSize: FontSize.body,
                          ),
                        ),
                        if (record.member != null &&
                            record.member!.wardId != null)
                          Text(
                            'For: ${record.member!.name ?? 'Ward'}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: FontSize.caption,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontSize: FontSize.sub,
                        ),
                      ),
                      _StatusPill(status: record.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sp10),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sp4),
                  Text(
                    'Due ${_fmtDate(record.dueDate)}',
                    style: TextStyle(
                      color: record.isOverdue
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: FontSize.caption,
                      fontWeight: record.isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (record.daysOverdue > 0) ...[
                    const SizedBox(width: Spacing.sp6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp6,
                        vertical: Spacing.sp2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        '${record.daysOverdue}d overdue',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: FontSize.nano,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (record.discountAmount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp6,
                        vertical: Spacing.sp2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        '-₹${record.discountAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: FontSize.nano,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sp4),
                  ],
                  if (record.isPartial) ...[
                    Text(
                      '₹${record.paidAmount.toStringAsFixed(0)} paid',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: FontSize.caption,
                      ),
                    ),
                  ],
                ],
              ),
              // Validity period
              if (record.validFrom != null || record.validUntil != null) ...[
                const SizedBox(height: Spacing.sp6),
                Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sp4),
                    Text(
                      _validityLabel(record.validFrom, record.validUntil),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: FontSize.micro,
                      ),
                    ),
                  ],
                ),
              ],
              // Tax info
              if (record.hasTax) ...[
                const SizedBox(height: Spacing.sp4),
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sp4),
                    Text(
                      'GST ${record.gstRate.toStringAsFixed(0)}%'
                      ' · Tax ₹${record.taxAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: FontSize.micro,
                      ),
                    ),
                  ],
                ),
              ],
              // Progress bar
              if (canPay) ...[
                const SizedBox(height: Spacing.sp10),
                _ProgressBar(
                  paid: record.paidAmount,
                  total: record.finalAmount,
                  statusColor: statusColor,
                ),
              ],
              // Pay Online (only in non-select mode and when enabled)
              if (canPay && !selectMode && onPayFull != null) ...[
                const SizedBox(height: Spacing.sp10),
                if (_hasInstallments(record)) ...[
                  // Two-button layout: installment (primary) + full (outlined)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: FilledButton.icon(
                            onPressed: onPayOnline,
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(
                              Icons.splitscreen_rounded,
                              size: 16,
                            ),
                            label: Text(
                              'Pay ₹${_installmentLabel(record)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: FontSize.caption,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sp8),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: OutlinedButton.icon(
                            onPressed: onPayFull,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.primary,
                              side: BorderSide(
                                color: theme.colorScheme.primary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(Radii.md),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(
                              'Full ₹${record.balance.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: FontSize.caption,
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
                    height: 36,
                    child: FilledButton.icon(
                      onPressed: onPayFull,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        'Pay ₹${record.balance.toStringAsFixed(0)} Online',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: FontSize.body,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              // Show info when online payment is not available
              if (canPay && !selectMode && onPayFull == null) ...[
                const SizedBox(height: Spacing.sp10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp12,
                    vertical: Spacing.sp8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Spacing.sp6),
                      Expanded(
                        child: Text(
                          'Ask your coaching admin to enable online payments',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: FontSize.micro,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
    final theme = Theme.of(context);
    final ratio = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: LinearProgressIndicator(
        value: ratio,
        backgroundColor: theme.colorScheme.outlineVariant.withValues(
          alpha: 0.4,
        ),
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
    final c = _statusColor(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp8,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: c,
          fontSize: FontSize.nano,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 52,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: Spacing.sp12),
          Text(
            'No fees due!',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              fontSize: FontSize.sub,
            ),
          ),
          const SizedBox(height: Spacing.sp4),
          Text(
            'You are all caught up.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String s, ColorScheme cs) {
  switch (s) {
    case 'PAID':
      return cs.primary;
    case 'PENDING':
      return cs.secondary;
    case 'OVERDUE':
      return cs.error;
    case 'PARTIALLY_PAID':
      return cs.secondary;
    case 'WAIVED':
      return cs.onSurfaceVariant;
    default:
      return cs.onSurfaceVariant;
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

// ─── Transaction History Tab ────────────────────────────────────────────

class _TransactionHistory extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final String coachingId;
  const _TransactionHistory({
    required this.transactions,
    required this.coachingId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (transactions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: Spacing.sp120),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 52,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: Spacing.sp12),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontSize: FontSize.sub,
                  ),
                ),
                const SizedBox(height: Spacing.sp4),
                Text(
                  'Your payment history will appear here.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: FontSize.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp16,
        Spacing.sp12,
        Spacing.sp16,
        Spacing.sp32,
      ),
      itemCount: transactions.length,
      itemBuilder: (ctx, i) => _TxnCard(txn: transactions[i]),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _TxnCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = txn['type'] as String? ?? '';
    final isPayment = type == 'PAYMENT';
    final orderStatus = txn['status'] as String? ?? '';

    // Visual theme — semantic status colours grounded in app theme
    late Color bgColor, accentColor, labelBg;
    late IconData icon;
    late String statusLabel;

    if (isPayment) {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.07);
      accentColor = theme.colorScheme.primary;
      labelBg = theme.colorScheme.primary.withValues(alpha: 0.13);
      icon = Icons.check_circle_rounded;
      statusLabel = 'Paid';
    } else if (orderStatus == 'FAILED') {
      bgColor = theme.colorScheme.error.withValues(alpha: 0.07);
      accentColor = theme.colorScheme.error;
      labelBg = theme.colorScheme.error.withValues(alpha: 0.13);
      icon = Icons.cancel_rounded;
      statusLabel = 'Failed';
    } else if (orderStatus == 'EXPIRED') {
      bgColor = theme.colorScheme.tertiary.withValues(alpha: 0.25);
      accentColor = theme.colorScheme.secondary;
      labelBg = theme.colorScheme.tertiary.withValues(alpha: 0.45);
      icon = Icons.access_time_rounded;
      statusLabel = 'Expired';
    } else {
      // CREATED — initiated but not completed
      bgColor = theme.colorScheme.secondary.withValues(alpha: 0.07);
      accentColor = theme.colorScheme.secondary;
      labelBg = theme.colorScheme.secondary.withValues(alpha: 0.13);
      icon = Icons.pending_rounded;
      statusLabel = 'Initiated';
    }

    final amount =
        ((txn['totalAmount'] ?? txn['amount']) as num?)?.toDouble() ?? 0;
    final title = txn['recordTitle'] as String? ?? '';
    final dateRaw = txn['date'] as String?;
    final date = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
    final dateStr = date != null
        ? '${date.day} ${_monthName(date.month)} ${date.year}  '
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}'
        : '';

    // Build detail lines
    final lines = <String>[];
    if (isPayment) {
      final mode = txn['mode'] as String? ?? '';
      final receiptNo = txn['receiptNo'] as String? ?? '';
      final payId = txn['razorpayPaymentId'] as String? ?? '';
      final orderId = txn['razorpayOrderId'] as String? ?? '';
      final parts = <String>[];
      if (mode.isNotEmpty) parts.add(mode.toUpperCase());
      if (receiptNo.isNotEmpty) parts.add('Receipt #$receiptNo');
      if (payId.isNotEmpty) parts.add(_truncateId(payId));
      if (parts.isNotEmpty) lines.add(parts.join(' · '));
      if (orderId.isNotEmpty) lines.add(_truncateId(orderId));
    } else {
      final rzpOrderId = txn['razorpayOrderId'] as String? ?? '';
      final rzpPayId = txn['razorpayPaymentId'] as String? ?? '';
      final receipt = txn['receipt'] as String? ?? '';
      final failureReason = txn['failureReason'] as String? ?? '';
      final transferStatus = txn['transferStatus'] as String? ?? '';

      if (rzpOrderId.isNotEmpty) lines.add(_truncateId(rzpOrderId));
      if (rzpPayId.isNotEmpty) lines.add(_truncateId(rzpPayId));
      if (receipt.isNotEmpty) lines.add('Receipt: $receipt');

      if (orderStatus == 'FAILED') {
        final reason = failureReason.replaceFirst('Exception: ', '').trim();
        if (reason.isNotEmpty) lines.add(reason);
      } else if (orderStatus == 'EXPIRED') {
        lines.add('Order expired — not completed');
      } else if (orderStatus == 'CREATED') {
        lines.add('Payment initiated — awaiting completion');
      }

      if (transferStatus.isNotEmpty && transferStatus != 'PENDING') {
        lines.add('Transfer: $transferStatus');
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sp10),
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp14,
        Spacing.sp12,
        Spacing.sp14,
        Spacing.sp12,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: Spacing.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          fontSize: FontSize.body,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.sp6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp8,
                        vertical: Spacing.sp2,
                      ),
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: FontSize.nano,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sp2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: FontSize.micro,
                        color: accentColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (dateStr.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.sp2),
                    child: Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: FontSize.micro,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sp8),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: FontSize.body,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Truncate long Razorpay IDs like `order_Abc123...` to a readable length.
  String _truncateId(String id) {
    if (id.length <= 22) return id;
    return '${id.substring(0, 18)}…';
  }

  String _monthName(int m) {
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
    return months[m - 1];
  }
}

// ─── Installment picker sheet (used by MyFeesScreen) ──────────────────────

class _FeeInstallmentSheet extends StatelessWidget {
  final List<InstallmentAmountItem> fixedItems;
  final int installmentCount;
  final double balance;
  final double paidAmount;
  final void Function(double? amount) onSelected;

  const _FeeInstallmentSheet({
    required this.fixedItems,
    required this.installmentCount,
    required this.balance,
    required this.paidAmount,
    required this.onSelected,
  });

  double get _totalAmount => balance + paidAmount;

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

  bool _isPaid(List<InstallmentAmountItem> options, int index) {
    double cumulative = 0;
    for (int i = 0; i <= index; i++) {
      cumulative += options[i].amount;
    }
    return paidAmount >= cumulative - 0.01;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        Spacing.sp20,
        Spacing.sp20,
        Spacing.sp20,
        Spacing.sp32 + MediaQuery.of(context).viewPadding.bottom,
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
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sp16),
          Text(
            'Choose Payment Option',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: FontSize.sub,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.sp4),
          Text(
            'Outstanding balance: ₹${balance.toStringAsFixed(0)}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: FontSize.caption,
            ),
          ),
          if (options.isNotEmpty) ...[
            const SizedBox(height: Spacing.sp6),
            Text(
              options.length == installmentCount && fixedItems.isEmpty
                  ? 'Split into $installmentCount equal installments'
                  : '${options.length} payment options available',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.micro,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: Spacing.sp16),
          // Installment options
          ...options.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final paid = _isPaid(options, i);
            final isPayable = !paid && item.amount <= balance + 0.01;
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sp10),
              child: InkWell(
                onTap: isPayable
                    ? () {
                        Navigator.pop(context);
                        onSelected(item.amount);
                      }
                    : null,
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp16,
                    vertical: Spacing.sp14,
                  ),
                  decoration: BoxDecoration(
                    color: paid
                        ? theme.colorScheme.primary.withValues(alpha: 0.07)
                        : isPayable
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.07)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: paid
                          ? theme.colorScheme.primary.withValues(alpha: 0.35)
                          : isPayable
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: paid
                                ? theme.colorScheme.primary
                                : isPayable
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: FontSize.body,
                          ),
                        ),
                      ),
                      Text(
                        '₹${item.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: paid
                              ? theme.colorScheme.primary
                              : isPayable
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: FontSize.body,
                        ),
                      ),
                      const SizedBox(width: Spacing.sp8),
                      if (paid)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      else if (!isPayable)
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Divider(height: 16),
          // Pay full balance
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(color: theme.colorScheme.primary),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.md),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onSelected(null);
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
