import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../coaching/models/member_model.dart';
import '../../coaching/services/member_service.dart';
import '../models/fee_model.dart';
import '../services/fee_service.dart';

/// Screen to assign a fee structure to one or more students.
class AssignFeeScreen extends StatefulWidget {
  final String coachingId;
  const AssignFeeScreen({super.key, required this.coachingId});

  @override
  State<AssignFeeScreen> createState() => _AssignFeeScreenState();
}

class _AssignFeeScreenState extends State<AssignFeeScreen> {
  final _feeSvc = FeeService();
  final _memberSvc = MemberService();

  List<FeeStructureModel> _structures = [];
  List<MemberModel> _members = [];
  bool _loading = true;
  String? _error;

  FeeStructureModel? _selectedStructure;
  final Set<String> _selectedMemberIds = {};

  final _customAmountCtrl = TextEditingController();
  final _discountAmountCtrl = TextEditingController();
  final _discountReasonCtrl = TextEditingController();
  DateTime? _startDate;
  bool _customAmountEnabled = false;
  bool _submitting = false;

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
      final results = await Future.wait([
        _feeSvc.listStructures(widget.coachingId),
        _memberSvc.getMembers(widget.coachingId),
      ]);
      final structures = results[0] as List<FeeStructureModel>;
      final members = (results[1] as List<MemberModel>)
          .where((m) => m.role == 'STUDENT' && m.status == 'active')
          .toList();
      setState(() {
        _structures = structures.where((s) => s.isActive).toList();
        _members = members;
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Assign Fee',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorRetry(error: _error!, onRetry: _load)
          : _Body(
              structures: _structures,
              members: _members,
              selectedStructure: _selectedStructure,
              selectedMemberIds: _selectedMemberIds,
              customAmountCtrl: _customAmountCtrl,
              discountAmountCtrl: _discountAmountCtrl,
              discountReasonCtrl: _discountReasonCtrl,
              startDate: _startDate,
              customAmountEnabled: _customAmountEnabled,
              onStructureChanged: (s) => setState(() {
                _selectedStructure = s;
                _customAmountCtrl.text = s.amount.toStringAsFixed(0);
              }),
              onMemberToggled: (id) => setState(() {
                if (_selectedMemberIds.contains(id)) {
                  _selectedMemberIds.remove(id);
                } else {
                  _selectedMemberIds.add(id);
                }
              }),
              onSelectAll: () => setState(() {
                _selectedMemberIds.addAll(_members.map((m) => m.id));
              }),
              onClearAll: () => setState(() => _selectedMemberIds.clear()),
              onCustomAmountToggled: (v) =>
                  setState(() => _customAmountEnabled = v),
              onStartDateChanged: (d) => setState(() => _startDate = d),
              onSubmit: _submit,
              submitting: _submitting,
            ),
    );
  }

