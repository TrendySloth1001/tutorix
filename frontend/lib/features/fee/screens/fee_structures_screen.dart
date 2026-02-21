import 'package:flutter/material.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_audit_log_screen.dart';
import '../../../core/theme/design_tokens.dart';

/// Manages fee structures (templates) for a coaching.
/// Multiple independent structures can coexist — each can be assigned to any number of students.
class FeeStructuresScreen extends StatefulWidget {
  final String coachingId;
  const FeeStructuresScreen({super.key, required this.coachingId});

  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  final _svc = FeeService();

  List<FeeStructureModel> _structures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _svc.listStructures(widget.coachingId);
      if (!mounted) return;
      setState(() {
        _structures = all;
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

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StructureFormSheet(
        onSubmit:
            (
              name,
              desc,
              amount,
              cycle,
              fine, {
              taxType,
              gstRate,
              sacCode,
              hsnCode,
              gstSupplyType,
              cessRate,
              lineItems,
              allowInstallments,
              installmentCount,
              installmentAmounts,
            }) async {
              await _svc.createStructure(
                widget.coachingId,
                name: name,
                description: desc,
                amount: amount,
                cycle: cycle,
                lateFinePerDay: fine,
                taxType: taxType,
                gstRate: gstRate,
                sacCode: sacCode,
                hsnCode: hsnCode,
                gstSupplyType: gstSupplyType,
                cessRate: cessRate,
                lineItems: lineItems,
                allowInstallments: allowInstallments ?? false,
                installmentCount: installmentCount ?? 0,
                installmentAmounts: installmentAmounts,
              );
              _load();
            },
      ),
    );
  }

  void _showEditSheet(FeeStructureModel s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StructureFormSheet(
        existing: s,
        onSubmit:
            (
              name,
              desc,
              amount,
              cycle,
              fine, {
              taxType,
              gstRate,
              sacCode,
              hsnCode,
              gstSupplyType,
              cessRate,
              lineItems,
              allowInstallments,
              installmentCount,
              installmentAmounts,
            }) async {
              await _svc.updateStructure(
                widget.coachingId,
                s.id,
                name: name,
                description: desc,
                amount: amount,
                cycle: cycle,
                lateFinePerDay: fine,
                taxType: taxType,
                gstRate: gstRate,
                sacCode: sacCode,
                hsnCode: hsnCode,
                gstSupplyType: gstSupplyType,
                cessRate: cessRate,
                lineItems: lineItems,
                allowInstallments: allowInstallments,
                installmentCount: installmentCount,
                installmentAmounts: installmentAmounts,
              );
              _load();
            },
      ),
    );
  }

  Future<void> _deleteStructure(FeeStructureModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Remove Structure',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Remove "${s.name}"? If it has active records it will be archived instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _svc.deleteStructure(widget.coachingId, s.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
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
          'Fee Structure',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.history_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Audit Log',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FeeAuditLogScreen(coachingId: widget.coachingId),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _loading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _showCreateSheet,
              backgroundColor: theme.colorScheme.primary,
              tooltip: 'New Fee Structure',
              child: Icon(
                Icons.add_rounded,
                color: theme.colorScheme.onPrimary,
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: theme.colorScheme.primary,
              onRefresh: _load,
              child: _structures.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 56,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: Spacing.sp16),
                              Text(
                                'No fee structures yet',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: FontSize.sub,
                                ),
                              ),
                              const SizedBox(height: Spacing.sp8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Spacing.sp40,
                                ),
                                child: Text(
                                  'Tap + to create structures like "Monthly Tuition" or "Annual Fee". Each can be assigned to multiple students.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: FontSize.body,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.sp16,
                        Spacing.sp16,
                        Spacing.sp16,
                        96,
                      ),
                      children: _structures
                          .map(
                            (s) => _StructureCard(
                              structure: s,
                              onEdit: () => _showEditSheet(s),
                              onDelete: () => _deleteStructure(s),
                            ),
                          )
                          .toList(),
                    ),
            ),
    );
  }
}

// ── Structure card ─────────────────────────────────────────────────────────

