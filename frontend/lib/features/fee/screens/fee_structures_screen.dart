import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';
import 'fee_audit_log_screen.dart';

/// Manages fee structures (templates) for a coaching.
/// Only ONE structure can be "current" at a time.
/// Creating a new structure automatically demotes the existing one.
class FeeStructuresScreen extends StatefulWidget {
  final String coachingId;
  const FeeStructuresScreen({super.key, required this.coachingId});

  @override
  State<FeeStructuresScreen> createState() => _FeeStructuresScreenState();
}

class _FeeStructuresScreenState extends State<FeeStructuresScreen> {
  final _svc = FeeService();

  FeeStructureModel? _current;
  List<FeeStructureModel> _previous = [];
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
        _current = all.where((s) => s.isCurrent).firstOrNull;
        _previous = all.where((s) => !s.isCurrent).toList()
          ..sort((a, b) {
            final aT = a.replacedAt ?? a.createdAt ?? DateTime(0);
            final bT = b.replacedAt ?? b.createdAt ?? DateTime(0);
            return bT.compareTo(aT);
          });
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

  Future<void> _initiateNewStructure() async {
    Map<String, dynamic>? preview;
    try {
      preview = await _svc.getStructureReplacePreview(widget.coachingId);
    } catch (_) {
      preview = {'hasCurrent': false, 'memberCount': 0, 'memberNames': []};
    }
    if (!mounted) return;

    final hasCurrent = preview['hasCurrent'] as bool? ?? false;

    if (hasCurrent) {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ReplaceWarningSheet(
          currentName: _current?.name ?? 'Current Structure',
          memberCount: (preview!['memberCount'] as num?)?.toInt() ?? 0,
          memberNames: List<String>.from(
            preview['memberNames'] as List<dynamic>? ?? [],
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    if (!mounted) return;
    _showCreateSheet();
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
        title: const Text(
          'Remove Structure',
          style: TextStyle(color: AppColors.darkOlive),
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Fee Structure',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.history_rounded,
              color: AppColors.mutedOlive,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : RefreshIndicator(
              color: AppColors.darkOlive,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_current != null) ...[
                    _SectionLabel(label: 'CURRENT STRUCTURE'),
                    const SizedBox(height: 8),
                    _CurrentStructureCard(
                      structure: _current!,
                      onEdit: () => _showEditSheet(_current!),
                      onReplace: _initiateNewStructure,
                    ),
                  ] else ...[
                    _EmptyCurrentCard(onCreate: _initiateNewStructure),
                  ],
                  const SizedBox(height: 24),
                  if (_previous.isNotEmpty) ...[
                    _SectionLabel(label: 'PREVIOUS STRUCTURES'),
                    const SizedBox(height: 8),
                    ..._previous.map(
                      (s) => _PreviousStructureTile(
                        structure: s,
                        onDelete: () => _deleteStructure(s),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.mutedOlive,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Current structure card ──────────────────────────────────────────────────

class _CurrentStructureCard extends StatelessWidget {
  final FeeStructureModel structure;
  final VoidCallback onEdit;
  final VoidCallback onReplace;

  const _CurrentStructureCard({
    required this.structure,
    required this.onEdit,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkOlive,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkOlive.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  structure.name,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cream.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: AppColors.cream,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          if (structure.description != null &&
              structure.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              structure.description!,
              style: TextStyle(
                color: AppColors.cream.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${structure.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${structure.cycleLabel}',
                  style: TextStyle(
                    color: AppColors.cream.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (structure.lateFinePerDay > 0)
                _InfoChip(
                  label:
                      'Late ₹${structure.lateFinePerDay.toStringAsFixed(0)}/day',
                  icon: Icons.access_time_rounded,
                ),
              if (structure.hasTax)
                _InfoChip(
                  label:
                      'GST ${structure.gstRate.toStringAsFixed(0)}% (${structure.taxType == 'GST_INCLUSIVE' ? 'Incl.' : 'Excl.'})',
                  icon: Icons.receipt_outlined,
                ),
              if (structure.lineItems.isNotEmpty)
                _InfoChip(
                  label:
                      '${structure.lineItems.length} line item${structure.lineItems.length == 1 ? '' : 's'}',
                  icon: Icons.list_rounded,
                ),
              _InfoChip(
                label:
                    '${structure.assignmentCount} student${structure.assignmentCount == 1 ? '' : 's'}',
                icon: Icons.people_rounded,
              ),
              if (structure.allowInstallments)
                _InfoChip(
                  label: structure.installmentCount > 0
                      ? '${structure.installmentCount} installments'
                      : 'Installments on',
                  icon: Icons.credit_card_rounded,
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cream,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cream,
                    foregroundColor: AppColors.darkOlive,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text(
                    'Change',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: onReplace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.cream.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.cream.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty current card ──────────────────────────────────────────────────────

class _EmptyCurrentCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyCurrentCard({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mutedOlive.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.mutedOlive,
          ),
          const SizedBox(height: 12),
          const Text(
            'No active fee structure',
            style: TextStyle(
              color: AppColors.darkOlive,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Set a fee structure like "Monthly Tuition" to begin assigning fees to students.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedOlive, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.darkOlive,
              foregroundColor: AppColors.cream,
            ),
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Set Fee Structure'),
          ),
        ],
      ),
    );
  }
}

// ── Replace-warning bottom sheet ────────────────────────────────────────────

class _ReplaceWarningSheet extends StatelessWidget {
  final String currentName;
  final int memberCount;
  final List<String> memberNames;

  const _ReplaceWarningSheet({
    required this.currentName,
    required this.memberCount,
    required this.memberNames,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE65100),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Change Fee Structure?',
                  style: TextStyle(
                    color: AppColors.darkOlive,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.softGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_rounded,
                  size: 16,
                  color: AppColors.mutedOlive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current: $currentName',
                    style: const TextStyle(
                      color: AppColors.darkOlive,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (memberCount > 0) ...[
            Text(
              '$memberCount student${memberCount == 1 ? ' is' : 's are'} currently assigned to this structure:',
              style: const TextStyle(
                color: AppColors.darkOlive,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: memberNames.take(10).map((name) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: AppColors.mutedOlive,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.darkOlive,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (memberCount > 10) ...[
              const SizedBox(height: 4),
              Text(
                '...and ${memberCount - 10} more',
                style: const TextStyle(
                  color: AppColors.mutedOlive,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Existing students will keep their current records under the old structure. New assignments will use the new structure.',
              style: TextStyle(
                color: Color(0xFFBF360C),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    foregroundColor: AppColors.cream,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Proceed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Previous structure tile ─────────────────────────────────────────────────

class _PreviousStructureTile extends StatelessWidget {
  final FeeStructureModel structure;
  final VoidCallback onDelete;

  const _PreviousStructureTile({
    required this.structure,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.softGrey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.mutedOlive.withValues(alpha: 0.2),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 6,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.archive_rounded,
              color: Colors.grey,
              size: 18,
            ),
          ),
          title: Text(
            structure.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '₹${structure.amount.toStringAsFixed(0)} · ${structure.cycleLabel}'
            '${structure.replacedAt != null ? ' · Replaced ${_fmtDate(structure.replacedAt!)}' : ''}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Colors.grey,
              size: 18,
            ),
            onSelected: (v) {
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) {
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
  return '${d.day} ${months[d.month - 1]} ${d.year}';
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
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
                  color: AppColors.softGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing != null ? 'Edit Structure' : 'New Fee Structure',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Monthly Tuition',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 14),
            const Text(
              'Billing Cycle',
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
              children: _cycles.map((c) {
                final sel = c == _cycle;
                return GestureDetector(
                  onTap: () => setState(() => _cycle = c),
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
                    ),
                    child: Text(
                      _cycleLabels[c] ?? c,
                      style: TextStyle(
                        color: sel ? AppColors.cream : AppColors.darkOlive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Tax Configuration',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.darkOlive,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tax Type',
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
              children: _taxTypes.map((t) {
                final sel = t == _taxType;
                return GestureDetector(
                  onTap: () => setState(() => _taxType = t),
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
                    ),
                    child: Text(
                      _taxLabels[t] ?? t,
                      style: TextStyle(
                        color: sel ? AppColors.cream : AppColors.darkOlive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_taxType != 'NONE') ...[
              const SizedBox(height: 14),
              const Text(
                'GST Rate',
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
                children: _gstRates.map((r) {
                  final sel = r == _gstRate;
                  return GestureDetector(
                    onTap: () => setState(() => _gstRate = r),
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
                      ),
                      child: Text(
                        '${r.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: sel ? AppColors.cream : AppColors.darkOlive,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              const Text(
                'Supply Type',
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
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.darkOlive
                                : AppColors.softGrey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            e.$2,
                            style: TextStyle(
                              color: sel
                                  ? AppColors.cream
                                  : AppColors.darkOlive,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sacCtrl,
                decoration: const InputDecoration(
                  labelText: 'SAC Code (optional)',
                  hintText: 'e.g. 999293',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hsnCtrl,
                decoration: const InputDecoration(
                  labelText: 'HSN Code (optional)',
                  hintText: 'For goods only',
                ),
              ),
            ],

            // ── Line Items ───────────────────────────────────────
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Line Items (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkOlive,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_rounded,
                    color: AppColors.darkOlive,
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
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Add breakdowns like "Books", "Lab Fee"',
                  style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
                ),
              ),
            ..._lineItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
                    const SizedBox(width: 8),
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
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Color(0xFFC62828),
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
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Installment Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.darkOlive,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Control whether parents can pay in installments and define the allowed amounts.',
              style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.darkOlive,
              title: const Text(
                'Allow installment payments',
                style: TextStyle(
                  color: AppColors.darkOlive,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _allowInstallments,
              onChanged: (v) => setState(() => _allowInstallments = v),
            ),
            if (_allowInstallments) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _installmentCountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of installments',
                  hintText: '0 = unlimited',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fixed installment amounts',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkOlive,
                      fontSize: 13,
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
                      foregroundColor: AppColors.darkOlive,
                    ),
                  ),
                ],
              ),
              if (_installmentAmounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Leave empty to allow any amount. Add specific amounts to restrict payment options.',
                    style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
                  ),
                ),
              ..._installmentAmounts.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                      const SizedBox(width: 8),
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
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Color(0xFFC62828),
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

            const SizedBox(height: 24),
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
                    : Text(
                        widget.existing != null ? 'Update' : 'Set as Current',
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
