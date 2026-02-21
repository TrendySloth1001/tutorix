import 'package:flutter/material.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';
import '../../../core/theme/design_tokens.dart';

/// Screen to add coaching members to a batch (teachers or students).
/// Premium design with polished selection and tab experience.
class AddBatchMembersScreen extends StatefulWidget {
  final CoachingModel coaching;
  final String batchId;

  const AddBatchMembersScreen({
    super.key,
    required this.coaching,
    required this.batchId,
  });

  @override
  State<AddBatchMembersScreen> createState() => _AddBatchMembersScreenState();
}

class _AddBatchMembersScreenState extends State<AddBatchMembersScreen>
    with SingleTickerProviderStateMixin {
  final BatchService _batchService = BatchService();
  late TabController _tabCtrl;

  List<dynamic> _availableTeachers = [];
  List<dynamic> _availableStudents = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {};
  bool _isSaving = false;
  String _currentRole = 'STUDENT';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      setState(() {
        _currentRole = _tabCtrl.index == 0 ? 'STUDENT' : 'TEACHER';
        _selectedIds.clear();
      });
    });
    _loadAvailable();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailable() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _batchService.getAvailableMembers(
          widget.coaching.id,
          widget.batchId,
          role: 'STUDENT',
        ),
        _batchService.getAvailableMembers(
          widget.coaching.id,
          widget.batchId,
          role: 'TEACHER',
        ),
      ]);
      _availableStudents = results[0];
      _availableTeachers = results[1];
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to load members');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _batchService.addMembers(
        widget.coaching.id,
        widget.batchId,
        memberIds: _selectedIds.toList(),
        role: _currentRole,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to add members');
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Add Members',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          dividerColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: FontSize.body,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: FontSize.body,
          ),
          tabs: [
            Tab(text: 'Students (${_availableStudents.length})'),
            Tab(text: 'Teachers (${_availableTeachers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const AddMembersShimmer()
          : Column(
              children: [
                // Selection count banner
                if (_selectedIds.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sp20,
                      vertical: Spacing.sp10,
                    ),
                    color: theme.colorScheme.primary.withValues(alpha: 0.06),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: Spacing.sp8),
                        Text(
                          '${_selectedIds.length} selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _selectedIds.clear()),
                          child: Text(
                            'Clear',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _MemberList(
                        members: _availableStudents,
                        selectedIds: _selectedIds,
                        onToggle: _toggle,
                      ),
                      _MemberList(
                        members: _availableTeachers,
                        selectedIds: _selectedIds,
                        onToggle: _toggle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.sp20,
                  Spacing.sp8,
                  Spacing.sp20,
                  Spacing.sp16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSaving ? null : _save,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Spacing.sp16,
                        ),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: Spacing.sp24,
                                  height: Spacing.sp24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Add ${_selectedIds.length} Member${_selectedIds.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: FontSize.body,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _MemberList extends StatelessWidget {
  final List<dynamic> members;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  const _MemberList({
    required this.members,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Spacing.sp20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_outlined,
                size: 36,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: Spacing.sp16),
            Text(
              'No available members',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Spacing.sp4),
            Text(
              'All members have been added to this batch',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sp20,
        Spacing.sp12,
        Spacing.sp20,
        Spacing.sp80,
      ),
      itemCount: members.length,
      itemBuilder: (context, i) {
        final m = members[i] as Map<String, dynamic>;
        final id = m['id'] as String;
        final user = m['user'] as Map<String, dynamic>?;
        final ward = m['ward'] as Map<String, dynamic>?;
        final name =
            user?['name'] as String? ?? ward?['name'] as String? ?? 'Unknown';
        final picture =
            user?['picture'] as String? ?? ward?['picture'] as String?;
        final email = user?['email'] as String?;
        final selected = selectedIds.contains(id);

        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sp8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.06)
                  : theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.04),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.lg),
              child: InkWell(
                onTap: () => onToggle(id),
                borderRadius: BorderRadius.circular(Radii.lg),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sp14,
                    vertical: Spacing.sp12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: picture != null
                            ? NetworkImage(picture)
                            : null,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: picture == null
                            ? Text(
                                name[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: Spacing.sp14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (email != null)
                              Text(
                                email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: FontSize.micro,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                key: const ValueKey('checked'),
                                color: theme.colorScheme.primary,
                                size: 24,
                              )
                            : Icon(
                                Icons.radio_button_unchecked_rounded,
                                key: const ValueKey('unchecked'),
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.2,
                                ),
                                size: 24,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
