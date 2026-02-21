import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../models/coaching_model.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';
import '../services/member_service.dart';
import '../../profile/screens/invite_member_screen.dart';
import '../../fee/screens/fee_member_profile_screen.dart';

/// Members screen — premium, compact design with segmented tabs.
class CoachingMembersScreen extends StatefulWidget {
  final CoachingModel coaching;
  final UserModel user;

  const CoachingMembersScreen({
    super.key,
    required this.coaching,
    required this.user,
  });

  @override
  State<CoachingMembersScreen> createState() => _CoachingMembersScreenState();
}

class _CoachingMembersScreenState extends State<CoachingMembersScreen>
    with SingleTickerProviderStateMixin {
  final MemberService _memberService = MemberService();
  late TabController _tabController;

  List<MemberModel> _members = [];
  List<InvitationModel> _invitations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final List<StreamSubscription> _subs = [];

  /// Check if current user is admin/owner
  bool get _isAdmin {
    if (widget.coaching.ownerId == widget.user.id) return true;
    final role = widget.coaching.myRole;
    return role == 'ADMIN';
  }

  /// Check if current user can invite members (owner, admin, or teacher)
  bool get _canInvite {
    // Owner can always invite
    if (widget.coaching.ownerId == widget.user.id) return true;

    // Check user's role in this coaching from myRole (for joined coachings)
    final role = widget.coaching.myRole;
    if (role == 'ADMIN' || role == 'TEACHER') return true;

    // Also check from loaded members list
    final userMembership = _members
        .where((m) => m.userId == widget.user.id)
        .firstOrNull;
    if (userMembership != null) {
      return userMembership.role == 'ADMIN' || userMembership.role == 'TEACHER';
    }

    return false;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tabController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() => _isLoading = true);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    int completed = 0;
    void checkDone() {
      completed++;
      if (completed >= 2 && mounted) setState(() => _isLoading = false);
    }

    _subs.add(
      _memberService
          .watchMembers(widget.coaching.id)
          .listen(
            (list) {
              if (mounted) setState(() => _members = list);
              checkDone();
            },
            onError: (e) {
              if (mounted) {
                AppAlert.error(context, e, fallback: 'Failed to load members');
              }
              checkDone();
            },
          ),
    );

    _subs.add(
      _memberService
          .watchInvitations(widget.coaching.id)
          .listen(
            (list) {
              if (mounted) setState(() => _invitations = list);
              checkDone();
            },
            onError: (e) {
              ErrorLoggerService.instance.warn(
                'watchInvitations error',
                category: LogCategory.api,
                error: e.toString(),
              );
              checkDone();
            },
          ),
    );
  }

  List<MemberModel> _filter(String? role) {
    var list = role == null
        ? _members
        : _members.where((m) => m.role == role).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((m) => m.displayName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  List<InvitationModel> get _pending {
    var list = _invitations.where((i) => i.isPending).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((i) => i.displayName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _navigateToInvite() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMemberScreen(
          coachingId: widget.coaching.id,
          coachingName: widget.coaching.name,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _removeMember(MemberModel member) async {
    final confirmed = await _showConfirmSheet(
      title: 'Remove Member',
      message: 'Remove ${member.displayName} from this coaching?',
      confirmLabel: 'Remove',
    );
    if (confirmed != true) return;
    try {
      await _memberService.removeMember(widget.coaching.id, member.id);
      if (mounted) {
        AppAlert.success(context, 'Member removed');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to remove member');
      }
    }
  }

  Future<void> _cancelInvitation(InvitationModel inv) async {
    final confirmed = await _showConfirmSheet(
      title: 'Cancel Invitation',
      message: 'Cancel the invitation for ${inv.displayName}?',
      confirmLabel: 'Cancel Invite',
    );
    if (confirmed != true) return;
    try {
      await _memberService.cancelInvitation(widget.coaching.id, inv.id);
      if (mounted) {
        AppAlert.success(context, 'Invitation cancelled');
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e, fallback: 'Failed to cancel invitation');
      }
    }
  }

  Future<bool?> _showConfirmSheet({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _grabHandle(theme),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // ── Header ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Members',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_members.length} member${_members.length != 1 ? 's' : ''}'
                              '${_pending.isNotEmpty ? ' · ${_pending.length} pending' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_canInvite) _InviteButton(onTap: _navigateToInvite),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        hintText: 'Search members…',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: theme.colorScheme.secondary.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Segmented tabs
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: theme.colorScheme.onPrimary,
                      unselectedLabelColor: theme.colorScheme.secondary
                          .withValues(alpha: 0.6),
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      dividerHeight: 0,
                      tabs: [
                        Tab(text: 'All (${_filter(null).length})'),
                        Tab(text: 'Teachers (${_filter('TEACHER').length})'),
                        Tab(text: 'Pending (${_pending.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Body ──
          Expanded(
            child: _isLoading
                ? const MembersShimmer()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _MemberListView(
                        members: _filter(null),
                        onRemove: _removeMember,
                        onRefresh: () async {
                          _loadData();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        emptyIcon: Icons.groups_outlined,
                        emptyText: 'No members yet',
                        canManage: _canInvite,
                        showEmail: _isAdmin,
                        coachingId: widget.coaching.id,
                      ),
                      _MemberListView(
                        members: _filter('TEACHER'),
                        onRemove: _removeMember,
                        onRefresh: () async {
                          _loadData();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                        emptyIcon: Icons.school_outlined,
                        emptyText: 'No teachers yet',
                        canManage: _canInvite,
                        showEmail: _isAdmin,
                        coachingId: widget.coaching.id,
                      ),
                      _InviteListView(
                        invites: _pending,
                        onCancel: _cancelInvitation,
                        onRefresh: () async {
                          _loadData();
                          await Future.delayed(
                            const Duration(milliseconds: 500),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════

Widget _grabHandle(ThemeData theme) => Center(
  child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: theme.colorScheme.secondary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(2),
    ),
  ),
);

// ── Invite button ──

class _InviteButton extends StatelessWidget {
  final VoidCallback onTap;
  const _InviteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: 16,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                'Invite',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Member list ──

class _MemberListView extends StatelessWidget {
  final List<MemberModel> members;
  final ValueChanged<MemberModel> onRemove;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyText;
  final bool canManage;
  final bool showEmail;
  final String coachingId;

  const _MemberListView({
    required this.members,
    required this.onRemove,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyText,
    required this.canManage,
    required this.coachingId,
    this.showEmail = false,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return _EmptyState(icon: emptyIcon, text: emptyText);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _MemberRow(
          member: members[i],
          onRemove: () => onRemove(members[i]),
          canRemove: canManage,
          showEmail: showEmail,
          coachingId: coachingId,
        ),
      ),
    );
  }
}



// ... existing imports

class _MemberRow extends StatelessWidget {
  final MemberModel member;
  final VoidCallback onRemove;
  final bool canRemove;
  final bool showEmail;
  final String coachingId; // Add coachingId

  const _MemberRow({
    required this.member,
    required this.onRemove,
    required this.canRemove,
    required this.coachingId, // Add coachingId
    this.showEmail = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeeMemberProfileScreen(
              coachingId: coachingId,
              memberId: member.id,
              memberName: member.displayName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
// ... rest of the row content

        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
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
                      fontSize: 15,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // Name + subtitle
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
                if (showEmail && member.subtitle.isNotEmpty)
                  Text(
                    member.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.45,
                      ),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Role badge
          _roleBadge(member.role),
          const SizedBox(width: 4),

          // Options
          if (canRemove)
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.colorScheme.secondary.withValues(alpha: 0.35),
                  size: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onSelected: (v) {
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'remove',
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_remove_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Remove',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ));
  }

  Widget _roleBadge(String role) {
    final (Color c, String l) = switch (role) {
      'ADMIN' => (AppColors.roleAdmin, 'A'),
      'TEACHER' => (AppColors.roleTeacher, 'T'),
      _ => (AppColors.roleStudent, 'S'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l,
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Invitation list ──

class _InviteListView extends StatelessWidget {
  final List<InvitationModel> invites;
  final ValueChanged<InvitationModel> onCancel;
  final Future<void> Function() onRefresh;

  const _InviteListView({
    required this.invites,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) {
      return const _EmptyState(
        icon: Icons.mail_outline_rounded,
        text: 'No pending invitations',
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: invites.length,
        separatorBuilder: (_, _) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _InviteRow(
          invite: invites[i],
          onCancel: () => onCancel(invites[i]),
        ),
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  final InvitationModel invite;
  final VoidCallback onCancel;
  const _InviteRow({required this.invite, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const amber = AppColors.rolePending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              invite.isUnresolved
                  ? Icons.person_off_rounded
                  : Icons.mail_outline_rounded,
              color: amber,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),

          // Name + role
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
                const SizedBox(height: 2),
                Row(
                  children: [
                    _roleBadge(invite.role),
                    if (invite.isUnresolved) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Not on platform',
                        style: TextStyle(
                          color: amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Cancel
          SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.error.withValues(alpha: 0.6),
              ),
              onPressed: onCancel,
              tooltip: 'Cancel',
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final (Color c, String l) = switch (role) {
      'ADMIN' => (AppColors.roleAdmin, 'A'),
      'TEACHER' => (AppColors.roleTeacher, 'T'),
      _ => (AppColors.roleStudent, 'S'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        l,
        style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
