import 'package:flutter/material.dart';
import '../../coaching/models/coaching_model.dart';
import '../services/batch_service.dart';

/// Screen to add coaching members to a batch (teachers or students).
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
            widget.coaching.id, widget.batchId,
            role: 'STUDENT'),
        _batchService.getAvailableMembers(
            widget.coaching.id, widget.batchId,
            role: 'TEACHER'),
      ]);
      _availableStudents = results[0];
      _availableTeachers = results[1];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
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
        title: const Text('Add Members'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: 'Students (${_availableStudents.length})'),
            Tab(text: 'Teachers (${_availableTeachers.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
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
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Add ${_selectedIds.length} Member${_selectedIds.length == 1 ? '' : 's'}'),
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
            Icon(Icons.person_off_outlined,
                size: 48,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('No available members',
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.4))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surfaceContainerLowest,
            leading: CircleAvatar(
              backgroundImage:
                  picture != null ? NetworkImage(picture) : null,
              child:
                  picture == null ? Text(name[0].toUpperCase()) : null,
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: email != null ? Text(email) : null,
            trailing: selected
                ? Icon(Icons.check_circle_rounded,
                    color: theme.colorScheme.primary)
                : Icon(Icons.radio_button_unchecked_rounded,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.3)),
            onTap: () => onToggle(id),
          ),
        );
      },
    );
  }
}
