import 'package:flutter/material.dart';
import '../../../shared/services/invitation_service.dart';

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

  // Selected targets
  String _selectedRole = 'STUDENT';
  String? _selectedUserId;
  String? _selectedWardId;
  String? _selectedName;

  final List<String> _roles = ['STUDENT', 'TEACHER', 'PARENT'];

  @override
  void dispose() {
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchContact() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isResolved
                  ? 'Invitation sent successfully!'
                  : 'Pending invitation created. Will be claimed on sign-up.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Member'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Coaching name header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.school_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inviting to',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          widget.coachingName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search field
            Text(
              'Search by Phone or Email',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _contactController,
                    decoration: InputDecoration(
                      hintText: 'Enter phone number or email',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _searchContact(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSearching ? null : _searchContact,
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Lookup result
            if (_lookupResult != null) _buildLookupResult(theme),

            const SizedBox(height: 24),

            // Role selector
            Text(
              'Assign Role',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: _roles
                  .map(
                    (role) => ButtonSegment(
                      value: role,
                      label: Text(role),
                      icon: Icon(_roleIcon(role)),
                    ),
                  )
                  .toList(),
              selected: {_selectedRole},
              onSelectionChanged: (roles) {
                setState(() => _selectedRole = roles.first);
              },
            ),

            const SizedBox(height: 24),

            // Optional message
            Text(
              'Message (Optional)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add a personal message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Send button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSend()
                    ? (_isSending ? null : _sendInvitation)
                    : null,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSending ? 'Sending...' : 'Send Invitation'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupResult(ThemeData theme) {
    final found = _lookupResult!['found'] == true;

    if (!found) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_off_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'User Not Found',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This person is not on the platform yet. A pending invitation will be created and automatically linked when they sign up.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final user = _lookupResult!['user'] as Map<String, dynamic>;
    final wards = (user['wards'] as List<dynamic>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Found',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),

        // User profile card
        _buildSelectableProfile(
          theme: theme,
          name: user['name'] ?? 'Unknown',
          subtitle: user['email'] ?? '',
          picture: user['picture'] as String?,
          icon: Icons.person_rounded,
          isSelected: _selectedUserId == user['id'] && _selectedWardId == null,
          onTap: () {
            setState(() {
              _selectedUserId = user['id'] as String;
              _selectedWardId = null;
              _selectedName = user['name'] as String?;
              // Auto-set role based on user flags
              if (user['isTeacher'] == true) _selectedRole = 'TEACHER';
            });
          },
          badge: _buildRoleBadges(user),
        ),

        // Ward profiles
        if (wards.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Student Profiles (Wards)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...wards.map((ward) {
            final w = ward as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildSelectableProfile(
                theme: theme,
                name: w['name'] ?? 'Unknown',
                subtitle: 'Student profile',
                picture: w['picture'] as String?,
                icon: Icons.child_care_rounded,
                isSelected: _selectedWardId == w['id'],
                onTap: () {
                  setState(() {
                    _selectedWardId = w['id'] as String;
                    _selectedUserId = null;
                    _selectedName = w['name'] as String?;
                    _selectedRole = 'STUDENT';
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSelectableProfile({
    required ThemeData theme,
    required String name,
    required String subtitle,
    String? picture,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: picture != null ? NetworkImage(picture) : null,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: picture == null
                  ? Icon(icon, color: theme.colorScheme.primary, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ?badge,
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadges(Map<String, dynamic> user) {
    final badges = <Widget>[];
    if (user['isAdmin'] == true) {
      badges.add(_chip('Admin', Colors.purple));
    }
    if (user['isTeacher'] == true) {
      badges.add(_chip('Teacher', Colors.blue));
    }
    if (user['isParent'] == true) {
      badges.add(_chip('Parent', Colors.teal));
    }
    return Wrap(spacing: 4, children: badges);
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'TEACHER':
        return Icons.school_rounded;
      case 'PARENT':
        return Icons.family_restroom_rounded;
      case 'STUDENT':
        return Icons.child_care_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  bool _canSend() {
    if (_contactController.text.trim().isEmpty) return false;
    // If lookup found someone, must select a profile
    if (_lookupResult?['found'] == true) {
      return _selectedUserId != null || _selectedWardId != null;
    }
    // Unresolved: can send as pending
    return _lookupResult != null;
  }
}