class _StructureCard extends StatelessWidget {
  final FeeStructureModel structure;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StructureCard({
    required this.structure,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sp12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp16,
              Spacing.sp14,
              Spacing.sp8,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sp8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(
                    Icons.receipt_rounded,
                    color: theme.colorScheme.onSurface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: Spacing.sp12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        structure.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: FontSize.body,
                        ),
                      ),
                      if (structure.description != null &&
                          structure.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: Spacing.sp2),
                          child: Text(
                            structure.description!,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: FontSize.caption,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  color: theme.colorScheme.onSurfaceVariant,
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: Spacing.sp10),
                          Text(
                            'Remove',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Amount + cycle
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp16,
              Spacing.sp10,
              Spacing.sp16,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u20b9${structure.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: FontSize.hero,
                  ),
                ),
                const SizedBox(width: Spacing.sp6),
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp4),
                  child: Text(
                    '/ ${structure.cycleLabel}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: FontSize.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.sp16,
              Spacing.sp10,
              Spacing.sp16,
              Spacing.sp14,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(
                  icon: Icons.people_rounded,
                  label:
                      '${structure.assignmentCount} student${structure.assignmentCount == 1 ? "" : "s"}',
                ),
                if (structure.lateFinePerDay > 0)
                  _Chip(
                    icon: Icons.access_time_rounded,
                    label:
                        'Late \u20b9${structure.lateFinePerDay.toStringAsFixed(0)}/day',
                  ),
                if (structure.hasTax)
                  _Chip(
                    icon: Icons.receipt_outlined,
                    label:
                        'GST ${structure.gstRate.toStringAsFixed(0)}% (${structure.taxType == "GST_INCLUSIVE" ? "Incl." : "Excl."})',
                  ),
                if (structure.lineItems.isNotEmpty)
                  _Chip(
                    icon: Icons.list_rounded,
                    label:
                        '${structure.lineItems.length} line item${structure.lineItems.length == 1 ? "" : "s"}',
                  ),
                if (structure.allowInstallments)
                  _Chip(
                    icon: Icons.credit_card_rounded,
                    label: structure.installmentCount > 0
                        ? '${structure.installmentCount} installments'
                        : 'Installments on',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sp8,
        vertical: Spacing.sp4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Spacing.sp4),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: FontSize.micro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Structure form sheet ────────────────────────────────────────────────────

class _StructureFormSheet extends StatefulWidget {
  final FeeStructureModel? existing;
  final Future<void> Function(
    String name,
    String? desc,
    double amount,
    String cycle,
    double fine, {
    String? taxType,
    double? gstRate,
    String? sacCode,
    String? hsnCode,
    String? gstSupplyType,
    double? cessRate,
    List<Map<String, dynamic>>? lineItems,
    bool? allowInstallments,
    int? installmentCount,
    List<Map<String, dynamic>>? installmentAmounts,
  })
  onSubmit;

  const _StructureFormSheet({this.existing, required this.onSubmit});

  @override
  State<_StructureFormSheet> createState() => _StructureFormSheetState();
}

class _StructureFormSheetState extends State<_StructureFormSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  final _sacCtrl = TextEditingController();
  final _hsnCtrl = TextEditingController();
  final _installmentCountCtrl = TextEditingController();

  String _cycle = 'MONTHLY';
  String _taxType = 'NONE';
  double _gstRate = 18;
  String _supplyType = 'INTRA_STATE';
  bool _allowInstallments = false;
  bool _submitting = false;
  final List<_LineItem> _lineItems = [];
  final List<_InstallmentItem> _installmentAmounts = [];

  static const _cycles = [
    'ONCE',
    'MONTHLY',
    'QUARTERLY',
    'HALF_YEARLY',
    'YEARLY',
  ];
  static const _cycleLabels = {
    'ONCE': 'One-time',
    'MONTHLY': 'Monthly',
    'QUARTERLY': 'Quarterly',
    'HALF_YEARLY': 'Half-yearly',
    'YEARLY': 'Yearly',
  };
  static const _taxTypes = ['NONE', 'GST_INCLUSIVE', 'GST_EXCLUSIVE'];
  static const _taxLabels = {
    'NONE': 'No Tax',
    'GST_INCLUSIVE': 'GST Inclusive',
    'GST_EXCLUSIVE': 'GST Exclusive',
  };
  static const _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description ?? '';
      _amountCtrl.text = e.amount.toStringAsFixed(0);
      _fineCtrl.text = e.lateFinePerDay.toStringAsFixed(0);
      _cycle = e.cycle;
      _taxType = e.taxType;
      _gstRate = e.gstRate > 0 ? e.gstRate : 18;
      _supplyType = e.gstSupplyType;
      _sacCtrl.text = e.sacCode ?? '';
      _hsnCtrl.text = e.hsnCode ?? '';
      _allowInstallments = e.allowInstallments;
      if (e.installmentCount > 0) {
        _installmentCountCtrl.text = '${e.installmentCount}';
      }
      for (final item in e.lineItems) {
        _lineItems.add(
          _LineItem(
            labelCtrl: TextEditingController(text: item.label),
            amountCtrl: TextEditingController(
              text: item.amount.toStringAsFixed(0),
            ),
          ),
        );
      }
      for (final ia in e.installmentAmounts) {
        _installmentAmounts.add(
          _InstallmentItem(
            labelCtrl: TextEditingController(text: ia.label),
            amountCtrl: TextEditingController(
              text: ia.amount.toStringAsFixed(0),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _fineCtrl.dispose();
    _sacCtrl.dispose();
    _hsnCtrl.dispose();
    _installmentCountCtrl.dispose();
    for (final item in _lineItems) {
      item.labelCtrl.dispose();
      item.amountCtrl.dispose();
    }
    for (final item in _installmentAmounts) {
      item.labelCtrl.dispose();
      item.amountCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
      ),
      padding: EdgeInsets.only(
        left: Spacing.sp20,
        right: Spacing.sp20,
        top: Spacing.sp20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
              widget.existing != null ? 'Edit Structure' : 'New Fee Structure',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sp16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Monthly Tuition',
              ),
            ),
            const SizedBox(height: Spacing.sp12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: Spacing.sp12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount (₹) *',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: Spacing.sp14),
            Text(
              'Billing Cycle',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _cycles.map((c) {
                final sel = c == _cycle;
                return GestureDetector(
                  onTap: () => setState(() => _cycle = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp12,
                      vertical: Spacing.sp6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Text(
                      _cycleLabels[c] ?? c,
                      style: TextStyle(
                        color: sel
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontSize: FontSize.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.sp12),
            TextField(
              controller: _fineCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Late fine per day (₹)',
                hintText: '0',
              ),
            ),

            // ── Tax ──────────────────────────────────────────────
            const SizedBox(height: Spacing.sp20),
            const Divider(),
            const SizedBox(height: Spacing.sp12),
            Text(
              'Tax Configuration',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp10),
            Text(
              'Tax Type',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taxTypes.map((t) {
                final sel = t == _taxType;
                return GestureDetector(
                  onTap: () => setState(() => _taxType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp12,
                      vertical: Spacing.sp6,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                      borderRadius: BorderRadius.circular(Radii.lg),
                    ),
                    child: Text(
                      _taxLabels[t] ?? t,
                      style: TextStyle(
                        color: sel
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                        fontSize: FontSize.caption,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_taxType != 'NONE') ...[
              const SizedBox(height: Spacing.sp14),
              Text(
                'GST Rate',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontSize: FontSize.body,
                ),
              ),
              const SizedBox(height: Spacing.sp8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _gstRates.map((r) {
                  final sel = r == _gstRate;
                  return GestureDetector(
                    onTap: () => setState(() => _gstRate = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sp12,
                        vertical: Spacing.sp6,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ),
                        borderRadius: BorderRadius.circular(Radii.lg),
                      ),
                      child: Text(
                        '${r.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: sel
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          fontSize: FontSize.caption,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.sp14),
              Text(
                'Supply Type',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  fontSize: FontSize.body,
                ),
              ),
              const SizedBox(height: Spacing.sp8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                      ('INTRA_STATE', 'Intra-State (CGST+SGST)'),
                      ('INTER_STATE', 'Inter-State (IGST)'),
                    ].map((e) {
                      final sel = e.$1 == _supplyType;
                      return GestureDetector(
                        onTap: () => setState(() => _supplyType = e.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.sp12,
                            vertical: Spacing.sp6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                            borderRadius: BorderRadius.circular(Radii.lg),
                          ),
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              color: sel
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                              fontSize: FontSize.caption,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: Spacing.sp12),
              TextField(
                controller: _sacCtrl,
                decoration: const InputDecoration(
                  labelText: 'SAC Code (optional)',
                  hintText: 'e.g. 999293',
                ),
              ),
              const SizedBox(height: Spacing.sp12),
              TextField(
                controller: _hsnCtrl,
                decoration: const InputDecoration(
                  labelText: 'HSN Code (optional)',
                  hintText: 'For goods only',
                ),
              ),
            ],

            // ── Line Items ───────────────────────────────────────
            const SizedBox(height: Spacing.sp20),
            const Divider(),
            const SizedBox(height: Spacing.sp12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Items (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontSize: FontSize.body,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () {
                    setState(() {
                      _lineItems.add(
                        _LineItem(
                          labelCtrl: TextEditingController(),
                          amountCtrl: TextEditingController(),
                        ),
                      );
                    });
                  },
                ),
              ],
            ),
            if (_lineItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sp8),
                child: Text(
                  'Add breakdowns like "Books", "Lab Fee"',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: FontSize.caption,
                  ),
                ),
              ),
            ..._lineItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sp8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: item.labelCtrl,
                        decoration: InputDecoration(
                          labelText: 'Item ${i + 1}',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sp8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: item.amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '₹',
                          prefixText: '₹ ',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _lineItems[i].labelCtrl.dispose();
                          _lineItems[i].amountCtrl.dispose();
                          _lineItems.removeAt(i);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),

            // ── Installment Controls ─────────────────────────────
            const SizedBox(height: Spacing.sp20),
            const Divider(),
            const SizedBox(height: Spacing.sp12),
            Text(
              'Installment Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                fontSize: FontSize.body,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              'Control whether parents can pay in installments and define the allowed amounts.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: FontSize.caption,
              ),
            ),
            const SizedBox(height: Spacing.sp8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: theme.colorScheme.primary,
              title: Text(
                'Allow installment payments',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: FontSize.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _allowInstallments,
              onChanged: (v) => setState(() => _allowInstallments = v),
            ),
            if (_allowInstallments) ...[
              const SizedBox(height: Spacing.sp8),
              TextField(
                controller: _installmentCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of installments',
                  hintText: '0 = unlimited',
                ),
              ),
              const SizedBox(height: Spacing.sp14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fixed installment amounts',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontSize: FontSize.body,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _installmentAmounts.add(
                          _InstallmentItem(
                            labelCtrl: TextEditingController(
                              text:
                                  'Installment ${_installmentAmounts.length + 1}',
                            ),
                            amountCtrl: TextEditingController(),
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (_installmentAmounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp8),
                  child: Text(
                    'Leave empty to allow any amount. Add specific amounts to restrict payment options.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: FontSize.caption,
                    ),
                  ),
                ),
              ..._installmentAmounts.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.sp8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: item.labelCtrl,
                          decoration: InputDecoration(
                            labelText: 'Label ${i + 1}',
                            hintText: 'e.g. Q1 Payment',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sp8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: item.amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '₹',
                            prefixText: '₹ ',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _installmentAmounts[i].labelCtrl.dispose();
                            _installmentAmounts[i].amountCtrl.dispose();
                            _installmentAmounts.removeAt(i);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: Spacing.sp24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.onPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.existing != null ? 'Update' : 'Create Structure',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and a valid amount are required')),
      );
      return;
    }

    List<Map<String, dynamic>>? items;
    if (_lineItems.isNotEmpty) {
      items = _lineItems
          .where((li) => li.labelCtrl.text.trim().isNotEmpty)
          .map(
            (li) => {
              'label': li.labelCtrl.text.trim(),
              'amount': double.tryParse(li.amountCtrl.text.trim()) ?? 0,
            },
          )
          .toList();
    }

    List<Map<String, dynamic>>? installAmounts;
    if (_allowInstallments && _installmentAmounts.isNotEmpty) {
      installAmounts = _installmentAmounts
          .where((ia) => ia.labelCtrl.text.trim().isNotEmpty)
          .map(
            (ia) => {
              'label': ia.labelCtrl.text.trim(),
              'amount': double.tryParse(ia.amountCtrl.text.trim()) ?? 0,
            },
          )
          .toList();
    }

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        name,
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        amount,
        _cycle,
        double.tryParse(_fineCtrl.text) ?? 0,
        taxType: _taxType != 'NONE' ? _taxType : null,
        gstRate: _taxType != 'NONE' ? _gstRate : null,
        sacCode: _sacCtrl.text.trim().isNotEmpty ? _sacCtrl.text.trim() : null,
        hsnCode: _hsnCtrl.text.trim().isNotEmpty ? _hsnCtrl.text.trim() : null,
        gstSupplyType: _taxType != 'NONE' ? _supplyType : null,
        lineItems: items,
        allowInstallments: _allowInstallments,
        installmentCount: _allowInstallments
            ? (int.tryParse(_installmentCountCtrl.text.trim()) ?? 0)
            : 0,
        installmentAmounts: installAmounts,
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
}

class _LineItem {
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  _LineItem({required this.labelCtrl, required this.amountCtrl});
}

class _InstallmentItem {
  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;
  _InstallmentItem({required this.labelCtrl, required this.amountCtrl});
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 40,
          ),
          const SizedBox(height: Spacing.sp10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.sp16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
