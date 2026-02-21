import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/error_logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coaching_model.dart';
import '../models/member_model.dart';
import '../models/invitation_model.dart';
import '../services/member_service.dart';
import 'coaching_notifications_screen.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../batch/services/batch_service.dart';
import '../../batch/models/batch_note_model.dart';
import '../../batch/screens/note_detail_screen.dart';
import '../../assessment/models/assessment_model.dart';
import '../../assessment/models/assignment_model.dart';
import '../../assessment/screens/take_assessment_screen.dart';
import '../../assessment/screens/submit_assignment_screen.dart';
import '../../fee/screens/fee_dashboard_screen.dart';
import '../../fee/screens/my_fees_screen.dart';

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
  final ErrorLoggerService _logger = ErrorLoggerService.instance;

  List<MemberModel> _members = [];
  List<InvitationModel> _invitations = [];
  List<BatchNoteModel> _recentNotes = [];
  int _unreadNotifications = 0;
  bool _isLoading = true;

  // Dashboard feed data
  List<dynamic> _feedAssessments = [];
  List<dynamic> _feedAssignments = [];
  List<dynamic> _feedNotices = [];
  Set<String> _dismissedItems = {};

  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _loadDismissedItems();
    _loadData();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
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
      if (completed >= 5 && mounted) setState(() => _isLoading = false);
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
              _logger.warn(
                'watchMembers error',
                category: LogCategory.api,
                error: e.toString(),
              );
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
              _logger.warn(
                'watchInvitations error',
                category: LogCategory.api,
                error: e.toString(),
              );
              checkDone();
            },
          ),
    );

    _subs.add(
      _notificationService
          .watchCoachingNotifications(widget.coaching.id, limit: 1)
          .listen(
            (data) {
              if (mounted) {
                setState(() => _unreadNotifications = data['unreadCount'] ?? 0);
              }
              checkDone();
            },
            onError: (e) {
              _logger.warn(
                'watchNotifications error',
                category: LogCategory.api,
                error: e.toString(),
              );
              checkDone();
            },
          ),
    );

    _subs.add(
      _batchService
          .watchRecentNotes(widget.coaching.id)
          .listen(
            (list) {
              if (mounted) setState(() => _recentNotes = list);
              checkDone();
            },
            onError: (e) {
              _logger.warn(
                'watchRecentNotes error',
                category: LogCategory.api,
                error: e.toString(),
              );
              checkDone();
            },
          ),
    );

    // Dashboard feed (assessments, assignments, notices)
    _subs.add(
      _batchService
          .watchDashboardFeed(widget.coaching.id)
          .listen(
            (data) {
              if (mounted) {
                setState(() {
                  _feedAssessments =
                      (data['assessments'] as List<dynamic>?) ?? [];
                  _feedAssignments =
                      (data['assignments'] as List<dynamic>?) ?? [];
                  _feedNotices = (data['notices'] as List<dynamic>?) ?? [];
                });
              }
              checkDone();
            },
            onError: (e) {
              _logger.warn(
                'watchDashboardFeed error',
                category: LogCategory.api,
                error: e.toString(),
              );
              checkDone();
            },
          ),
    );
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
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  Future<void> _loadDismissedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'dismissed_feed_${widget.coaching.id}';
      final dismissed = prefs.getStringList(key) ?? [];
      if (mounted) {
        setState(() {
          _dismissedItems = dismissed.toSet();
        });
      }
    } catch (e) {
      _logger.debug(
        'Failed to load dismissed items: $e',
        category: LogCategory.storage,
      );
    }
  }

  Future<void> _dismissItem(String itemId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'dismissed_feed_${widget.coaching.id}';
      _dismissedItems.add('${type}_$itemId');
      await prefs.setStringList(key, _dismissedItems.toList());
      if (mounted) setState(() {});
    } catch (e) {
      _logger.debug(
        'Failed to dismiss item: $e',
        category: LogCategory.storage,
      );
    }
  }

  Future<void> _clearDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'dismissed_feed_${widget.coaching.id}';
      await prefs.remove(key);
      if (mounted) {
        setState(() {
          _dismissedItems.clear();
        });
      }
    } catch (e) {
      _logger.debug(
        'Failed to clear dismissed items: $e',
        category: LogCategory.storage,
      );
    }
  }

  List<dynamic> _filterDismissed(List<dynamic> items, String type) {
    return items.where((item) {
      final id = (item as Map<String, dynamic>)['id'] as String? ?? '';
      return !_dismissedItems.contains('${type}_$id');
    }).toList();
  }

  void _onAssessmentTap(dynamic assessmentData) {
    final a = assessmentData as Map<String, dynamic>;
    final batchId = a['batchId'] as String? ?? '';
    if (batchId.isEmpty) return;

    final assessment = AssessmentModel.fromJson(a);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakeAssessmentScreen(
          coachingId: widget.coaching.id,
          batchId: batchId,
          assessment: assessment,
        ),
      ),
    );
  }

  void _onAssignmentTap(dynamic assignmentData) {
    final a = assignmentData as Map<String, dynamic>;
    final batchId = a['batchId'] as String? ?? '';
    if (batchId.isEmpty) return;

    final assignment = AssignmentModel.fromJson(a);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitAssignmentScreen(
          coachingId: widget.coaching.id,
          batchId: batchId,
          assignment: assignment,
        ),
      ),
    );
  }

  int _countRole(String role) => _members.where((m) => m.role == role).length;

  List<InvitationModel> get _pending =>
      _invitations.where((i) => i.isPending).toList();

  // Role helpers
  bool get _isOwner =>
      widget.user != null && widget.coaching.isOwner(widget.user!.id);
  String? get _myRole => widget.coaching.myRole;
  bool get _isStudent => _myRole == 'STUDENT';
  bool get _isAdmin => _myRole == 'ADMIN';
  bool get _canManageMembers => _isAdmin || _isOwner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.coaching;

    if (_isLoading) {
      return const Scaffold(body: DashboardShimmer());
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
              onRefresh: () async {
                _loadData();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                children: [
                  // ── Role badge (for students/teachers) ──
                  if (!_canManageMembers && _myRole != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isStudent
                                ? Icons.school_rounded
                                : Icons.person_rounded,
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
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Fee Management',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeeDashboardScreen(
                            coachingId: widget.coaching.id,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── My Fees shortcut (for students/parents) ──
                  if (!_canManageMembers) ...[
                    const SizedBox(height: 16),
                    _QuickAction(
                      icon: Icons.receipt_rounded,
                      label: 'My Fees',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MyFeesScreen(
                            coachingId: widget.coaching.id,
                            coachingName: widget.coaching.name,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Swipeable Notices (for students/teachers) ──
                  if (!_canManageMembers && _feedNotices.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Notices',
                      icon: Icons.campaign_rounded,
                    ),
                    const SizedBox(height: 8),
                    _SwipeableNoticesSection(notices: _feedNotices),
                  ],

                  // ── Clear dismissed button (only if items are dismissed) ──
                  if (!_canManageMembers && _dismissedItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _clearDismissed,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Show ${_dismissedItems.length} dismissed item${_dismissedItems.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],

                  // ── New Quizzes (for students/teachers) ──
                  if (!_canManageMembers &&
                      _filterDismissed(
                        _feedAssessments,
                        'assessment',
                      ).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'New Quizzes',
                      icon: Icons.quiz_rounded,
                    ),
                    const SizedBox(height: 8),
                    _DateGroupedFeedSection(
                      items: _filterDismissed(_feedAssessments, 'assessment'),
                      itemBuilder: (a) => _FeedAssessmentCard(
                        assessment: a,
                        onTap: () => _onAssessmentTap(a),
                        onDismiss: () {
                          final id =
                              (a as Map<String, dynamic>)['id'] as String? ??
                              '';
                          if (id.isNotEmpty) _dismissItem(id, 'assessment');
                        },
                      ),
                    ),
                  ],

                  // ── New Assignments (for students/teachers) ──
                  if (!_canManageMembers &&
                      _filterDismissed(
                        _feedAssignments,
                        'assignment',
                      ).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'New Assignments',
                      icon: Icons.assignment_rounded,
                    ),
                    const SizedBox(height: 8),
                    _DateGroupedFeedSection(
                      items: _filterDismissed(_feedAssignments, 'assignment'),
                      itemBuilder: (a) => _FeedAssignmentCard(
                        assignment: a,
                        onTap: () => _onAssignmentTap(a),
                        onDismiss: () {
                          final id =
                              (a as Map<String, dynamic>)['id'] as String? ??
                              '';
                          if (id.isNotEmpty) _dismissItem(id, 'assignment');
                        },
                      ),
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
                    ..._members
                        .take(5)
                        .map((m) => _CompactMemberTile(member: m)),
                  ],

                  // ── Pending Invitations (only for admins/owners) ──
                  if (_canManageMembers && _pending.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(title: 'Pending Invitations'),
                    const SizedBox(height: 8),
                    ..._pending
                        .take(5)
                        .map((i) => _CompactInviteTile(invite: i)),
                  ],

                  // ── Student/Teacher Empty state ──
                  if (!_canManageMembers &&
                      _recentNotes.isEmpty &&
                      _feedAssessments.isEmpty &&
                      _feedAssignments.isEmpty &&
                      _feedNotices.isEmpty) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            _isStudent
                                ? Icons.wb_sunny_outlined
                                : Icons.edit_note_outlined,
                            size: 56,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isStudent
                                ? 'All Caught Up!'
                                : 'No Recent Activity',
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
                  if (_canManageMembers &&
                      _members.isEmpty &&
                      _pending.isEmpty) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.group_add_rounded,
                            size: 48,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
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
            color: AppColors.roleAdmin,
          ),
        _Chip(
          label: '$teachers Teacher${teachers != 1 ? 's' : ''}',
          color: AppColors.roleTeacher,
        ),
        _Chip(
          label: '$students Student${students != 1 ? 's' : ''}',
          color: AppColors.roleStudent,
        ),
        if (pending > 0)
          _Chip(label: '$pending Pending', color: AppColors.rolePending),
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
      'ADMIN' => (AppColors.roleAdmin, 'Admin'),
      'TEACHER' => (AppColors.roleTeacher, 'Teacher'),
      _ => (AppColors.roleStudent, 'Student'),
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
    const pendingColor = AppColors.rolePending;
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

  const _RecentNotesSection({required this.notes, required this.onNoteTap});

  Map<String, List<BatchNoteModel>> _groupNotesByDate() {
    final grouped = <String, List<BatchNoteModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final note in notes) {
      if (note.createdAt == null) continue;

      // Convert to local time and extract date only
      final noteDate = note.createdAt!.toLocal();
      final noteDateOnly = DateTime(
        noteDate.year,
        noteDate.month,
        noteDate.day,
      );

      String dateKey;
      if (noteDateOnly.isAtSameMomentAs(today)) {
        dateKey = 'Today';
      } else if (noteDateOnly.isAtSameMomentAs(yesterday)) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('MMM dd, yyyy').format(noteDate);
      }

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(note);
    }

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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
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
            ...entry.value.map(
              (note) => _NoteCard(note: note, onTap: () => onNoteTap(note)),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final BatchNoteModel note;
  final VoidCallback onTap;

  const _NoteCard({required this.note, required this.onTap});

  static const _typeConfig = {
    'pdf': (Icons.picture_as_pdf_rounded, AppColors.filePdf),
    'image': (Icons.image_rounded, AppColors.fileImage),
    'doc': (Icons.description_rounded, AppColors.fileDoc),
    'link': (Icons.link_rounded, AppColors.fileLink),
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
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.6,
                                  ),
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

// ═══════════════════════════════════════════════════════════════════════════
// ── DASHBOARD FEED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// Groups feed items by date (Today, Yesterday, date) with dividers.
class _DateGroupedFeedSection extends StatelessWidget {
  final List<dynamic> items;
  final Widget Function(dynamic item) itemBuilder;

  const _DateGroupedFeedSection({
    required this.items,
    required this.itemBuilder,
  });

  Map<String, List<dynamic>> _groupByDate() {
    final grouped = <String, List<dynamic>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final raw = (item as Map<String, dynamic>)['createdAt'];
      if (raw == null) continue;
      final dt = DateTime.tryParse(raw as String);
      if (dt == null) continue;

      final local = dt.toLocal();
      final dateOnly = DateTime(local.year, local.month, local.day);

      String dateKey;
      if (dateOnly.isAtSameMomentAs(today)) {
        dateKey = 'Today';
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        dateKey = 'Yesterday';
      } else {
        dateKey = DateFormat('MMM dd, yyyy').format(local);
      }

      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(item);
    }
    return grouped;
  }

  List<MapEntry<String, List<dynamic>>> _getSortedGroups(
    Map<String, List<dynamic>> grouped,
  ) {
    final entries = grouped.entries.toList();
    // Sort by the date of the first item in each group (newest first)
    entries.sort((a, b) {
      final aDate = (a.value.first as Map<String, dynamic>)['createdAt'];
      final bDate = (b.value.first as Map<String, dynamic>)['createdAt'];
      if (aDate == null || bDate == null) return 0;
      final aTime = DateTime.tryParse(aDate as String);
      final bTime = DateTime.tryParse(bDate as String);
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime); // Newest first
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _groupByDate();

    // If all items are same date, show without dividers
    if (grouped.length <= 1) {
      return Column(children: items.map((item) => itemBuilder(item)).toList());
    }

    final sortedGroups = _getSortedGroups(grouped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedGroups.expand((entry) {
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
          ...entry.value.map((item) => itemBuilder(item)),
        ];
      }).toList(),
    );
  }
}

/// Swipeable notices carousel with PageView + dots indicator.
class _SwipeableNoticesSection extends StatefulWidget {
  final List<dynamic> notices;
  const _SwipeableNoticesSection({required this.notices});

  @override
  State<_SwipeableNoticesSection> createState() =>
      _SwipeableNoticesSectionState();
}

class _SwipeableNoticesSectionState extends State<_SwipeableNoticesSection> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.notices.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final notice = widget.notices[index] as Map<String, dynamic>;
              final title = notice['title'] as String? ?? '';
              final message = notice['message'] as String? ?? '';
              final batch = notice['batch'] as Map<String, dynamic>?;
              final batchName = batch?['name'] as String? ?? '';
              final sentBy = notice['sentBy'] as Map<String, dynamic>?;
              final senderName = sentBy?['name'] as String? ?? '';
              final createdAt = notice['createdAt'] != null
                  ? DateTime.tryParse(notice['createdAt'] as String)
                  : null;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.campaign_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            _timeAgo(createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (batchName.isNotEmpty) ...[
                          Icon(
                            Icons.class_outlined,
                            size: 12,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            batchName,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (senderName.isNotEmpty)
                          Text(
                            '— $senderName',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.notices.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.notices.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Card for a new quiz/assessment in the dashboard feed.
class _FeedAssessmentCard extends StatelessWidget {
  final dynamic assessment;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  const _FeedAssessmentCard({
    required this.assessment,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assessment as Map<String, dynamic>;
    final title = a['title'] as String? ?? 'Untitled Quiz';
    final type = a['type'] as String? ?? 'QUIZ';
    final batch = a['batch'] as Map<String, dynamic>?;
    final batchName = batch?['name'] as String? ?? '';
    final questionCount =
        (a['_count'] as Map<String, dynamic>?)?['questions'] as int? ?? 0;
    final duration = a['durationMinutes'] as int? ?? 0;
    final totalMarks = a['totalMarks'];

    final isQuiz = type == 'QUIZ';
    final color = isQuiz ? AppColors.roleTeacher : AppColors.roleAdmin;
    final icon = isQuiz
        ? Icons.quiz_rounded
        : Icons.assignment_turned_in_rounded;

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (batchName.isNotEmpty) ...[
                        Text(
                          batchName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _FeedMeta(
                            icon: Icons.help_outline_rounded,
                            text:
                                '$questionCount Q${questionCount != 1 ? 's' : ''}',
                          ),
                          if (duration > 0) ...[
                            const SizedBox(width: 12),
                            _FeedMeta(
                              icon: Icons.timer_outlined,
                              text: '${duration}m',
                            ),
                          ],
                          if (totalMarks != null) ...[
                            const SizedBox(width: 12),
                            _FeedMeta(
                              icon: Icons.star_outline_rounded,
                              text: '$totalMarks marks',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDismiss == null) return card;

    return Dismissible(
      key: Key('assessment_${a['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.remove_circle_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        onDismiss?.call();
        return true;
      },
      child: card,
    );
  }
}

/// Card for a new assignment in the dashboard feed.
class _FeedAssignmentCard extends StatelessWidget {
  final dynamic assignment;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  const _FeedAssignmentCard({
    required this.assignment,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assignment as Map<String, dynamic>;
    final title = a['title'] as String? ?? 'Untitled Assignment';
    final batch = a['batch'] as Map<String, dynamic>?;
    final batchName = batch?['name'] as String? ?? '';
    final totalMarks = a['totalMarks'];
    final dueDate = a['dueDate'] != null
        ? DateTime.tryParse(a['dueDate'] as String)
        : null;

    const color = AppColors.roleStudent;

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (batchName.isNotEmpty) ...[
                        Text(
                          batchName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (dueDate != null) ...[
                            _FeedMeta(
                              icon: Icons.event_outlined,
                              text:
                                  'Due ${DateFormat('MMM dd').format(dueDate)}',
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (totalMarks != null)
                            _FeedMeta(
                              icon: Icons.star_outline_rounded,
                              text: '$totalMarks marks',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDismiss == null) return card;

    return Dismissible(
      key: Key('assignment_${a['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.remove_circle_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        onDismiss?.call();
        return true;
      },
      child: card,
    );
  }
}

/// Small metadata chip used inside feed cards.
class _FeedMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeedMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
