import 'package:flutter/material.dart';
import '../../../shared/models/user_model.dart';
import '../../coaching/models/coaching_model.dart';
import '../models/batch_model.dart';
import '../models/batch_member_model.dart';
import '../models/batch_note_model.dart';
import '../models/batch_notice_model.dart';
import '../services/batch_service.dart';
import 'create_batch_screen.dart';
import 'add_batch_members_screen.dart';
import 'create_note_screen.dart';
import 'create_notice_screen.dart';

/// Full batch detail — overview, members, notes, notices via TabBar.
class BatchDetailScreen extends StatefulWidget {
  final CoachingModel coaching;
  final String batchId;
  final UserModel user;

  const BatchDetailScreen({
    super.key,
    required this.coaching,
    required this.batchId,
    required this.user,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen>
    with SingleTickerProviderStateMixin {
  final BatchService _batchService = BatchService();
  late TabController _tabCtrl;

  BatchModel? _batch;
  List<BatchMemberModel> _members = [];
  List<BatchNoteModel> _notes = [];
  List<BatchNoticeModel> _notices = [];
  bool _isLoading = true;
  bool _changed = false;

  bool get _isAdmin =>
      widget.coaching.ownerId == widget.user.id ||
      widget.coaching.myRole == 'ADMIN';

  bool get _isTeacherOrAdmin {
    if (_isAdmin) return true;
    // Check if user is a teacher in this batch
    return _members.any(
      (m) => m.role == 'TEACHER' && m.user?.id == widget.user.id,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _batchService.getBatchById(widget.coaching.id, widget.batchId),
        _batchService.getMembers(widget.coaching.id, widget.batchId),
        _batchService.listNotes(widget.coaching.id, widget.batchId),
        _batchService.listNotices(widget.coaching.id, widget.batchId),
      ]);
      _batch = results[0] as BatchModel;
      _members = results[1] as List<BatchMemberModel>;
      _notes = results[2] as List<BatchNoteModel>;
      _notices = results[3] as List<BatchNoticeModel>;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _editBatch() async {
    if (_batch == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateBatchScreen(coaching: widget.coaching, batch: _batch),
      ),
    );
    if (changed == true) {
      _changed = true;
      _loadAll();
    }
  }

  void _deleteBatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Batch?'),
        content: const Text(
          'This will permanently delete this batch, all members, notes, and notices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _batchService.deleteBatch(widget.coaching.id, widget.batchId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _toggleArchive() async {
    if (_batch == null) return;
    final newStatus = _batch!.isActive ? 'archived' : 'active';
    try {
      await _batchService.updateBatch(
        widget.coaching.id,
        widget.batchId,
        status: newStatus,
      );
      _changed = true;
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _addMembers() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddBatchMembersScreen(
          coaching: widget.coaching,
          batchId: widget.batchId,
        ),
      ),
    );
    if (added == true) {
      _changed = true;
      _loadAll();
    }
  }

  void _removeMember(BatchMemberModel m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove ${m.displayName} from this batch?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _batchService.removeMember(
        widget.coaching.id,
        widget.batchId,
        m.id,
      );
      _changed = true;
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
      }
    }
  }

  void _addNote() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateNoteScreen(
          coaching: widget.coaching,
          batchId: widget.batchId,
        ),
      ),
    );
    if (added == true) {
      _changed = true;
      _loadAll();
    }
  }

  void _deleteNote(BatchNoteModel note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: Text('Delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _batchService.deleteNote(
        widget.coaching.id,
        widget.batchId,
        note.id,
      );
      _changed = true;
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _addNotice() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateNoticeScreen(
          coaching: widget.coaching,
          batchId: widget.batchId,
        ),
      ),
    );
    if (added == true) {
      _changed = true;
      _loadAll();
    }
  }

  void _deleteNotice(BatchNoticeModel notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: Text('Delete "${notice.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _batchService.deleteNotice(
        widget.coaching.id,
        widget.batchId,
        notice.id,
      );
      _changed = true;
      _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading && _batch == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_batch == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('Batch not found')),
      );
    }

    final b = _batch!;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) {
          // Already popping with true handled by pop(context, true)
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              leading: BackButton(
                onPressed: () => Navigator.pop(context, _changed),
              ),
              actions: [
                if (_isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editBatch();
                      if (v == 'archive') _toggleArchive();
                      if (v == 'delete') _deleteBatch();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Batch'),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(
                          b.isActive ? 'Archive Batch' : 'Reactivate',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  b.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (b.subject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                b.subject!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (b.days.isNotEmpty || b.startTime != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  b.scheduleText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Members (${_members.length})'),
                  Tab(text: 'Notes (${_notes.length})'),
                  Tab(text: 'Notices (${_notices.length})'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _OverviewTab(batch: b, members: _members),
              _MembersTab(
                members: _members,
                isAdmin: _isAdmin,
                onAdd: _addMembers,
                onRemove: _removeMember,
              ),
              _NotesTab(
                notes: _notes,
                isTeacher: _isTeacherOrAdmin,
                onAdd: _addNote,
                onDelete: _deleteNote,
              ),
              _NoticesTab(
                notices: _notices,
                isTeacher: _isTeacherOrAdmin,
                onAdd: _addNotice,
                onDelete: _deleteNotice,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final BatchModel batch;
  final List<BatchMemberModel> members;
  const _OverviewTab({required this.batch, required this.members});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teachers = members.where((m) => m.role == 'TEACHER').toList();
    final students = members.where((m) => m.role == 'STUDENT').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ── Stats cards
        Row(
          children: [
            _OverviewStat(
              icon: Icons.people_rounded,
              label: 'Students',
              value: '${students.length}',
              color: Colors.blue,
            ),
            const SizedBox(width: 12),
            _OverviewStat(
              icon: Icons.school_rounded,
              label: 'Teachers',
              value: '${teachers.length}',
              color: Colors.teal,
            ),
            const SizedBox(width: 12),
            _OverviewStat(
              icon: Icons.note_rounded,
              label: 'Notes',
              value: '${batch.noteCount}',
              color: Colors.orange,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Description
        if (batch.description != null && batch.description!.isNotEmpty) ...[
          Text(
            'About',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            batch.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Schedule details
        _DetailCard(
          title: 'Schedule',
          icon: Icons.calendar_today_rounded,
          children: [
            if (batch.days.isNotEmpty)
              _DetailRow(
                'Days',
                batch.days.map(BatchModel.shortDay).join(', '),
              ),
            if (batch.startTime != null) _DetailRow('Start', batch.startTime!),
            if (batch.endTime != null) _DetailRow('End', batch.endTime!),
          ],
        ),
        const SizedBox(height: 12),

        // ── Capacity
        _DetailCard(
          title: 'Capacity',
          icon: Icons.groups_rounded,
          children: [
            _DetailRow(
              'Max Students',
              batch.maxStudents > 0 ? '${batch.maxStudents}' : 'Unlimited',
            ),
            _DetailRow('Current', '${students.length} enrolled'),
            _DetailRow('Status', batch.isActive ? 'Active' : 'Archived'),
          ],
        ),
        const SizedBox(height: 12),

        // ── Teachers list
        if (teachers.isNotEmpty) ...[
          Text(
            'Teachers',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...teachers.map((t) => _MemberTile(member: t)),
        ],
      ],
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _DetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── MEMBERS TAB
// ═══════════════════════════════════════════════════════════════════════════

class _MembersTab extends StatelessWidget {
  final List<BatchMemberModel> members;
  final bool isAdmin;
  final VoidCallback onAdd;
  final void Function(BatchMemberModel) onRemove;
  const _MembersTab({
    required this.members,
    required this.isAdmin,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teachers = members.where((m) => m.role == 'TEACHER').toList();
    final students = members.where((m) => m.role == 'STUDENT').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Members'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (teachers.isNotEmpty) ...[
          _SectionHeader('Teachers (${teachers.length})'),
          const SizedBox(height: 8),
          ...teachers.map(
            (m) => _MemberTile(
              member: m,
              onRemove: isAdmin ? () => onRemove(m) : null,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionHeader('Students (${students.length})'),
        const SizedBox(height: 8),
        if (students.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No students yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          )
        else
          ...students.map(
            (m) => _MemberTile(
              member: m,
              onRemove: isAdmin ? () => onRemove(m) : null,
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final BatchMemberModel member;
  final VoidCallback? onRemove;
  const _MemberTile({required this.member, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: member.displayPicture != null
                ? NetworkImage(member.displayPicture!)
                : null,
            child: member.displayPicture == null
                ? Text(member.displayName[0].toUpperCase())
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (member.subtitle.isNotEmpty)
                  Text(
                    member.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: member.role == 'TEACHER'
                  ? Colors.teal.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              member.role,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: member.role == 'TEACHER'
                    ? Colors.teal.shade700
                    : Colors.blue.shade700,
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.red.withValues(alpha: 0.6),
              ),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── NOTES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _NotesTab extends StatelessWidget {
  final List<BatchNoteModel> notes;
  final bool isTeacher;
  final VoidCallback onAdd;
  final void Function(BatchNoteModel) onDelete;
  const _NotesTab({
    required this.notes,
    required this.isTeacher,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (isTeacher)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload Note'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (notes.isEmpty)
          _EmptySection(
            icon: Icons.note_outlined,
            text: 'No notes uploaded yet',
          )
        else
          ...notes.map(
            (n) => _NoteCard(
              note: n,
              canDelete: isTeacher,
              onDelete: () => onDelete(n),
            ),
          ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final BatchNoteModel note;
  final bool canDelete;
  final VoidCallback onDelete;
  const _NoteCard({
    required this.note,
    required this.canDelete,
    required this.onDelete,
  });

  IconData get _fileIcon {
    switch (note.fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'doc':
        return Icons.description_rounded;
      case 'video':
        return Icons.movie_rounded;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.attach_file_rounded;
    }
  }

  Color _fileColor(ThemeData theme) {
    switch (note.fileType) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.purple;
      case 'doc':
        return Colors.blue;
      case 'video':
        return Colors.orange;
      case 'link':
        return Colors.teal;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _fileColor(theme);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_fileIcon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note.description != null)
                  Text(
                    note.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (note.uploadedBy != null)
                      Text(
                        note.uploadedBy!.name ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    if (note.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(note.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.red.withValues(alpha: 0.6),
              ),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── NOTICES TAB
// ═══════════════════════════════════════════════════════════════════════════

class _NoticesTab extends StatelessWidget {
  final List<BatchNoticeModel> notices;
  final bool isTeacher;
  final VoidCallback onAdd;
  final void Function(BatchNoticeModel) onDelete;
  const _NoticesTab({
    required this.notices,
    required this.isTeacher,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (isTeacher)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.campaign_rounded, size: 18),
              label: const Text('Send Notice'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        if (notices.isEmpty)
          _EmptySection(icon: Icons.campaign_outlined, text: 'No notices yet')
        else
          ...notices.map(
            (n) => _NoticeCard(
              notice: n,
              canDelete: isTeacher,
              onDelete: () => onDelete(n),
            ),
          ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final BatchNoticeModel notice;
  final bool canDelete;
  final VoidCallback onDelete;
  const _NoticeCard({
    required this.notice,
    required this.canDelete,
    required this.onDelete,
  });

  Color _priorityColor() {
    switch (notice.priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _priorityColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: notice.isImportant
            ? Border.all(color: color.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    notice.priorityLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                if (notice.createdAt != null)
                  Text(
                    _timeAgo(notice.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                if (canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notice.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notice.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            if (notice.sentBy != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: notice.sentBy!.picture != null
                        ? NetworkImage(notice.sentBy!.picture!)
                        : null,
                    child: notice.sentBy!.picture == null
                        ? Text(
                            (notice.sentBy!.name ?? 'T')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 8),
                          )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    notice.sentBy!.name ?? 'Teacher',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptySection({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
