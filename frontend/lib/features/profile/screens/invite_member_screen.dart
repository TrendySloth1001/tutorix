import 'package:flutter/material.dart';
import '../../../shared/services/invitation_service.dart';
import '../../../shared/widgets/app_alert.dart';

/// Invite member — card-based flow, tuned for cream/olive palette.
class InviteMemberScreen extends StatefulWidget {
  final String coachingId;
  final String coachingName;

  const InviteMemberScreen({
    super.key,
    required this.coachingId,
    required this.coachingName,
  });

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final InvitationService _invitationService = InvitationService();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isSearching = false;
  bool _isSending = false;
  Map<String, dynamic>? _lookupResult;
  String? _errorMessage;

  String _selectedRole = 'STUDENT';
  String? _selectedUserId;
  String? _selectedWardId;
  String? _selectedName;

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchContact() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _lookupResult = null;
      _selectedUserId = null;
      _selectedWardId = null;
      _selectedName = null;
    });
    try {
      final result = await _invitationService.lookupContact(
        widget.coachingId,
        contact,
      );
      setState(() {
        _lookupResult = result;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  Future<void> _sendInvitation() async {
    setState(() => _isSending = true);
    try {
      final isResolved = _lookupResult?['found'] == true;
      await _invitationService.sendInvitation(
        coachingId: widget.coachingId,
        role: _selectedRole,
        userId: _selectedUserId,
        wardId: _selectedWardId,
        invitePhone: !isResolved ? _contactController.text.trim() : null,
        inviteEmail: !isResolved ? _contactController.text.trim() : null,
        inviteName: _selectedName,
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );
      if (mounted) {
        final isResolved = _lookupResult?['found'] == true;
        AppAlert.success(
          context,
          isResolved ? 'Invitation sent!' : 'Pending invite created',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _canSend() {
    if (_contactController.text.trim().isEmpty) return false;
    if (_lookupResult?['found'] == true) {
      return _selectedUserId != null || _selectedWardId != null;
    }
    return _lookupResult != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface; // dark olive
    final surface = theme.colorScheme.surface; // cream

    // Derived tokens — tuned for readability on cream
    final cardBg = Color.lerp(surface, onSurface, 0.045)!;
    final cardBorder = onSurface.withValues(alpha: 0.13);
    final muted = onSurface.withValues(alpha: 0.65); // labels, section headers
    final faint = onSurface.withValues(alpha: 0.35); // secondary text, borders
    final hint = onSurface.withValues(alpha: 0.28); // placeholder text only

    return Scaffold(
      backgroundColor: surface,
      body: Column(
        children: [
          // ── App bar ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, size: 13, color: muted),
                        const SizedBox(width: 5),
                        Text(
                          widget.coachingName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const SizedBox(height: 8),
                Text(
                  'Invite\nMember',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Search for an existing user or send a pending invite',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════
                // CARD 1 — Search
                // ═══════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.search_rounded,
                        label: 'Find by phone or email',
                        color: onSurface,
                        muted: muted,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: faint),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search_rounded, size: 20, color: hint),
                            Expanded(
                              child: TextField(
                                controller: _contactController,
                                style: theme.textTheme.bodyMedium,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 13,
                                  ),
                                  hintText: 'name@email.com or +91...',
                                  hintStyle: theme.textTheme.bodyMedium
                                      ?.copyWith(color: hint),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                onSubmitted: (_) => _searchContact(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap:
                                    _contactController.text.trim().isNotEmpty &&
                                        !_isSearching
                                    ? _searchContact
                                    : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _contactController.text
                                            .trim()
                                            .isNotEmpty
                                        ? onSurface
                                        : onSurface.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  alignment: Alignment.center,
                                  child: _isSearching
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: surface,
                                          ),
                                        )
                                      : Icon(
                                          Icons.search_rounded,
                                          size: 18,
                                          color:
                                              _contactController.text
                                                  .trim()
                                                  .isNotEmpty
                                              ? surface
                                              : faint,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        _ErrorBanner(message: _errorMessage!),
                      ],

                      if (_lookupResult != null) ...[
                        const SizedBox(height: 14),
                        Container(height: 1, color: faint),
                        const SizedBox(height: 14),
                        _buildLookupResult(theme, onSurface, muted, faint),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ═══════════════════════════════════════════════
                // CARD 2 — Role
                // ═══════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        icon: Icons.badge_outlined,
                        label: 'Choose a role',
                        color: onSurface,
                        muted: muted,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _RoleCard(
                            label: 'Student',
                            icon: Icons.person_outline_rounded,
                            accent: const Color(0xFF2E7D32), // rich green
                            selected: _selectedRole == 'STUDENT',
                            surface: surface,
                            faint: faint,
                            onTap: () =>
                                setState(() => _selectedRole = 'STUDENT'),
                          ),
                          const SizedBox(width: 10),
                          _RoleCard(
                            label: 'Teacher',
                            icon: Icons.school_outlined,
                            accent: const Color(0xFF1565C0), // strong blue
                            selected: _selectedRole == 'TEACHER',
                            surface: surface,
                            faint: faint,
                            onTap: () =>
                                setState(() => _selectedRole = 'TEACHER'),
                          ),
                          const SizedBox(width: 10),
                          _RoleCard(
                            label: 'Parent',
                            icon: Icons.family_restroom_rounded,
                            accent: const Color(0xFF6A1B9A), // deep purple
                            selected: _selectedRole == 'PARENT',
                            surface: surface,
                            faint: faint,
                            onTap: () =>
                                setState(() => _selectedRole = 'PARENT'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ═══════════════════════════════════════════════
                // CARD 3 — Message
                // ═══════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Personal note',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 11,
                              color: hint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: faint),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.all(14),
                            hintText: 'Welcome to ${widget.coachingName}!',
                            hintStyle: theme.textTheme.bodySmall?.copyWith(
                              color: hint,
                              height: 1.4,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ═══════════════════════════════════════════════
                // Send CTA
                // ═══════════════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: _canSend()
                          ? onSurface
                          : onSurface.withValues(alpha: 0.08),
                      boxShadow: _canSend()
                          ? [
                              BoxShadow(
                                color: onSurface.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canSend() && !_isSending
                            ? _sendInvitation
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: _isSending
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: surface,
                                  ),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      size: 18,
                                      color: _canSend() ? surface : faint,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Send Invitation',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                        color: _canSend() ? surface : faint,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                if (!_canSend())
                  Center(
                    child: Text(
                      _contactController.text.trim().isEmpty
                          ? 'Search for a member to get started'
                          : _lookupResult == null
                          ? 'Tap search to look up this contact'
                          : _lookupResult!['found'] == true
                          ? 'Select a profile above to continue'
                          : '',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Lookup result ──────────────────────────────────────────────────────

  Widget _buildLookupResult(
    ThemeData theme,
    Color onSurface,
    Color muted,
    Color faint,
  ) {
    final found = _lookupResult!['found'] == true;

    if (!found) {
      const amber = Color(0xFFD84315); // burnt orange — high contrast on cream
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: amber.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New to the platform',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: amber,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'A pending invite will be sent and auto-linked when they join.',
                    style: TextStyle(color: muted, height: 1.35, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final user = _lookupResult!['user'] as Map<String, dynamic>;
    final wards = (user['wards'] as List<dynamic>?) ?? [];
    final privacy = (user['privacy'] as Map<String, dynamic>?) ?? {};

    // Build subtitle: show email if available, else phone, else 'Contact hidden'
    String subtitle;
    if (user['email'] != null && (user['email'] as String).isNotEmpty) {
      subtitle = user['email'] as String;
    } else if (user['phone'] != null && (user['phone'] as String).isNotEmpty) {
      subtitle = user['phone'] as String;
    } else {
      subtitle = 'Contact info hidden';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'User found',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PersonCard(
          name: user['name'] ?? 'Unknown',
          subtitle: subtitle,
          picture: user['picture'] as String?,
          icon: Icons.person_rounded,
          selected: _selectedUserId == user['id'] && _selectedWardId == null,
          badges: _buildBadges(user),
          onSurface: onSurface,
          faint: faint,
          onTap: () => setState(() {
            _selectedUserId = user['id'] as String;
            _selectedWardId = null;
            _selectedName = user['name'] as String?;
            final roles = (user['existingRoles'] as List<dynamic>?) ?? [];
            if (roles.contains('TEACHER')) _selectedRole = 'TEACHER';
          }),
        ),
        if (privacy['wardsHidden'] == true) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.visibility_off_rounded, size: 14, color: faint),
              const SizedBox(width: 6),
              Text(
                'Student profiles hidden by user',
                style: TextStyle(
                  fontSize: 11,
                  color: faint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ] else if (wards.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'STUDENT PROFILES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: faint,
            ),
          ),
          const SizedBox(height: 6),
          ...wards.map((w) {
            final ward = w as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _PersonCard(
                name: ward['name'] ?? 'Unknown',
                subtitle: ward['isEnrolled'] == true
                    ? 'Already enrolled as ${ward['enrolledRole'] ?? 'student'}'
                    : 'Student profile',
                picture: ward['picture'] as String?,
                icon: Icons.child_care_rounded,
                selected: _selectedWardId == ward['id'],
                badges: ward['isEnrolled'] == true
                    ? [_badge('Enrolled', const Color(0xFF2E7D32))]
                    : null,
                onSurface: onSurface,
                faint: faint,
                onTap: () => setState(() {
                  _selectedWardId = ward['id'] as String;
                  _selectedUserId = null;
                  _selectedName = ward['name'] as String?;
                  _selectedRole = 'STUDENT';
                }),
              ),
            );
          }),
        ],
      ],
    );
  }

  List<Widget> _buildBadges(Map<String, dynamic> user) {
    final b = <Widget>[];
    // Show coaching-scoped roles from existingRoles array
    final roles = (user['existingRoles'] as List<dynamic>?) ?? [];
    for (final role in roles) {
      switch (role) {
        case 'ADMIN':
          b.add(_badge('Admin', const Color(0xFF6A1B9A)));
          break;
        case 'TEACHER':
          b.add(_badge('Teacher', const Color(0xFF1565C0)));
          break;
        case 'STUDENT':
          b.add(_badge('Student', const Color(0xFF2E7D32)));
          break;
        case 'PARENT':
          b.add(_badge('Parent', const Color(0xFFE65100)));
          break;
      }
    }
    if (user['isMember'] == true && b.isEmpty) {
      b.add(_badge('Member', const Color(0xFF455A64)));
    }
    return b;
  }

  Widget _badge(String label, Color c) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color muted;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
      ],
    );
  }
}

/// Role card — each role uses a distinct saturated accent color.
class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final Color surface;
  final Color faint;
  final VoidCallback onTap;
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.surface,
    required this.faint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent.withValues(alpha: 0.5) : faint,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.14)
                      : faint.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: selected ? accent : faint),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : faint,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Person card with selection state.
class _PersonCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? picture;
  final IconData icon;
  final bool selected;
  final List<Widget>? badges;
  final Color onSurface;
  final Color faint;
  final VoidCallback onTap;
  const _PersonCard({
    required this.name,
    required this.subtitle,
    this.picture,
    required this.icon,
    required this.selected,
    this.badges,
    required this.onSurface,
    required this.faint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? onSurface.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? onSurface.withValues(alpha: 0.35) : faint,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: onSurface.withValues(alpha: 0.07),
              backgroundImage: picture != null ? NetworkImage(picture!) : null,
              child: picture == null
                  ? Icon(
                      icon,
                      color: onSurface.withValues(alpha: 0.4),
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: faint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (badges != null) ...badges!,
            if (selected) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: onSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: theme.colorScheme.surface,
                  size: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: red.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
