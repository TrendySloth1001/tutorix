import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/coaching_model.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';
import '../services/member_service.dart';
import 'coaching_notifications_screen.dart'; // Import the new screen (same directory)
import '../../../shared/services/notification_service.dart'; // Correct path
import '../../../shared/models/user_model.dart';
import '../../batch/services/batch_service.dart';
import '../../batch/models/batch_note_model.dart';
import '../../batch/screens/note_detail_screen.dart';

/// Coaching dashboard — compact, data-driven overview.
class CoachingDashboardScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel? user;
  final VoidCallback? onMembersTap;
  final VoidCallback? onBack;

  const CoachingDashboardScreen({
    super.key,
    required this.coaching,
    this.user,
    this.onMembersTap,
    this.onBack,
  });

  @override
  State<CoachingDashboardScreen> createState() =>
      _CoachingDashboardScreenState();
}

class _CoachingDashboardScreenState extends State<CoachingDashboardScreen> {
  final MemberService _memberService = MemberService();
  final NotificationService _notificationService = NotificationService();
  final BatchService _batchService = BatchService();

  List<MemberModel> _members = [];
  List<InvitationModel> _invitations = [];
  List<BatchNoteModel> _recentNotes = [];
  int _unreadNotifications = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load data with individual error handling to prevent one failure from blocking others
      final membersResult = await _memberService.getMembers(widget.coaching.id).catchError((e) {
        print('ERROR loading members: $e');
        return <MemberModel>[];
      });
      
      final invitationsResult = await _memberService.getInvitations(widget.coaching.id).catchError((e) {
        print('ERROR loading invitations: $e');
        return <InvitationModel>[];
      });
      
      final notificationsResult = await _notificationService.getCoachingNotifications(
        widget.coaching.id,
        limit: 1,
      ).catchError((e) {
        print('ERROR loading notifications: $e');
        return {'unreadCount': 0};
      });
      
      final notesResult = await _batchService.getRecentNotes(widget.coaching.id).catchError((e) {
        print('ERROR loading recent notes: $e');
        return <BatchNoteModel>[];
      });
      
      _members = membersResult;
      _invitations = invitationsResult;
      _unreadNotifications = notificationsResult['unreadCount'] ?? 0;
      _recentNotes = notesResult;
      
      print('DEBUG: Dashboard loaded - Members: ${_members.length}, Notes: ${_recentNotes.length}');
    } catch (e) {
      print('FATAL ERROR loading dashboard data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _onNotificationTap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CoachingNotificationsScreen(coachingId: widget.coaching.id),
      ),
    );
    _loadData(); // Refresh on return to update badge
  }

  void _navigateToNote(BatchNoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteDetailScreen(note: note),
      ),
    );
  }

  int _countRole(String role) => _members.where((m) => m.role == role).length;

  List<InvitationModel> get _pending =>
      _invitations.where((i) => i.isPending).toList();

  // Role helpers
  bool get _isOwner => widget.user != null && widget.coaching.isOwner(widget.user!.id);
  String? get _myRole => widget.coaching.myRole;
  bool get _isStudent => _myRole == 'STUDENT';
  bool get _isAdmin => _myRole == 'ADMIN';
  bool get _canManageMembers => _isAdmin || _isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.coaching;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // ── Fixed Header ──
          Container(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _Header(
                    coaching: c,
                    memberCount: _members.length,
                    unreadNotifications: _unreadNotifications,
                    onNotificationTap: _onNotificationTap,
                    onBack: widget.onBack,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // ── Scrollable Content ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [

            // ── Role badge (for students/teachers) ──
            if (!_canManageMembers && _myRole != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isStudent ? Icons.school_rounded : Icons.person_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _myRole!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Stat chips (only for admins/owners) ──
            if (_canManageMembers) ...[
              _StatChipRow(
                teachers: _countRole('TEACHER'),
                students: _countRole('STUDENT'),
                admins: _countRole('ADMIN'),
                pending: _pending.length,
              ),
              const SizedBox(height: 24),
            ],

            // ── Quick action (only for admins/owners) ──
            if (_canManageMembers) ...[
              _QuickAction(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Invite Members',
                onTap: widget.onMembersTap,
              ),
            ],

            // ── Recent Notes (priority for students) ──
            if (_recentNotes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: _isStudent ? 'Latest Notes' : 'Recent Notes',
                icon: Icons.sticky_note_2_outlined,
              ),
              const SizedBox(height: 8),
              _RecentNotesSection(
                notes: _recentNotes,
                onNoteTap: _navigateToNote,
              ),
            ],

            // ── Recent Members (only for admins/owners) ──
            if (_canManageMembers && _members.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Recent Members',
                trailing: _members.length > 5 ? 'See all' : null,
                onTrailingTap: widget.onMembersTap,
              ),
              const SizedBox(height: 8),
              ..._members.take(5).map((m) => _CompactMemberTile(member: m)),
            ],

            // ── Pending Invitations (only for admins/owners) ──
            if (_canManageMembers && _pending.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: 'Pending Invitations'),
              const SizedBox(height: 8),
              ..._pending.take(5).map((i) => _CompactInviteTile(invite: i)),
            ],

            // ── Student/Teacher Empty state ──
            if (!_canManageMembers && _recentNotes.isEmpty) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(
                      _isStudent ? Icons.wb_sunny_outlined : Icons.edit_note_outlined,
                      size: 56,
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isStudent ? 'All Caught Up! 🎉' : 'No Recent Activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isStudent
                          ? 'Today is free - nothing new from your teachers in the last 7 days.\nEnjoy your time!'
                          : 'Create notes in your batches to see them here',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.5,
                        ),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Admin Empty state ──
            if (_canManageMembers && _members.isEmpty && _pending.isEmpty) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.group_add_rounded,
                      size: 48,
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No members yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invite teachers and students to get started',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.4,
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
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widgets — compact, premium, zero static data
// ═══════════════════════════════════════════════════════════════════════════

