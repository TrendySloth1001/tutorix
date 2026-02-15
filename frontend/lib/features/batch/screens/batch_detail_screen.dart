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
import 'note_detail_screen.dart';

/// Full batch detail — overview, members, notes, notices via TabBar.
/// Premium design with layered header, rich cards, and polished interactions.
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Batch?'),
        content: const Text(
          'This will permanently delete this batch, including all members, notes, and notices.',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          // parent will receive true via Navigator.pop
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 220,
              floating: false,
              pinned: true,
              leading: BackButton(
                onPressed: () => Navigator.pop(context, _changed),
              ),
              actions: [
                if (_isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.more_horiz_rounded, size: 20),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (v) {
                        if (v == 'edit') _editBatch();
                        if (v == 'archive') _toggleArchive();
                        if (v == 'delete') _deleteBatch();
                      },
                      itemBuilder: (_) => [
                        _popupItem('edit', 'Edit Batch', Icons.edit_rounded),
                        _popupItem(
                          'archive',
                          b.isActive ? 'Archive Batch' : 'Reactivate',
                          b.isActive
                              ? Icons.archive_rounded
                              : Icons.unarchive_rounded,
                        ),
                        _popupItem(
                          'delete',
                          'Delete',
                          Icons.delete_rounded,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withValues(alpha: 0.75),
                        theme.colorScheme.secondary.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Subtle pattern overlay
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: 40,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                      ),
                      // Content
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 52),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                b.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (b.subject != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    b.subject!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (b.days.isNotEmpty || b.startTime != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      b.scheduleText,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabCtrl,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
                tabs: [
                  const Tab(text: 'Overview'),
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

  PopupMenuItem<String> _popupItem(
    String value,
    String text,
    IconData icon, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
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

    // Capacity calculation
    final capacity = batch.maxStudents > 0
        ? (students.length / batch.maxStudents).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        // ── Capacity progress (if maxStudents > 0)
        if (batch.maxStudents > 0) ...[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Capacity',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${students.length}/${batch.maxStudents}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: capacity,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.onSurface.withValues(
                      alpha: 0.06,
                    ),
                    color: capacity > 0.9
                        ? Colors.red
                        : capacity > 0.7
                        ? Colors.orange
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  capacity >= 1.0
                      ? 'Batch is full'
                      : '${((1 - capacity) * batch.maxStudents).round()} spots remaining',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Description
        if (batch.description != null && batch.description!.isNotEmpty) ...[
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  batch.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Schedule card
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Schedule',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (batch.days.isNotEmpty)
                _DetailRow(
                  'Days',
                  batch.days.map(BatchModel.shortDay).join(', '),
                ),
              if (batch.startTime != null)
                _DetailRow('Start', batch.startTime!),
              if (batch.endTime != null) _DetailRow('End', batch.endTime!),
              _DetailRow(
                'Status',
                batch.isActive ? 'Active' : 'Archived',
                valueColor: batch.isActive
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Teachers list
        if (teachers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(
              'Teachers',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...teachers.map((t) => _MemberTile(member: t)),
        ],
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// Removed _OverviewStat — stat cards no longer shown

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
    final teachers = members.where((m) => m.role == 'TEACHER').toList();
    final students = members.where((m) => m.role == 'STUDENT').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _ActionButton(
              icon: Icons.person_add_rounded,
              label: 'Add Members',
              onTap: onAdd,
            ),
          ),
        if (teachers.isNotEmpty) ...[
          _SectionHeader(
            'Teachers',
            count: teachers.length,
            icon: Icons.school_rounded,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          ...teachers.map(
            (m) => _MemberTile(
              member: m,
              onRemove: isAdmin ? () => onRemove(m) : null,
            ),
          ),
          const SizedBox(height: 20),
        ],
        _SectionHeader(
          'Students',
          count: students.length,
          icon: Icons.people_rounded,
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 10),
        if (students.isEmpty)
          _EmptySection(
            icon: Icons.person_off_outlined,
            text: 'No students yet',
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (isTeacher)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _ActionButton(
              icon: Icons.note_add_rounded,
              label: 'Share Note',
              onTap: onAdd,
            ),
          ),
        if (notes.isEmpty)
          _EmptySection(
            icon: Icons.note_outlined,
            text: 'No notes uploaded yet',
            subtitle: isTeacher
                ? 'Upload study materials for your students'
                : null,
          )
        else
          ...notes.map(
            (n) => _NoteCard(
              note: n,
              canDelete: isTeacher,
              onDelete: () => onDelete(n),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteDetailScreen(
                      note: n,
                      canDelete: isTeacher,
                      onDelete: () => onDelete(n),
                    ),
                  ),
                );
              },
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
  final VoidCallback? onTap;
  const _NoteCard({
    required this.note,
    required this.canDelete,
    required this.onDelete,
    this.onTap,
  });

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, Color(0xFFE53935)),
    'image': (Icons.image_rounded, Color(0xFF8E24AA)),
    'doc': (Icons.description_rounded, Color(0xFF1E88E5)),
    'link': (Icons.link_rounded, Color(0xFF00897B)),
  };

  (IconData, Color) _primaryType(ThemeData theme) {
    if (note.attachments.isEmpty) {
      return (Icons.note_outlined, theme.colorScheme.primary);
    }
    // Use the first attachment type for the main icon
    final first = note.attachments.first.fileType;
    return _typeConfig[first] ??
        (Icons.attach_file_rounded, theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _primaryType(theme);
    final hasFiles = note.attachments.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row with timestamp at top-right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced icon with gradient
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.18),
                            color.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: color.withValues(alpha: 0.12),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title with better typography
                          Text(
                            note.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note.description != null &&
                              note.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              note.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                                height: 1.4,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Timestamp in top-right
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (note.createdAt != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _timeAgo(note.createdAt!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        if (canDelete) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.red.shade600,
                              ),
                              onPressed: onDelete,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // ── Metadata row (attachment count & uploader with more space)
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Attachment count badge
                    if (hasFiles) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${note.attachments.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    // Uploader with avatar (no background container)
                    if (note.uploadedBy != null)
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Profile avatar
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              backgroundImage: note.uploadedBy!.picture != null
                                  ? NetworkImage(note.uploadedBy!.picture!)
                                  : null,
                              child: note.uploadedBy!.picture == null
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.7),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                note.uploadedBy!.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // ── Attachment chips (show max 2, then "...more")
                if (hasFiles) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Show first 2 attachments
                      ...note.attachments.take(2).map((a) {
                        final ac = _typeConfig[a.fileType] ??
                            (
                              Icons.attach_file_rounded,
                              theme.colorScheme.primary
                            );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ac.$2.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ac.$2.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ac.$1, size: 16, color: ac.$2),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(
                                  a.fileName ?? a.fileType.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ac.$2.withValues(alpha: 0.9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                a.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: ac.$2.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Show "...more" if there are more than 2
                      if (note.attachments.length > 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.more_horiz_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${note.attachments.length - 2} more',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (isTeacher)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _ActionButton(
              icon: Icons.campaign_rounded,
              label: 'Send Notice',
              onTap: onAdd,
            ),
          ),
        if (notices.isEmpty)
          _EmptySection(
            icon: Icons.campaign_outlined,
            text: 'No notices yet',
            subtitle: isTeacher ? 'Send announcements to batch members' : null,
          )
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

  static const _priorityConfig = {
    'urgent': (Color(0xFFEF4444), Icons.priority_high_rounded),
    'high': (Color(0xFFF59E0B), Icons.arrow_upward_rounded),
    'normal': (Color(0xFF3B82F6), Icons.remove_rounded),
    'low': (Color(0xFF9CA3AF), Icons.arrow_downward_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config =
        _priorityConfig[notice.priority] ??
        (const Color(0xFF3B82F6), Icons.remove_rounded);
    final color = config.$1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: notice.isImportant
              ? color.withValues(alpha: 0.2)
              : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          if (notice.isImportant)
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority accent strip for urgent/high
          if (notice.isImportant)
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.4)],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(config.$2, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            notice.priorityLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (notice.createdAt != null)
                      Text(
                        _timeAgo(notice.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    if (canDelete)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.red.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.6,
                  ),
                ),
                if (notice.sentBy != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundImage: notice.sentBy!.picture != null
                            ? NetworkImage(notice.sentBy!.picture!)
                            : null,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        child: notice.sentBy!.picture == null
                            ? Text(
                                (notice.sentBy!.name ?? 'T')[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notice.sentBy!.name ?? 'Teacher',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

/// Detail row used in schedule cards.

/// Prominent action button used in tab headers.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final int count;
  final IconData icon;
  final Color color;
  const _SectionHeader(
    this.text, {
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          '$text ($count)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      ],
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
    final isTeacher = member.role == 'TEACHER';
    final roleColor = isTeacher
        ? const Color(0xFF10B981)
        : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: member.displayPicture != null
                ? NetworkImage(member.displayPicture!)
                : null,
            backgroundColor: roleColor.withValues(alpha: 0.1),
            child: member.displayPicture == null
                ? Text(
                    member.displayName[0].toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: roleColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (member.subtitle.isNotEmpty)
                  Text(
                    member.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              member.role,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: roleColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (onRemove != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.red.withValues(alpha: 0.5),
                ),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  const _EmptySection({required this.icon, required this.text, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
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
