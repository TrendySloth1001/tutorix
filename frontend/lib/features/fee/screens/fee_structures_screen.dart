import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

/// Manage fee structures (templates) for a coaching.
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
      final d = await _svc.listStructures(widget.coachingId);
      setState(() {
        _structures = d;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          'Fee Structures',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.darkOlive),
            onPressed: () => _showCreateSheet(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _structures.isEmpty
          ? _EmptyState(onCreate: _showCreateSheet)
          : RefreshIndicator(
              color: AppColors.darkOlive,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _structures.length,
                itemBuilder: (ctx, i) => _StructureTile(
                  structure: _structures[i],
                  onEdit: () => _showEditSheet(_structures[i]),
                  onDelete: () => _deleteStructure(_structures[i]),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.darkOlive,
        foregroundColor: AppColors.cream,
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Structure'),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StructureFormSheet(
        onSubmit: (name, desc, amount, cycle, fine) async {
          await _svc.createStructure(
            widget.coachingId,
            name: name,
            description: desc,
            amount: amount,
            cycle: cycle,
            lateFinePerDay: fine,
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
        onSubmit: (name, desc, amount, cycle, fine) async {
          await _svc.updateStructure(
            widget.coachingId,
            s.id,
            name: name,
            description: desc,
            amount: amount,
            cycle: cycle,
            lateFinePerDay: fine,
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
          'Delete Structure',
          style: TextStyle(color: AppColors.darkOlive),
        ),
        content: Text(
          'Delete "${s.name}"? If it has active records it will be deactivated instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
}

class _StructureTile extends StatelessWidget {
  final FeeStructureModel structure;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _StructureTile({
    required this.structure,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.softGrey.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mutedOlive.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.darkOlive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_rounded,
            color: AppColors.darkOlive,
            size: 20,
          ),
        ),
        title: Text(
          structure.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${structure.amount.toStringAsFixed(0)} · ${structure.cycleLabel}',
              style: const TextStyle(color: AppColors.mutedOlive, fontSize: 12),
            ),
            if (structure.lateFinePerDay > 0)
              Text(
                'Late fine: ₹${structure.lateFinePerDay}/day',
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 11),
              ),
            Text(
              '${structure.assignmentCount} student${structure.assignmentCount == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.mutedOlive, fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.mutedOlive,
          ),
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _StructureFormSheet extends StatefulWidget {
  final FeeStructureModel? existing;
  final Future<void> Function(
    String name,
    String? desc,
    double amount,
    String cycle,
    double fine,
  )
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
  String _cycle = 'MONTHLY';
  bool _submitting = false;

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

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description ?? '';
      _amountCtrl.text = widget.existing!.amount.toStringAsFixed(0);
      _fineCtrl.text = widget.existing!.lateFinePerDay.toStringAsFixed(0);
      _cycle = widget.existing!.cycle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            const SizedBox(height: 20),
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
                    : Text(widget.existing != null ? 'Update' : 'Create'),
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
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        name,
        _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        amount,
        _cycle,
        double.tryParse(_fineCtrl.text) ?? 0,
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

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 52,
            color: AppColors.mutedOlive,
          ),
          const SizedBox(height: 12),
          const Text(
            'No fee structures yet',
            style: TextStyle(
              color: AppColors.mutedOlive,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create templates like "Monthly Tuition"\nto assign to students.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mutedOlive, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Structure'),
          ),
        ],
      ),
    );
  }
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