/// Coaching name + avatar header with back button.
class _Header extends StatelessWidget {
  final CoachingModel coaching;
  final int memberCount;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback? onBack;

  const _Header({
    required this.coaching,
    required this.memberCount,
    required this.unreadNotifications,
    required this.onNotificationTap,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // Back Button - Carded style with shadow
        if (onBack != null) ...[
          Material(
            color: theme.colorScheme.surface,
            elevation: 2,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: coaching.logo != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(coaching.logo!, fit: BoxFit.cover),
                )
              : Icon(
                  Icons.school_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coaching.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$memberCount member${memberCount != 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: onNotificationTap,
              icon: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal row of small stat chips.
class _StatChipRow extends StatelessWidget {
  final int teachers, students, admins, pending;
  const _StatChipRow({
    required this.teachers,
    required this.students,
    required this.admins,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (admins > 0)
          _Chip(
            label: '$admins Admin${admins > 1 ? 's' : ''}',
            color: const Color(0xFF6B5B95),
          ),
        _Chip(
          label: '$teachers Teacher${teachers != 1 ? 's' : ''}',
          color: const Color(0xFF4A90A4),
        ),
        _Chip(
          label: '$students Student${students != 1 ? 's' : ''}',
          color: const Color(0xFF5B8C5A),
        ),
        if (pending > 0)
          _Chip(label: '$pending Pending', color: const Color(0xFFC48B3F)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Single-row quick action button.
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small section header with optional trailing action.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final IconData? icon;
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        if (trailing != null)
          GestureDetector(
            onTap: onTrailingTap,
            child: Text(
              trailing!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact member tile — avatar, name, role badge.
class _CompactMemberTile extends StatelessWidget {
  final MemberModel member;
  const _CompactMemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.primary.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: member.displayPicture != null
                  ? NetworkImage(member.displayPicture!)
                  : null,
              child: member.displayPicture == null
                  ? Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.subtitle.isNotEmpty)
                    Text(
                      member.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.5,
                        ),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _roleBadge(member.role),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    final (Color color, String label) = switch (role) {
      'ADMIN' => (const Color(0xFF6B5B95), 'Admin'),
      'TEACHER' => (const Color(0xFF4A90A4), 'Teacher'),
      _ => (const Color(0xFF5B8C5A), 'Student'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Compact pending invitation tile.
class _CompactInviteTile extends StatelessWidget {
  final InvitationModel invite;
  const _CompactInviteTile({required this.invite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const pendingColor = Color(0xFFC48B3F);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: pendingColor.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: pendingColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: pendingColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    invite.role,
                    style: const TextStyle(
                      color: pendingColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule_rounded, size: 15, color: pendingColor),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── RECENT NOTES SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _RecentNotesSection extends StatelessWidget {
  final List<BatchNoteModel> notes;
  final ValueChanged<BatchNoteModel> onNoteTap;

  const _RecentNotesSection({
    required this.notes,
    required this.onNoteTap,
  });

  Map<String, List<BatchNoteModel>> _groupNotesByDate() {
    final grouped = <String, List<BatchNoteModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    print('DEBUG: Current date - Today: $today, Yesterday: $yesterday');
    
    for (final note in notes) {
      if (note.createdAt == null) continue;
      
      // Convert to local time and extract date only
      final noteDate = note.createdAt!.toLocal();
      final noteDateOnly = DateTime(noteDate.year, noteDate.month, noteDate.day);
      
      print('DEBUG: Note "${note.title}" - Created: ${note.createdAt} (UTC), Local: $noteDate, Date only: $noteDateOnly');
      
      String dateKey;
      if (noteDateOnly.isAtSameMomentAs(today)) {
        dateKey = 'Today';
        print('DEBUG: Classified as Today');
      } else if (noteDateOnly.isAtSameMomentAs(yesterday)) {
        dateKey = 'Yesterday';
        print('DEBUG: Classified as Yesterday');
      } else {
        dateKey = DateFormat('MMM dd, yyyy').format(noteDate);
        print('DEBUG: Classified as $dateKey');
      }
      
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(note);
    }
    
    print('DEBUG: Final groups: ${grouped.keys.toList()}');
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedNotes = _groupNotesByDate();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedNotes.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),
            // Notes for this date
            ...entry.value.map((note) => _NoteCard(
              note: note,
              onTap: () => onNoteTap(note),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final BatchNoteModel note;
  final VoidCallback onTap;

  const _NoteCard({
    required this.note,
    required this.onTap,
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
                          // Batch name if available
                          if (note.batch != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 14,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    note.batch!.name,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
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
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
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
                    if (note.createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.04,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _timeAgo(note.createdAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
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
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Show first 2 attachments with descriptions in reading flow
                      ...note.attachments.take(2).expand((a) {
                        final ac =
                            _typeConfig[a.fileType] ??
                            (
                              Icons.attach_file_rounded,
                              theme.colorScheme.primary,
                            );
                        return [
                          // Attachment chip
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
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
                                  Flexible(
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
                            ),
                          ),
                          // Description directly below if exists
                          if (a.description != null &&
                              a.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _DescriptionCard(
                                description: a.description!,
                                fileName:
                                    a.fileName ?? a.fileType.toUpperCase(),
                                theme: theme,
                              ),
                            ),
                        ];
                      }),
                      // Show "...more" if there are more than 2
                      if (note.attachments.length > 2)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.06,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.more_horiz_rounded,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${note.attachments.length - 2} more',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
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

class _DescriptionCard extends StatefulWidget {
  final String description;
  final String fileName;
  final ThemeData theme;

  const _DescriptionCard({
    required this.description,
    required this.fileName,
    required this.theme,
  });

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final needsExpansion =
        widget.description.length > 80 ||
        widget.description.split('\n').length > 2;

    return GestureDetector(
      onTap: needsExpansion
          ? () => setState(() => _isExpanded = !_isExpanded)
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File reference with trail indicator
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.theme.colorScheme.primary.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.description_outlined,
                  size: 13,
                  color: widget.theme.colorScheme.primary.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.fileName,
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (needsExpansion)
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: widget.theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Description text
            Text(
              widget.description,
              style: widget.theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: widget.theme.colorScheme.onSurface.withValues(
                  alpha: 0.75,
                ),
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              maxLines: _isExpanded ? null : 2,
              overflow: _isExpanded ? null : TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── UTILITY FUNCTIONS ──
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}
