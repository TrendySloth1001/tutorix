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
  FeeStructureModel? _selectedStructure;
  List<MemberModel> _members = [];
  bool _loading = true;
  String? _error;

  final Set<String> _selectedMemberIds = {};

  final _customAmountCtrl = TextEditingController();
  final _discountAmountCtrl = TextEditingController();
  final _discountReasonCtrl = TextEditingController();
  final _scholarshipTagCtrl = TextEditingController();
  final _scholarshipAmountCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _customAmountEnabled = false;
  bool _submitting = false;
  final Map<String, _AssignmentPreview?> _previews = {};

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
      final structures = (results[0] as List).cast<FeeStructureModel>();
      final members = (results[1] as List<MemberModel>)
          .where((m) => m.role == 'STUDENT' && m.status == 'active')
          .toList();
      if (!mounted) return;
      setState(() {
        _structures = structures;
        _selectedStructure = structures.isNotEmpty ? structures.first : null;
        _members = members;
        if (_selectedStructure != null) {
          _customAmountCtrl.text = _selectedStructure!.amount.toStringAsFixed(
            0,
          );
        }
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
              selectedStructure: _selectedStructure,
              onStructureSelected: (s) => setState(() {
                _selectedStructure = s;
                if (!_customAmountEnabled) {
                  _customAmountCtrl.text = s.amount.toStringAsFixed(0);
                }
              }),
              members: _members,
              selectedMemberIds: _selectedMemberIds,
              customAmountCtrl: _customAmountCtrl,
              discountAmountCtrl: _discountAmountCtrl,
              discountReasonCtrl: _discountReasonCtrl,
              scholarshipTagCtrl: _scholarshipTagCtrl,
              scholarshipAmountCtrl: _scholarshipAmountCtrl,
              startDate: _startDate,
              endDate: _endDate,
              customAmountEnabled: _customAmountEnabled,
              onMemberToggled: _onMemberToggled,
              onSelectAll: () {
                final newIds = _members
                    .map((m) => m.id)
                    .where((id) => !_selectedMemberIds.contains(id))
                    .toList();
                setState(() {
                  for (final id in newIds) {
                    _selectedMemberIds.add(id);
                    _previews[id] = null;
                  }
                });
                for (final id in newIds) {
                  _fetchPreview(id);
                }
              },
              onClearAll: () => setState(() {
                _selectedMemberIds.clear();
                _previews.clear();
              }),
              onCustomAmountToggled: (v) =>
                  setState(() => _customAmountEnabled = v),
              onStartDateChanged: (d) => setState(() => _startDate = d),
              onEndDateChanged: (d) => setState(() => _endDate = d),
              onSubmit: _submit,
              submitting: _submitting,
              previews: _previews,
              onApplyCredit: (amount) => setState(
                () => _discountAmountCtrl.text = amount.toStringAsFixed(0),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    _discountAmountCtrl.dispose();
    _discountReasonCtrl.dispose();
    _scholarshipTagCtrl.dispose();
    _scholarshipAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStructure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fee structure selected. Create one in Fee Structures first.',
          ),
        ),
      );
      return;
    }
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one student')),
      );
      return;
    }
    setState(() => _submitting = true);

    final customAmount = _customAmountEnabled
        ? double.tryParse(_customAmountCtrl.text.trim())
        : null;
    final discount = double.tryParse(_discountAmountCtrl.text.trim()) ?? 0;
    final scholarshipAmt =
        double.tryParse(_scholarshipAmountCtrl.text.trim()) ?? 0;
    final scholarshipTag = _scholarshipTagCtrl.text.trim();
    final discountReason = _discountReasonCtrl.text.trim();

    // M19: Handle partial failures — don't let one failure abort all
    final memberIds = _selectedMemberIds.toList();
    final List<String> succeeded = [];
    final List<String> failed = [];

    for (final mId in memberIds) {
      try {
        await _feeSvc.assignFee(
          widget.coachingId,
          memberId: mId,
          feeStructureId: _selectedStructure!.id,
          customAmount: customAmount,
          discountAmount: discount > 0 ? discount : null,
          discountReason: discountReason.isEmpty ? null : discountReason,
          scholarshipTag: scholarshipTag.isEmpty ? null : scholarshipTag,
          scholarshipAmount: scholarshipAmt > 0 ? scholarshipAmt : null,
          startDate: _startDate,
          endDate: _endDate,
        );
        succeeded.add(mId);
      } catch (_) {
        failed.add(mId);
      }
    }

    if (!mounted) return;

    if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fee assigned to ${succeeded.length} student(s)'),
        ),
      );
      Navigator.pop(context);
    } else if (succeeded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign fee to all students'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      // Partial success — remove succeeded from selection
      setState(() {
        for (final id in succeeded) {
          _selectedMemberIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assigned to ${succeeded.length}, failed for ${failed.length} student(s). Retry for remaining.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    if (mounted) setState(() => _submitting = false);
  }

  void _onMemberToggled(String id) {
    final wasSelected = _selectedMemberIds.contains(id);
    setState(() {
      if (wasSelected) {
        _selectedMemberIds.remove(id);
        _previews.remove(id);
      } else {
        _selectedMemberIds.add(id);
        _previews[id] = null; // null = loading preview
      }
    });
    if (!wasSelected) _fetchPreview(id);
  }

  Future<void> _fetchPreview(String memberId) async {
    try {
      final data = await _feeSvc.getAssignmentPreview(
        widget.coachingId,
        memberId,
      );
      if (!mounted || !_selectedMemberIds.contains(memberId)) return;
      final preview = _AssignmentPreview.fromJson(data);
      setState(() {
        _previews[memberId] = preview;
      });
      // After state is set, offer to restore previous assignment settings
      if (preview.hasAssignment && preview.lastLog != null) {
        _showPullSettingsSheet(preview.lastLog!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _previews.remove(memberId));
    }
  }

  void _showPullSettingsSheet(_LastAssignmentLog log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PullSettingsSheet(
        log: log,
        onPull: () {
          if (mounted) {
            setState(() {
              if (log.customAmount != null) {
                _customAmountEnabled = true;
                _customAmountCtrl.text = log.customAmount!.toStringAsFixed(0);
              }
              final disc = log.discountAmount ?? 0;
              if (disc > 0) {
                _discountAmountCtrl.text = disc.toStringAsFixed(0);
              }
              if (log.discountReason != null &&
                  log.discountReason!.isNotEmpty) {
                _discountReasonCtrl.text = log.discountReason!;
              }
              if (log.scholarshipTag != null &&
                  log.scholarshipTag!.isNotEmpty) {
                _scholarshipTagCtrl.text = log.scholarshipTag!;
              }
              final schAmt = log.scholarshipAmount ?? 0;
              if (schAmt > 0) {
                _scholarshipAmountCtrl.text = schAmt.toStringAsFixed(0);
              }
            });
          }
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final List<FeeStructureModel> structures;
  final FeeStructureModel? selectedStructure;
  final ValueChanged<FeeStructureModel> onStructureSelected;
  final List<MemberModel> members;
  final Set<String> selectedMemberIds;
  final TextEditingController customAmountCtrl;
  final TextEditingController discountAmountCtrl;
  final TextEditingController discountReasonCtrl;
  final TextEditingController scholarshipTagCtrl;
  final TextEditingController scholarshipAmountCtrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool customAmountEnabled;
  final ValueChanged<String> onMemberToggled;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final ValueChanged<bool> onCustomAmountToggled;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final VoidCallback onSubmit;
  final bool submitting;
  final Map<String, _AssignmentPreview?> previews;
  final ValueChanged<double> onApplyCredit;

  const _Body({
    required this.structures,
    required this.selectedStructure,
    required this.onStructureSelected,
    required this.members,
    required this.selectedMemberIds,
    required this.customAmountCtrl,
    required this.discountAmountCtrl,
    required this.discountReasonCtrl,
    required this.scholarshipTagCtrl,
    required this.scholarshipAmountCtrl,
    required this.startDate,
    required this.endDate,
    required this.customAmountEnabled,
    required this.onMemberToggled,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onCustomAmountToggled,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onSubmit,
    required this.submitting,
    required this.previews,
    required this.onApplyCredit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Choose fee structure
          _StepHeader(step: '1', title: 'Fee Structure'),
          const SizedBox(height: 12),
          if (structures.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE65100).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFE65100),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No fee structures found. Create one in Fee Structures first.',
                      style: TextStyle(color: Color(0xFFBF360C), fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: structures.map((s) {
                final isSelected = selectedStructure?.id == s.id;
                return GestureDetector(
                  onTap: () => onStructureSelected(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.darkOlive.withValues(alpha: 0.07)
                          : AppColors.softGrey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.darkOlive.withValues(alpha: 0.5)
                            : AppColors.mutedOlive.withValues(alpha: 0.15),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.darkOlive
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.darkOlive
                                  : AppColors.mutedOlive,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: AppColors.cream,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? AppColors.darkOlive
                                      : AppColors.darkOlive,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '₹${s.amount.toStringAsFixed(0)} · ${s.cycleLabel}'
                                '${s.allowInstallments ? ' · Installments' : ''}',
                                style: const TextStyle(
                                  color: AppColors.mutedOlive,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${s.assignmentCount} student${s.assignmentCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.mutedOlive,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
                activeThumbColor: AppColors.darkOlive,
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
          const SizedBox(height: 16),
          // Scholarship fields (M18)
          TextField(
            controller: scholarshipTagCtrl,
            decoration: const InputDecoration(
              labelText: 'Scholarship Tag',
              hintText: 'e.g. Merit, Sports, Need-based',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: scholarshipAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Scholarship Amount (₹)',
              prefixText: '₹ ',
              hintText: '0',
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
              if (d != null) {
                onStartDateChanged(d);
              }
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
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate:
                    endDate ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: startDate ?? DateTime.now(),
                lastDate: DateTime(2035),
              );
              if (d != null) {
                onEndDateChanged(d);
              }
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
                    Icons.event_rounded,
                    size: 16,
                    color: AppColors.mutedOlive,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    endDate != null
                        ? 'Ends ${_fmtDate(endDate!)}'
                        : 'End date: None (ongoing)',
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

          _buildSettlementBanner(context),
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

  Widget _buildSettlementBanner(BuildContext context) {
    // Collect selected members that have partial payments pending settlement
    final withPartial = selectedMemberIds
        .where(
          (id) =>
              previews[id] != null &&
              previews[id]!.hasAssignment &&
              previews[id]!.partialRecords.isNotEmpty,
        )
        .map((id) => MapEntry(id, previews[id]!))
        .toList();

    if (withPartial.isEmpty) return const SizedBox.shrink();

    const cardColor = Color(0xFFFFF3E0);
    const borderColor = Color(0xFFFFB300);
    const titleColor = Color(0xFFBF360C);
    const bodyColor = Color(0xFF5D4037);
    const paidColor = Color(0xFF2E7D32);
    const waivedColor = Color(0xFFE65100);

    if (withPartial.length == 1) {
      final entry = withPartial.first;
      final preview = entry.value;
      final memberMatches = members.where((m) => m.id == entry.key).toList();
      final memberName = memberMatches.isNotEmpty
          ? memberMatches.first.displayName
          : 'Student';

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: waivedColor,
                  size: 15,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Settlement Preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$memberName is currently assigned to “${preview.currentStructureName}”.',
              style: const TextStyle(color: bodyColor, fontSize: 12),
            ),
            const SizedBox(height: 10),
            ...preview.partialRecords.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.title,
                        style: const TextStyle(
                          color: bodyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${r.paidAmount.toStringAsFixed(0)} paid',
                            style: const TextStyle(
                              color: paidColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            '  ·  ',
                            style: TextStyle(color: bodyColor, fontSize: 11),
                          ),
                          Text(
                            '₹${r.balance.toStringAsFixed(0)} remaining → auto-waived',
                            style: const TextStyle(
                              color: waivedColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (preview.totalPaid > 0) ...[
              const Divider(height: 16),
              GestureDetector(
                onTap: () => onApplyCredit(preview.totalPaid),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: paidColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: paidColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: paidColor,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Apply ₹${preview.totalPaid.toStringAsFixed(0)} already paid as discount on new structure',
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: paidColor,
                        size: 11,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Multiple students with partial payments
    final totalPaid = withPartial.fold(0.0, (s, e) => s + e.value.totalPaid);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: waivedColor, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${withPartial.length} student${withPartial.length == 1 ? '' : 's'} have partial payments '
              '(₹${totalPaid.toStringAsFixed(0)} total paid). '
              'Remaining balances will be auto-waived — no manual action needed.',
              style: const TextStyle(color: titleColor, fontSize: 12),
            ),
          ),
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

// ── Assignment preview models (local to this screen) ──────────────────────

class _PartialRecord {
  final String id;
  final String title;
  final double totalAmount;
  final double paidAmount;
  final double balance;

  const _PartialRecord({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.balance,
  });

  factory _PartialRecord.fromJson(Map<String, dynamic> j) => _PartialRecord(
    id: j['id'] as String,
    title: j['title'] as String,
    totalAmount: (j['totalAmount'] as num).toDouble(),
    paidAmount: (j['paidAmount'] as num).toDouble(),
    balance: (j['balance'] as num).toDouble(),
  );
}

class _AssignmentPreview {
  final bool hasAssignment;
  final String? currentStructureId;
  final String? currentStructureName;
  final List<_PartialRecord> partialRecords;
  final double totalPaid;
  final double totalBalance;
  final _LastAssignmentLog? lastLog;

  const _AssignmentPreview({
    required this.hasAssignment,
    this.currentStructureId,
    this.currentStructureName,
    required this.partialRecords,
    required this.totalPaid,
    required this.totalBalance,
    this.lastLog,
  });

  factory _AssignmentPreview.fromJson(Map<String, dynamic> j) =>
      _AssignmentPreview(
        hasAssignment: j['hasAssignment'] as bool? ?? false,
        currentStructureId: j['currentStructureId'] as String?,
        currentStructureName: j['currentStructureName'] as String?,
        partialRecords: ((j['partialRecords'] as List?) ?? [])
            .map((r) => _PartialRecord.fromJson(r as Map<String, dynamic>))
            .toList(),
        totalPaid: (j['totalPaid'] as num?)?.toDouble() ?? 0,
        totalBalance: (j['totalBalance'] as num?)?.toDouble() ?? 0,
        lastLog: j['lastLog'] != null
            ? _LastAssignmentLog.fromJson(j['lastLog'] as Map<String, dynamic>)
            : null,
      );
}

class _LastAssignmentLog {
  final double? customAmount;
  final double? discountAmount;
  final String? discountReason;
  final String? scholarshipTag;
  final double? scholarshipAmount;
  final String? assignedBy;
  final DateTime? assignedAt;

  const _LastAssignmentLog({
    this.customAmount,
    this.discountAmount,
    this.discountReason,
    this.scholarshipTag,
    this.scholarshipAmount,
    this.assignedBy,
    this.assignedAt,
  });

  factory _LastAssignmentLog.fromJson(Map<String, dynamic> j) =>
      _LastAssignmentLog(
        customAmount: (j['customAmount'] as num?)?.toDouble(),
        discountAmount: (j['discountAmount'] as num?)?.toDouble(),
        discountReason: j['discountReason'] as String?,
        scholarshipTag: j['scholarshipTag'] as String?,
        scholarshipAmount: (j['scholarshipAmount'] as num?)?.toDouble(),
        assignedBy: j['assignedBy'] as String?,
        assignedAt: j['assignedAt'] != null
            ? DateTime.tryParse(j['assignedAt'] as String)
            : null,
      );
}

// ── Pull-settings confirmation sheet ───────────────────────────────────

class _PullSettingsSheet extends StatelessWidget {
  final _LastAssignmentLog log;
  final VoidCallback onPull;

  const _PullSettingsSheet({required this.log, required this.onPull});

  @override
  Widget build(BuildContext context) {
    final rows = <_SettingRow>[];
    if (log.customAmount != null)
      rows.add(
        _SettingRow(
          icon: Icons.edit_rounded,
          label: 'Custom Amount',
          value: '₹${log.customAmount!.toStringAsFixed(0)}',
        ),
      );
    if ((log.discountAmount ?? 0) > 0)
      rows.add(
        _SettingRow(
          icon: Icons.discount_outlined,
          label: 'Discount',
          value:
              '₹${log.discountAmount!.toStringAsFixed(0)}' +
              (log.discountReason != null && log.discountReason!.isNotEmpty
                  ? ' — ${log.discountReason}'
                  : ''),
        ),
      );
    if (log.scholarshipTag != null && log.scholarshipTag!.isNotEmpty)
      rows.add(
        _SettingRow(
          icon: Icons.school_outlined,
          label: 'Scholarship',
          value:
              log.scholarshipTag! +
              ((log.scholarshipAmount ?? 0) > 0
                  ? ' (₹${log.scholarshipAmount!.toStringAsFixed(0)})'
                  : ''),
        ),
      );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.darkOlive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.darkOlive,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Assignment Found',
                      style: TextStyle(
                        color: AppColors.darkOlive,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'This student had custom settings last time. Want to reuse them?',
                      style: TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (log.assignedBy != null || log.assignedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (log.assignedBy != null) 'by ${log.assignedBy}',
                if (log.assignedAt != null) _fmtDate(log.assignedAt!),
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.mutedOlive,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Settings rows
          Container(
            decoration: BoxDecoration(
              color: AppColors.softGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: rows
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(r.icon, size: 15, color: AppColors.mutedOlive),
                          const SizedBox(width: 10),
                          Text(
                            r.label,
                            style: const TextStyle(
                              color: AppColors.mutedOlive,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            r.value,
                            style: const TextStyle(
                              color: AppColors.darkOlive,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mutedOlive,
                    side: const BorderSide(color: AppColors.softGrey),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkOlive,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onPull();
                  },
                  icon: const Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: AppColors.cream,
                  ),
                  label: const Text(
                    'Pull Settings',
                    style: TextStyle(color: AppColors.cream),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingRow {
  final IconData icon;
  final String label;
  final String value;
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });
}