  Future<void> _submit() async {
    if (_selectedStructure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a fee structure')));
      return;
    }
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one student')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final customAmount = _customAmountEnabled
          ? double.tryParse(_customAmountCtrl.text.trim())
          : null;
      final discount = double.tryParse(_discountAmountCtrl.text.trim()) ?? 0;
      await Future.wait(
        _selectedMemberIds.map(
          (mId) => _feeSvc.assignFee(
            widget.coachingId,
            memberId: mId,
            feeStructureId: _selectedStructure!.id,
            customAmount: customAmount,
            discountAmount: discount > 0 ? discount : null,
            discountReason: _discountReasonCtrl.text.trim().isEmpty
                ? null
                : _discountReasonCtrl.text.trim(),
            startDate: _startDate,
          ),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fee assigned to ${_selectedMemberIds.length} student(s)',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _Body extends StatelessWidget {
  final List<FeeStructureModel> structures;
  final List<MemberModel> members;
  final FeeStructureModel? selectedStructure;
  final Set<String> selectedMemberIds;
  final TextEditingController customAmountCtrl;
  final TextEditingController discountAmountCtrl;
  final TextEditingController discountReasonCtrl;
  final DateTime? startDate;
  final bool customAmountEnabled;
  final ValueChanged<FeeStructureModel> onStructureChanged;
  final ValueChanged<String> onMemberToggled;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final ValueChanged<bool> onCustomAmountToggled;
  final ValueChanged<DateTime> onStartDateChanged;
  final VoidCallback onSubmit;
  final bool submitting;

  const _Body({
    required this.structures,
    required this.members,
    required this.selectedStructure,
    required this.selectedMemberIds,
    required this.customAmountCtrl,
    required this.discountAmountCtrl,
    required this.discountReasonCtrl,
    required this.startDate,
    required this.customAmountEnabled,
    required this.onStructureChanged,
    required this.onMemberToggled,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onCustomAmountToggled,
    required this.onStartDateChanged,
    required this.onSubmit,
    required this.submitting,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Fee Structure
          _StepHeader(step: '1', title: 'Select Fee Structure'),
          const SizedBox(height: 12),
          if (structures.isEmpty)
            const _Hint('No active fee structures. Create one first.')
          else
            ...structures.map(
              (s) => _StructureOption(
                structure: s,
                isSelected: selectedStructure?.id == s.id,
                onTap: () => onStructureChanged(s),
              ),
            ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // Step 2: Override amount / discount
          _StepHeader(step: '2', title: 'Pricing (Optional)'),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: customAmountEnabled,
                onChanged: onCustomAmountToggled,
                activeColor: AppColors.darkOlive,
              ),
              const SizedBox(width: 8),
              const Text(
                'Custom amount for this assignment',
                style: TextStyle(color: AppColors.darkOlive, fontSize: 13),
              ),
            ],
          ),
          if (customAmountEnabled) ...[
            const SizedBox(height: 10),
            TextField(
              controller: customAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Custom Amount (₹)',
                prefixText: '₹ ',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: discountAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Discount Amount (₹)',
              prefixText: '₹ ',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: discountReasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Discount Reason',
              hintText: 'e.g. Sibling discount',
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null) onStartDateChanged(d);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.mutedOlive.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.mutedOlive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    startDate != null
                        ? 'Starts ${_fmtDate(startDate!)}'
                        : 'Start date: Today',
                    style: const TextStyle(
                      color: AppColors.darkOlive,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),

          // Step 3: Select Students
          Row(
            children: [
              _StepHeader(step: '3', title: 'Select Students'),
              const Spacer(),
              TextButton(
                onPressed: onSelectAll,
                child: const Text(
                  'All',
                  style: TextStyle(color: AppColors.darkOlive, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: AppColors.mutedOlive, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${selectedMemberIds.length} of ${members.length} selected',
            style: const TextStyle(color: AppColors.mutedOlive, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (members.isEmpty)
            const _Hint('No active students in this coaching.')
          else
            ...members.map(
              (m) => _MemberOption(
                member: m,
                isSelected: selectedMemberIds.contains(m.id),
                onTap: () => onMemberToggled(m.id),
              ),
            ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.cream,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Assign Fee to ${selectedMemberIds.length} Student${selectedMemberIds.length == 1 ? '' : 's'}',
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String step;
  final String title;
  const _StepHeader({required this.step, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.darkOlive,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.cream,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.darkOlive,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _StructureOption extends StatelessWidget {
  final FeeStructureModel structure;
  final bool isSelected;
  final VoidCallback onTap;
  const _StructureOption({
    required this.structure,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkOlive.withValues(alpha: 0.08)
              : AppColors.softGrey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.darkOlive
                : AppColors.mutedOlive.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.darkOlive : AppColors.mutedOlive,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    structure.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.darkOlive
                          : AppColors.darkOlive.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '₹${structure.amount.toStringAsFixed(0)} · ${structure.cycleLabel}',
                    style: const TextStyle(
                      color: AppColors.mutedOlive,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberOption extends StatelessWidget {
  final MemberModel member;
  final bool isSelected;
  final VoidCallback onTap;
  const _MemberOption({
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.darkOlive.withValues(alpha: 0.07)
              : AppColors.softGrey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.darkOlive
                : AppColors.mutedOlive.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.softGrey,
              backgroundImage:
                  (member.user?.picture ?? member.ward?.picture) != null
                  ? NetworkImage(member.user?.picture ?? member.ward!.picture!)
                  : null,
              child: (member.user?.picture ?? member.ward?.picture) == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.mutedOlive,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                member.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkOlive,
                  fontSize: 13,
                ),
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap(),
              activeColor: AppColors.darkOlive,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.mutedOlive, fontSize: 13),
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
