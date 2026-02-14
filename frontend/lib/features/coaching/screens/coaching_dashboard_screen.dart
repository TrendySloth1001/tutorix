import 'package:flutter/material.dart';
import '../models/coaching_model.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';
import '../services/member_service.dart';
import 'coaching_notifications_screen.dart'; // Import the new screen (same directory)
import '../../../shared/services/notification_service.dart'; // Correct path

/// Coaching dashboard — compact, data-driven overview.
class CoachingDashboardScreen extends StatefulWidget {
  final CoachingModel coaching;
  final VoidCallback? onMembersTap;

  const CoachingDashboardScreen({
    super.key,
    required this.coaching,
    this.onMembersTap,
  });

  @override
  State<CoachingDashboardScreen> createState() =>
      _CoachingDashboardScreenState();
}

class _CoachingDashboardScreenState extends State<CoachingDashboardScreen> {
  final MemberService _memberService = MemberService();
  final NotificationService _notificationService = NotificationService();

  List<MemberModel> _members = [];
  List<InvitationModel> _invitations = [];
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
      final results = await Future.wait([
        _memberService.getMembers(widget.coaching.id),
        _memberService.getInvitations(widget.coaching.id),
        _notificationService.getCoachingNotifications(
          widget.coaching.id,
          limit: 1,
        ), // Fetch fetching metadata for unread count
      ]);
      _members = results[0] as List<MemberModel>;
      _invitations = results[1] as List<InvitationModel>;
      _unreadNotifications =
          (results[2] as Map<String, dynamic>)['unreadCount'] ?? 0;
    } catch (_) {}
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

  int _countRole(String role) => _members.where((m) => m.role == role).length;

  List<InvitationModel> get _pending =>
      _invitations.where((i) => i.isPending).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.coaching;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            // ── Safe area + coaching header ──
            SizedBox(height: MediaQuery.of(context).padding.top + 16),
            _Header(
              coaching: c,
              memberCount: _members.length,
              unreadNotifications: _unreadNotifications,
              onNotificationTap: _onNotificationTap,
            ),

            const SizedBox(height: 20),

            // ── Stat chips ──
            _StatChipRow(
              teachers: _countRole('TEACHER'),
              students: _countRole('STUDENT'),
              admins: _countRole('ADMIN'),
              pending: _pending.length,
            ),

            const SizedBox(height: 24),

            // ── Quick action ──
            _QuickAction(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Invite Members',
              onTap: widget.onMembersTap,
            ),

            // ── Recent Members ──
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Recent Members',
                trailing: _members.length > 5 ? 'See all' : null,
                onTrailingTap: widget.onMembersTap,
              ),
              const SizedBox(height: 8),
              ..._members.take(5).map((m) => _CompactMemberTile(member: m)),
            ],

            // ── Pending Invitations ──
            if (_pending.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionHeader(title: 'Pending Invitations'),
              const SizedBox(height: 8),
              ..._pending.take(5).map((i) => _CompactInviteTile(invite: i)),
            ],

            // ── Empty state ──
            if (_members.isEmpty && _pending.isEmpty) ...[
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widgets — compact, premium, zero static data
// ═══════════════════════════════════════════════════════════════════════════

/// Coaching name + avatar header.
class _Header extends StatelessWidget {
  final CoachingModel coaching;
  final int memberCount;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;

  const _Header({
    required this.coaching,
    required this.memberCount,
    required this.unreadNotifications,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
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
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
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
